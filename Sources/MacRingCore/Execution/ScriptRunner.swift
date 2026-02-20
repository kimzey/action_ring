import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Script Result

/// Result of a script execution
public struct ScriptResult: Sendable {
    /// The script's standard output
    public let output: String

    /// The script's standard error
    public let error: String

    /// The exit code (0 = success)
    public let exitCode: Int32

    /// Whether the execution timed out
    public let didTimeout: Bool

    /// Duration of the execution
    public let duration: TimeInterval

    public init(
        output: String = "",
        error: String = "",
        exitCode: Int32 = 0,
        didTimeout: Bool = false,
        duration: TimeInterval = 0
    ) {
        self.output = output
        self.error = error
        self.exitCode = exitCode
        self.didTimeout = didTimeout
        self.duration = duration
    }

    /// Whether the script executed successfully
    public var isSuccess: Bool {
        exitCode == 0 && !didTimeout
    }
}

// MARK: - Script Validation Result

/// Result of script validation
public struct ScriptValidationResult: Sendable {
    /// Whether the script is safe to execute
    public let isValid: Bool

    /// Validation error message (if invalid)
    public let error: String

    public init(isValid: Bool, error: String = "") {
        self.isValid = isValid
        self.error = error
    }
}

// MARK: - Script Runner

/// Executes shell scripts and AppleScripts safely
public final class ScriptRunner: Sendable {

    // MARK: - Properties

    private let timeout: TimeInterval
    private let workingDirectory: String?
    private let environment: [String: String]?

    // Dangerous command patterns to reject
    private let dangerousPatterns: [String] = [
        "rm -rf /",
        "rm -Rf /",
        "rm -rf ~",
        "rm -Rf ~",
        "rm -rf /usr",
        "rm -Rf /usr",
        "rm -rf /bin",
        "rm -Rf /bin",
        "rm -rf /sbin",
        "rm -Rf /sbin",
        "rm -rf /etc",
        "rm -Rf /etc",
        "rm -rf /var",
        "rm -Rf /var",
        "rm -rf /System",
        "rm -Rf /System",
        "dd if=/dev/zero",
        "dd if=/dev/random",
        "dd if=/dev/urandom",
        ":(){ :|:& };:",  // Fork bomb
        "mv / ~/.",
        "mv /home",
        "mkfs",
        "format c:",
        "del /q /s",
    ]

    // MARK: - Initializers

    /// Create a new ScriptRunner
    /// - Parameters:
    ///   - timeout: Maximum execution time in seconds (default: 30)
    ///   - workingDirectory: Directory to execute scripts in (default: current)
    ///   - environment: Environment variables to pass to scripts
    public init(
        timeout: TimeInterval = 30,
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) {
        self.timeout = timeout
        self.workingDirectory = workingDirectory
        self.environment = environment
    }

    // MARK: - Shell Script Execution

    /// Execute a shell script
    /// - Parameter script: The shell script to execute
    /// - Returns: ScriptResult with output, error, and exit code
    public func runShell(script: String) async -> ScriptResult {
        let startTime = Date()

        // Validate script first
        let validation = await validateShellScript(script)
        guard validation.isValid else {
            return ScriptResult(
                output: "",
                error: validation.error,
                exitCode: -1,
                didTimeout: false,
                duration: Date().timeIntervalSince(startTime)
            )
        }

        // Trim and check for empty script
        let trimmedScript = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedScript.isEmpty else {
            return ScriptResult(
                output: "",
                error: "Script is empty",
                exitCode: -1,
                didTimeout: false,
                duration: Date().timeIntervalSince(startTime)
            )
        }

        return await withCheckedContinuation { continuation in
            let task = Process()
            let pipe = Pipe()
            let errorPipe = Pipe()

            task.standardOutput = pipe
            task.standardError = errorPipe

            // Use /bin/sh for POSIX compatibility
            #if os(macOS)
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            #elseif os(Linux)
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            #else
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            #endif

            task.arguments = ["-c", trimmedScript]

            // Set working directory if specified
            if let workingDir = workingDirectory {
                task.currentDirectoryURL = URL(fileURLWithPath: workingDir)
            }

            // Set environment
            if let env = environment {
                var updatedEnv = ProcessInfo.processInfo.environment
                for (key, value) in env {
                    updatedEnv[key] = value
                }
                task.environment = updatedEnv
            }

            // Set up timeout
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if task.isRunning {
                    task.terminate()
                    continuation.resume(returning: ScriptResult(
                        output: "",
                        error: "Script execution timed out after \(timeout)s",
                        exitCode: -2,
                        didTimeout: true,
                        duration: Date().timeIntervalSince(startTime)
                    ))
                }
            }

            do {
                try task.run()

                // Read output
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                task.waitUntilExit()

                timeoutTask.cancel()

                continuation.resume(returning: ScriptResult(
                    output: output,
                    error: error,
                    exitCode: task.terminationStatus,
                    didTimeout: false,
                    duration: Date().timeIntervalSince(startTime)
                ))

            } catch {
                timeoutTask.cancel()
                continuation.resume(returning: ScriptResult(
                    output: "",
                    error: "Failed to execute script: \(error.localizedDescription)",
                    exitCode: -1,
                    didTimeout: false,
                    duration: Date().timeIntervalSince(startTime)
                ))
            }
        }
    }

    // MARK: - AppleScript Execution

    /// Execute an AppleScript
    /// - Parameter script: The AppleScript to execute
    /// - Returns: ScriptResult with output, error, and exit code
    public func runAppleScript(script: String) async -> ScriptResult {
        let startTime = Date()

        let trimmedScript = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedScript.isEmpty else {
            return ScriptResult(
                output: "",
                error: "Script is empty",
                exitCode: -1,
                didTimeout: false,
                duration: Date().timeIntervalSince(startTime)
            )
        }

        return await withCheckedContinuation { continuation in
            let appleScript = NSAppleScript(source: trimmedScript)

            // Execute with timeout
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                continuation.resume(returning: ScriptResult(
                    output: "",
                    error: "AppleScript execution timed out after \(timeout)s",
                    exitCode: -2,
                    didTimeout: true,
                    duration: Date().timeIntervalSince(startTime)
                ))
            }

            var errorInfo: NSDictionary?
            let output = appleScript.executeAndReturnError(&errorInfo)

            timeoutTask.cancel()

            if let error = errorInfo {
                continuation.resume(returning: ScriptResult(
                    output: output.stringValue ?? "",
                    error: error.description,
                    exitCode: -1,
                    didTimeout: false,
                    duration: Date().timeIntervalSince(startTime)
                ))
            } else {
                continuation.resume(returning: ScriptResult(
                    output: output.stringValue ?? "",
                    error: "",
                    exitCode: 0,
                    didTimeout: false,
                    duration: Date().timeIntervalSince(startTime)
                ))
            }
        }
    }

    // MARK: - Script Validation

    /// Validate a shell script for safety
    /// - Parameter script: The shell script to validate
    /// - Returns: ScriptValidationResult indicating if the script is safe
    public func validateShellScript(_ script: String) async -> ScriptValidationResult {
        let trimmedScript = script.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for empty script
        if trimmedScript.isEmpty {
            return ScriptValidationResult(
                isValid: false,
                error: "Script is empty"
            )
        }

        // Check for dangerous patterns
        let lowercased = trimmedScript.lowercased()
        for pattern in dangerousPatterns {
            if lowercased.contains(pattern.lowercased()) {
                return ScriptValidationResult(
                    isValid: false,
                    error: "Script contains dangerous command: \(pattern)"
                )
            }
        }

        // Check for suspicious combinations
        // This is a basic check - production systems should use more comprehensive validation
        if lowercased.contains("chmod") && lowercased.contains("777") {
            return ScriptValidationResult(
                isValid: false,
                error: "Setting 777 permissions is not allowed"
            )
        }

        return ScriptValidationResult(isValid: true)
    }

    // MARK: - Batch Execution

    /// Execute multiple scripts in sequence
    /// - Parameter scripts: Array of shell scripts to execute
    /// - Returns: Array of ScriptResults in the same order
    public func runBatch(scripts: [String]) async -> [ScriptResult] {
        var results: [ScriptResult] = []

        for script in scripts {
            let result = await runShell(script: script)
            results.append(result)

            // Stop if a script fails
            if !result.isSuccess {
                break
            }
        }

        return results
    }
}

#endif
