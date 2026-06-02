import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Script Result

public struct ScriptResult: Sendable {
    public let output: String
    public let error: String
    public let exitCode: Int32
    public let didTimeout: Bool
    public let duration: TimeInterval

    public init(output: String = "", error: String = "", exitCode: Int32 = 0, didTimeout: Bool = false, duration: TimeInterval = 0) {
        self.output = output
        self.error = error
        self.exitCode = exitCode
        self.didTimeout = didTimeout
        self.duration = duration
    }

    public var isSuccess: Bool { exitCode == 0 && !didTimeout }
}

// MARK: - Validation Result

public struct ScriptValidationResult: Sendable {
    public let isValid: Bool
    public let error: String
    public init(isValid: Bool, error: String = "") {
        self.isValid = isValid
        self.error = error
    }
}

/// Thread-safe one-way flag used to record that the watchdog fired.
private final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func set() { lock.lock(); value = true; lock.unlock() }
}

/// Holds pipe output written from a background queue and read after a barrier.
private final class DataBox: @unchecked Sendable {
    var data = Data()
}

// MARK: - Script Runner

/// Runs shell scripts and AppleScripts with a timeout and a conservative
/// denylist of obviously destructive shell patterns.
public final class ScriptRunner: Sendable {

    private let timeout: TimeInterval
    private let workingDirectory: String?
    private let environment: [String: String]?

    /// Obvious footguns we refuse to run. This is a guardrail, NOT a security
    /// boundary — arbitrary shell is inherently powerful. The UI warns the user.
    private static let dangerousPatterns: [String] = [
        "rm -rf /", "rm -rf ~", "rm -fr /", "rm -fr ~",
        "rm -rf /usr", "rm -rf /bin", "rm -rf /sbin", "rm -rf /etc",
        "rm -rf /var", "rm -rf /system", "rm -rf /library",
        "dd if=/dev/zero", "dd if=/dev/random", "dd if=/dev/urandom",
        ":(){ :|:& };:", "mkfs", "> /dev/sda", "format c:",
    ]

    public init(timeout: TimeInterval = 10, workingDirectory: String? = nil, environment: [String: String]? = nil) {
        self.timeout = timeout
        self.workingDirectory = workingDirectory
        self.environment = environment
    }

    // MARK: Shell

    public func runShell(script: String) async -> ScriptResult {
        let start = Date()
        let validation = validateShellScript(script)
        guard validation.isValid else {
            return ScriptResult(error: validation.error, exitCode: -1, duration: Date().timeIntervalSince(start))
        }
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ScriptResult(error: "Script is empty", exitCode: -1, duration: Date().timeIntervalSince(start))
        }

        let timeoutValue = timeout
        let workingDir = workingDirectory
        let env = environment

        return await withCheckedContinuation { (continuation: CheckedContinuation<ScriptResult, Never>) in
            let task = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", trimmed]
            if let workingDir { task.currentDirectoryURL = URL(fileURLWithPath: workingDir) }
            if let env {
                var merged = ProcessInfo.processInfo.environment
                for (k, v) in env { merged[k] = v }
                task.environment = merged
            }

            // Launch first. (Only this path resumes the continuation once; the
            // catch returns before the background resume block below is scheduled.)
            do {
                try task.run()
            } catch {
                continuation.resume(returning: ScriptResult(
                    error: "Failed to launch: \(error.localizedDescription)", exitCode: -1,
                    duration: Date().timeIntervalSince(start)))
                return
            }

            // Drain both pipes concurrently on background queues so a process that
            // writes more than the ~64KB pipe buffer can't deadlock against a
            // synchronous read that happens before the process exits. Started only
            // after a successful launch so the reader threads can't block forever
            // on pipes whose write ends never opened.
            let outBox = DataBox()
            let errBox = DataBox()
            let group = DispatchGroup()
            let io = DispatchQueue(label: "com.actionring.script.io", attributes: .concurrent)
            group.enter()
            io.async { outBox.data = outPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            group.enter()
            io.async { errBox.data = errPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }

            // Watchdog: terminate on timeout and record that fact explicitly,
            // rather than inferring it from terminationReason/wallclock. A
            // `finished` flag lets the watchdog no-op once the process exits,
            // avoiding a non-Sendable DispatchWorkItem capture.
            let timedOut = AtomicFlag()
            let finished = AtomicFlag()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutValue) {
                if !finished.isSet, task.isRunning { timedOut.set(); task.terminate() }
            }

            DispatchQueue.global().async {
                task.waitUntilExit()
                finished.set()
                group.wait()   // ensure both pipes fully drained (EOF after exit)
                let didTimeout = timedOut.isSet
                continuation.resume(returning: ScriptResult(
                    output: String(data: outBox.data, encoding: .utf8) ?? "",
                    error: didTimeout
                        ? "Script timed out after \(timeoutValue)s"
                        : (String(data: errBox.data, encoding: .utf8) ?? ""),
                    exitCode: task.terminationStatus,
                    didTimeout: didTimeout,
                    duration: Date().timeIntervalSince(start)
                ))
            }
        }
    }

    // MARK: AppleScript

    public func runAppleScript(script: String) async -> ScriptResult {
        let start = Date()
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ScriptResult(error: "Script is empty", exitCode: -1, duration: Date().timeIntervalSince(start))
        }
        var errorInfo: NSDictionary?
        guard let apple = NSAppleScript(source: trimmed) else {
            return ScriptResult(error: "Failed to compile AppleScript", exitCode: -1, duration: Date().timeIntervalSince(start))
        }
        let output = apple.executeAndReturnError(&errorInfo)
        if let err = errorInfo {
            return ScriptResult(output: output.stringValue ?? "", error: err.description, exitCode: -1, duration: Date().timeIntervalSince(start))
        }
        return ScriptResult(output: output.stringValue ?? "", exitCode: 0, duration: Date().timeIntervalSince(start))
    }

    // MARK: Validation

    public func validateShellScript(_ script: String) -> ScriptValidationResult {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return ScriptValidationResult(isValid: false, error: "Script is empty") }
        let lower = trimmed.lowercased()
        for pattern in Self.dangerousPatterns where lower.contains(pattern.lowercased()) {
            return ScriptValidationResult(isValid: false, error: "Refused: contains dangerous command pattern '\(pattern)'")
        }
        if lower.contains("chmod") && lower.contains("777") {
            return ScriptValidationResult(isValid: false, error: "Refused: chmod 777 is not allowed")
        }
        return ScriptValidationResult(isValid: true)
    }
}

#endif
