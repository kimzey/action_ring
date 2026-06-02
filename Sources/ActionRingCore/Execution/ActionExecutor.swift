import Foundation
#if canImport(AppKit)
import AppKit

// MARK: - Options

public struct ScriptExecutionOptions: Sendable {
    public var timeout: TimeInterval
    public var workingDirectory: String?
    public var environment: [String: String]?
    public init(timeout: TimeInterval = 10, workingDirectory: String? = nil, environment: [String: String]? = nil) {
        self.timeout = timeout
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

// MARK: - Errors / Result

public enum ActionExecutorError: Error, Equatable, Sendable {
    case notImplemented
    case appNotFound(bundleId: String)
    case invalidUrl(url: String)
    case executionFailed(reason: String)
    case systemActionNotSupported(action: String)
    case scriptValidationFailed(reason: String)
    case scriptTimeout
    case eventSourceUnavailable
}

public enum ActionExecutorResult: Sendable, Equatable {
    case success
    case failure(ActionExecutorError)

    public var isSuccess: Bool { if case .success = self { return true }; return false }
    public var isFailure: Bool { !isSuccess }
}

// MARK: - Action Executor

/// Performs `RingAction`s: keyboard shortcuts, app launches, URLs, system
/// actions, scripts, text, files, and workflows.
///
/// All keystroke synthesis is posted to `.cghidEventTap` so the events look
/// like real hardware input to the focused app.
public final class ActionExecutor: @unchecked Sendable {

    private let scriptRunner: ScriptRunner
    private let options: ScriptExecutionOptions

    public init(scriptOptions: ScriptExecutionOptions = ScriptExecutionOptions()) {
        self.options = scriptOptions
        self.scriptRunner = ScriptRunner(
            timeout: scriptOptions.timeout,
            workingDirectory: scriptOptions.workingDirectory,
            environment: scriptOptions.environment
        )
    }

    // MARK: Dispatch

    @discardableResult
    public func execute(_ action: RingAction) async -> ActionExecutorResult {
        switch action {
        case .keyboardShortcut(let key, let mods):
            return executeKeyboardShortcut(keyCode: key, modifiers: mods)
        case .launchApplication(let bundleId):
            return await launchApplication(bundleIdentifier: bundleId)
        case .openURL(let url):
            return openURL(url)
        case .systemAction(let a):
            return await executeSystemAction(a)
        case .shellScript(let s):
            return await executeShellScript(s)
        case .appleScript(let s):
            return await executeAppleScript(s)
        case .shortcutsApp(let name):
            return await executeShortcut(named: name)
        case .textSnippet(let text):
            return typeText(text)
        case .openFile(let path):
            return openFile(path)
        case .workflow(let actions):
            return await executeWorkflow(actions)
        case .mcpToolCall, .mcpWorkflow:
            return .failure(.notImplemented)
        }
    }

    // MARK: Keyboard

    private func flags(for modifiers: [KeyModifier]) -> CGEventFlags {
        var f: CGEventFlags = []
        for m in modifiers {
            switch m {
            case .command: f.insert(.maskCommand)
            case .shift: f.insert(.maskShift)
            case .option: f.insert(.maskAlternate)
            case .control: f.insert(.maskControl)
            case .capsLock: f.insert(.maskAlphaShift)
            case .function: f.insert(.maskSecondaryFn)
            }
        }
        return f
    }

    private func executeKeyboardShortcut(keyCode: KeyCode, modifiers: [KeyModifier]) -> ActionExecutorResult {
        guard let resolved = KeyCodeMap.resolve(keyCode) else {
            // Not on the ANSI layout — fall back to typing it as text.
            if case .character(let ch) = keyCode { return typeText(String(ch)) }
            return .failure(.executionFailed(reason: "Unmapped key"))
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return .failure(.eventSourceUnavailable)
        }
        var f = flags(for: modifiers)
        if resolved.needsShift { f.insert(.maskShift) }

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(resolved.code), keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(resolved.code), keyDown: false)
        else { return .failure(.executionFailed(reason: "Failed to create key events")) }

        down.flags = f
        up.flags = f
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return .success
    }

    /// Type arbitrary text (Unicode-safe) by posting per-character key events
    /// with an attached unicode string. Avoids keycode/layout issues.
    private func typeText(_ text: String) -> ActionExecutorResult {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return .failure(.eventSourceUnavailable)
        }
        for scalar in text.unicodeScalars {
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { return .failure(.executionFailed(reason: "Failed to create text events")) }
            var units = Array(String(scalar).utf16)
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
        return .success
    }

    // MARK: System actions

    /// Posts a system-defined media/hardware key (volume, brightness, media
    /// transport) the way the physical keyboard does.
    private func postMediaKey(_ keyCode: Int32) -> ActionExecutorResult {
        func event(down: Bool) -> CGEvent? {
            // Canonical media-key idiom: for NSSystemDefined subtype-8 events the
            // key state is carried in BOTH the flags field (0xA00 down / 0xB00 up)
            // and data1's second byte. This is the documented working pattern —
            // do not "simplify" the flags to 0; that breaks the events.
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = Int((keyCode << 16) | ((down ? 0xA : 0xB) << 8))
            guard let ns = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { return nil }
            return ns.cgEvent
        }
        guard let down = event(down: true), let up = event(down: false) else {
            return .failure(.executionFailed(reason: "Failed to create media key event"))
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return .success
    }

    private func executeSystemAction(_ action: SystemAction) async -> ActionExecutorResult {
        // NX_KEYTYPE constants from <IOKit/hidsystem/ev_keymap.h>.
        switch action {
        case .volumeUp:        return postMediaKey(0)
        case .volumeDown:      return postMediaKey(1)
        case .mute:            return postMediaKey(7)
        case .brightnessUp:    return postMediaKey(2)
        case .brightnessDown:  return postMediaKey(3)
        case .mediaPlayPause:  return postMediaKey(16)
        case .mediaNext:       return postMediaKey(17)
        case .mediaPrevious:   return postMediaKey(18)

        case .lockScreen:
            return executeKeyboardShortcut(keyCode: .character("q"), modifiers: [.control, .command])
        case .screenshot:
            return executeKeyboardShortcut(keyCode: .character("3"), modifiers: [.command, .shift])
        case .screenshotArea:
            return executeKeyboardShortcut(keyCode: .character("4"), modifiers: [.command, .shift])
        case .missionControl:
            return executeKeyboardShortcut(keyCode: .special(.upArrow), modifiers: [.control])
        case .showDesktop:
            return executeKeyboardShortcut(keyCode: .special(.f11), modifiers: [])
        case .launchpad:
            return await launchApplication(bundleIdentifier: "com.apple.launchpad.launcher")
        case .sleep:
            return await executeShellScript("pmset sleepnow")
        case .notificationCenter:
            return .failure(.systemActionNotSupported(action: "notificationCenter"))
        }
    }

    // MARK: Apps / URLs / files

    private func launchApplication(bundleIdentifier: String) async -> ActionExecutorResult {
        let workspace = NSWorkspace.shared
        if let running = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            running.activate()
            return .success
        }
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return .failure(.appNotFound(bundleId: bundleIdentifier))
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        do {
            try await workspace.openApplication(at: url, configuration: config)
            return .success
        } catch {
            return .failure(.executionFailed(reason: error.localizedDescription))
        }
    }

    private func openURL(_ urlString: String) -> ActionExecutorResult {
        guard let url = URL(string: urlString) else { return .failure(.invalidUrl(url: urlString)) }
        return NSWorkspace.shared.open(url) ? .success : .failure(.invalidUrl(url: urlString))
    }

    private func openFile(_ path: String) -> ActionExecutorResult {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            return .failure(.executionFailed(reason: "File not found: \(expanded)"))
        }
        return NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
            ? .success : .failure(.executionFailed(reason: "Failed to open: \(expanded)"))
    }

    // MARK: Scripts

    private func executeShellScript(_ script: String) async -> ActionExecutorResult {
        let validation = scriptRunner.validateShellScript(script)
        guard validation.isValid else { return .failure(.scriptValidationFailed(reason: validation.error)) }
        let r = await scriptRunner.runShell(script: script)
        if r.didTimeout { return .failure(.scriptTimeout) }
        return r.isSuccess ? .success
            : .failure(.executionFailed(reason: r.error.isEmpty ? "Exit code \(r.exitCode)" : r.error))
    }

    private func executeAppleScript(_ script: String) async -> ActionExecutorResult {
        let r = await scriptRunner.runAppleScript(script: script)
        if r.didTimeout { return .failure(.scriptTimeout) }
        return r.isSuccess ? .success : .failure(.executionFailed(reason: r.error.isEmpty ? "AppleScript failed" : r.error))
    }

    private func executeShortcut(named name: String) async -> ActionExecutorResult {
        // Escape backslashes BEFORE quotes, else an embedded \" or trailing \
        // breaks out of the AppleScript string literal.
        let escaped = name
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return await executeAppleScript(#"tell application "Shortcuts Events" to run shortcut "\#(escaped)""#)
    }

    // MARK: Workflow

    /// Run a sequence of actions, stopping at the first failure.
    public func executeWorkflow(_ actions: [RingAction]) async -> ActionExecutorResult {
        for action in actions {
            let result = await execute(action)
            if case .failure(let err) = result { return .failure(err) }
            // Small gap so the target app can process each keystroke.
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        return .success
    }
}

#endif
