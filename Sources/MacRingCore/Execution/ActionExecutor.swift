import Foundation
#if canImport(AppKit)
import AppKit
import Carbon

// MARK: - Script Execution Options

/// Options for script execution
public struct ScriptExecutionOptions: Sendable {
    /// Timeout in seconds (default: 30)
    public var timeout: TimeInterval

    /// Working directory for script execution
    public var workingDirectory: String?

    /// Environment variables to pass to scripts
    public var environment: [String: String]?

    public init(
        timeout: TimeInterval = 30,
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) {
        self.timeout = timeout
        self.workingDirectory = workingDirectory
        self.environment = environment
    }
}

// MARK: - Action Executor Error

/// Errors that can occur during action execution
public enum ActionExecutorError: Error, Equatable, Sendable {
    case notImplemented
    case appNotFound(bundleId: String)
    case invalidUrl(url: String)
    case executionFailed(reason: String)
    case systemActionNotSupported(action: String)
    case scriptValidationFailed(reason: String)
    case scriptTimeout
}

// MARK: - Execution Result

/// Result of executing an action
public enum ActionExecutorResult: Sendable {
    case success
    case failure(ActionExecutorError)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var isFailure: Bool {
        !isSuccess
    }
}

// MARK: - Action Executor

/// Executes ring actions: keyboard shortcuts, app launches, URLs, system actions, scripts
public final class ActionExecutor {

    // MARK: - Properties

    private let scriptRunner: ScriptRunner
    private let scriptOptions: ScriptExecutionOptions

    // MARK: - Initializers

    public init(scriptOptions: ScriptExecutionOptions = ScriptExecutionOptions()) {
        self.scriptOptions = scriptOptions
        self.scriptRunner = ScriptRunner(
            timeout: scriptOptions.timeout,
            workingDirectory: scriptOptions.workingDirectory,
            environment: scriptOptions.environment
        )
    }

    // MARK: - Execute Action

    // MARK: - Execute Action

    /// Execute a ring action
    /// - Parameter action: The action to execute
    /// - Returns: Result indicating success or failure
    public func execute(_ action: RingAction) async -> ActionExecutorResult {
        switch action {
        case .keyboardShortcut(let keyCode, let modifiers):
            await executeKeyboardShortcut(keyCode: keyCode, modifiers: modifiers)

        case .launchApplication(let bundleIdentifier):
            await launchApplication(bundleIdentifier: bundleIdentifier)

        case .openURL(let url):
            await openURL(url)

        case .systemAction(let systemAction):
            await executeSystemAction(systemAction)

        case .shellScript(let script):
            await executeShellScript(script)

        case .appleScript(let script):
            await executeAppleScript(script)

        case .shortcutsApp(let shortcutName):
            await executeShortcutsApp(shortcutName)

        case .textSnippet(let text):
            await executeTextSnippet(text)

        case .openFile(let path):
            await openFile(path)

        case .workflow(let actions):
            await executeWorkflow(actions)

        case .mcpToolCall, .mcpWorkflow:
            return .failure(.notImplemented)
        }
    }

    // MARK: - Shell Scripts

    private func executeShellScript(_ script: String) async -> ActionExecutorResult {
        // Validate script first
        let validation = await scriptRunner.validateShellScript(script)
        guard validation.isValid else {
            return .failure(.scriptValidationFailed(reason: validation.error))
        }

        // Execute script
        let result = await scriptRunner.runShell(script: script)

        if result.didTimeout {
            return .failure(.scriptTimeout)
        }

        if result.isSuccess {
            return .success
        } else {
            return .failure(.executionFailed(reason: result.error.isEmpty ? "Script failed with exit code \(result.exitCode)" : result.error))
        }
    }

    // MARK: - AppleScript

    private func executeAppleScript(_ script: String) async -> ActionExecutorResult {
        let result = await scriptRunner.runAppleScript(script: script)

        if result.didTimeout {
            return .failure(.scriptTimeout)
        }

        if result.isSuccess {
            return .success
        } else {
            return .failure(.executionFailed(reason: result.error.isEmpty ? "AppleScript failed" : result.error))
        }
    }

    // MARK: - Shortcuts App

    private func executeShortcutsApp(_ shortcutName: String) async -> ActionExecutorResult {
        let script = """
        tell application "Shortcuts Events"
            run the shortcut named "\(shortcutName.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """

        return await executeAppleScript(script)
    }

    // MARK: - Text Snippet

    private func executeTextSnippet(_ text: String) async -> ActionExecutorResult {
        // Type the text character by character using keyboard events
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return .failure(.executionFailed(reason: "Failed to create event source"))
        }

        for character in text {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            guard let keyDownEvent = keyDown, let keyUpEvent = keyUp else {
                return .failure(.executionFailed(reason: "Failed to create keyboard events"))
            }

            // Get key code for this character
            let keyCode = getVirtualKeyCode(for: .character(character))

            keyDownEvent.setIntegerValueField(.keyboardEventKeycode, value: keyCode)
            keyUpEvent.setIntegerValueField(.keyboardEventKeycode, value: keyCode)

            // Handle shift for uppercase
            if character.isUppercase {
                keyDownEvent.flags.insert(.maskShift)
                keyUpEvent.flags.insert(.maskShift)
            }

            keyDownEvent.post(tap: .cghidEventTap)
            keyUpEvent.post(tap: .cghidEventTap)

            // Small delay between keystrokes for natural typing
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }

        return .success
    }

    // MARK: - Open File

    private func openFile(_ path: String) async -> ActionExecutorResult {
        let fileURL = URL(fileURLWithPath: path)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.executionFailed(reason: "File not found: \(path)"))
        }

        let workspace = NSWorkspace.shared
        if workspace.open(fileURL) {
            return .success
        } else {
            return .failure(.executionFailed(reason: "Failed to open file: \(path)"))
        }
    }

    // MARK: - Keyboard Shortcuts

    private func executeKeyboardShortcut(
        keyCode: KeyCode,
        modifiers: [KeyModifier]
    ) async -> ActionExecutorResult {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return .failure(.executionFailed(reason: "Failed to create event source"))
        }

        // Create key down event
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

        guard let keyDownEvent = keyDown, let keyUpEvent = keyUp else {
            return .failure(.executionFailed(reason: "Failed to create keyboard events"))
        }

        // Set modifiers
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier {
            case .command: flags.insert(.maskCommand)
            case .shift: flags.insert(.maskShift)
            case .option: flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            case .capsLock: flags.insert(.maskAlphaShift)
            case .function: break  // Function key handled differently
            }
        }
        keyDownEvent.flags = flags
        keyUpEvent.flags = flags

        // Set key code
        let keyCodeValue = getVirtualKeyCode(for: keyCode)
        keyDownEvent.setIntegerValueField(.keyboardEventKeycode, value: keyCodeValue)
        keyUpEvent.setIntegerValueField(.keyboardEventKeycode, value: keyCodeValue)

        // Post events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)

        return .success
    }

    private func getVirtualKeyCode(for keyCode: KeyCode) -> Int32 {
        switch keyCode {
        case .character(let char):
            // Map common characters to key codes
            let lowercase = char.lowercased()
            let scalar = lowercase.unicodeScalars.first
            let value = scalar?.value ?? 0

            // a-z are 0-25
            if value >= 97 && value <= 122 {
                return Int32(value - 97)
            }
            // 0-9 are 29-38
            if value >= 48 && value <= 57 {
                return Int32(value - 48 + 29)
            }
            return 0  // Default to 'a'

        case .special(let specialKey):
            switch specialKey {
            case .enter: return 36
            case .tab: return 48
            case .space: return 49
            case .escape: return 53
            case .delete: return 51
            case .backspace: return 51
            case .home: return 115
            case .end: return 119
            case .pageUp: return 116
            case .pageDown: return 121
            case .leftArrow: return 123
            case .rightArrow: return 124
            case .upArrow: return 126
            case .downArrow: return 125
            case .f1: return 122
            case .f2: return 120
            case .f3: return 99
            case .f4: return 118
            case .f5: return 96
            case .f6: return 97
            case .f7: return 98
            case .f8: return 100
            case .f9: return 101
            case .f10: return 109
            case .f11: return 103
            case .f12: return 111
            }
        }
    }

    // MARK: - Launch Application

    private func launchApplication(bundleIdentifier: String) async -> ActionExecutorResult {
        let workspace = NSWorkspace.shared

        // Check if app is running
        let runningApps = workspace.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            // App is running, bring to front
            app.activate(options: [.activateIgnoringOtherApps])
            return .success
        }

        // Try to launch app
        do {
            try workspace.launchApplication(
                withBundleIdentifier: bundleIdentifier,
                options: [.async, .activateIgnoringOtherApps],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
            return .success
        } catch {
            return .failure(.appNotFound(bundleId: bundleIdentifier))
        }
    }

    // MARK: - Open URL

    private func openURL(_ urlString: String) async -> ActionExecutorResult {
        guard let url = URL(string: urlString) else {
            return .failure(.invalidUrl(url: urlString))
        }

        let workspace = NSWorkspace.shared
        if workspace.open(url) {
            return .success
        } else {
            return .failure(.invalidUrl(url: urlString))
        }
    }

    // MARK: - System Actions

    private func executeSystemAction(_ action: SystemAction) async -> ActionExecutorResult {
        let workspace = NSWorkspace.shared

        switch action {
        case .lockScreen:
            // Use screen saver engine to lock screen
            workspace.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?RequirePassword")!)
            return .success

        case .screenshot:
            // Trigger screenshot via hotkey
            await executeKeyboardShortcut(
                keyCode: .special(.f1),  // This is approximate
                modifiers: []
            )
            return .success

        case .volumeUp:
            // Adjust volume via key press
            await executeKeyboardShortcut(
                keyCode: .special(.upArrow),
                modifiers: []
            )
            return .success

        case .volumeDown:
            await executeKeyboardShortcut(
                keyCode: .special(.downArrow),
                modifiers: []
            )
            return .success

        case .mute:
            await executeKeyboardShortcut(
                keyCode: .character("m"),
                modifiers: [.shift]  // Shift+M for some keyboards
            )
            return .success

        case .brightnessUp:
            await executeKeyboardShortcut(
                keyCode: .special(.upArrow),
                modifiers: []
            )
            return .success

        case .brightnessDown:
            await executeKeyboardShortcut(
                keyCode: .special(.downArrow),
                modifiers: []
            )
            return .success

        case .missionControl:
            // Trigger Mission Control via CGEvent
            await executeKeyboardShortcut(
                keyCode: .character(" "),
                modifiers: [.control]  // Ctrl+Up for Mission Control
            )
            return .success

        case .showDesktop:
            // F11 shortcut
            await executeKeyboardShortcut(
                keyCode: .special(.f11),
                modifiers: []
            )
            return .success

        case .launchpad:
            await executeKeyboardShortcut(
                keyCode: .character("l"),
                modifiers: []
            )
            return .success

        case .notificationCenter:
            // Two-finger swipe from right or click
            return .failure(.systemActionNotSupported(action: "notificationCenter"))

        case .sleep:
            // Put system to sleep
            workspace.open(URL(string: "x-apple.systempreferences:com.apple.preference.energysaver")!)
            return .success

        case .restart:
            // Initiate restart (requires confirmation)
            let appleScript = """
            tell application "System Events" to restart
            """
            return await executeAppleScriptSandbox(appleScript)

        case .shutdown:
            let appleScript = """
            tell application "System Events" to shut down
            """
            return await executeAppleScriptSandbox(appleScript)
        }
    }

    // MARK: - Helper: Execute AppleScript

    private func executeAppleScriptSandbox(_ script: String) async -> ActionExecutorResult {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return .success
            } else {
                return .failure(.executionFailed(reason: error?.description ?? "Unknown error"))
            }
        }
        return .failure(.executionFailed(reason: "Failed to create script"))
    }

    // MARK: - Workflow Execution

    /// Execute a workflow (sequence of actions)
    public func executeWorkflow(_ actions: [RingAction]) async -> ActionExecutorResult {
        for action in actions {
            let result = await execute(action)

            // Handle nested workflows
            if case .workflow(let nestedActions) = action {
                let nestedResult = await executeWorkflow(nestedActions)
                if case .failure(let error) = nestedResult {
                    return .failure(error)
                }
            } else {
                // Check if this action failed
                if case .failure(let error) = result {
                    return .failure(error)
                }
            }
        }
        return .success
    }

    private func executeWorkflow(_ actions: [RingAction]) async -> ActionExecutorResult {
        for action in actions {
            let result = await execute(action)
            if case .failure(let error) = result {
                return .failure(error)
            }
        }
        return .success
    }
}

// MARK: - Result Type Alias

extension ActionExecutor {
    public typealias Result = ActionExecutorResult
}

#endif
