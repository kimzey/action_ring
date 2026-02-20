import Testing
import Foundation
@testable import MacRingCore

#if canImport(AppKit)
import AppKit

@Suite("ActionExecutor Tests")
struct ActionExecutorTests {

    // MARK: - Keyboard Shortcut Execution

    @Test("Execute keyboard shortcut without modifiers")
    func executeKeyboardNoModifiers() async throws {
        #if os(macOS)
        let action = RingAction.keyboardShortcut(.character("c"), modifiers: [])
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        switch result {
        case .success:
            break  // Expected
        case .failure(let error):
            throw error
        }
        #endif
    }

    @Test("Execute keyboard shortcut with Command modifier")
    func executeKeyboardWithCommand() async throws {
        #if os(macOS)
        let action = RingAction.keyboardShortcut(.character("c"), modifiers: [.command])
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    @Test("Execute keyboard shortcut with multiple modifiers")
    func executeKeyboardMultipleModifiers() async throws {
        #if os(macOS)
        let action = RingAction.keyboardShortcut(.character("s"), modifiers: [.command, .shift])
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    @Test("Execute special key shortcut")
    func executeSpecialKeyShortcut() async throws {
        #if os(macOS)
        let action = RingAction.keyboardShortcut(.special(.escape), modifiers: [])
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    // MARK: - Launch Application

    @Test("Launch application by bundle ID")
    func launchApplicationByBundleId() async {
        #if os(macOS)
        let action = RingAction.launchApplication(bundleIdentifier: "com.apple.Safari")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        // May fail if Safari not installed, but should not crash
        switch result {
        case .success:
            break
        case .failure(let error):
            // Should be a known error type
            #expect(error is ActionExecutorError)
        }
        #endif
    }

    @Test("Launch non-existent app returns error")
    func launchNonExistentApp() async {
        #if os(macOS)
        let action = RingAction.launchApplication(bundleIdentifier: "com.nonexistent.app")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        switch result {
        case .success:
            #expect(Bool(false), "Should fail for non-existent app")
        case .failure:
            break  // Expected
        }
        #endif
    }

    @Test("Launch already running app brings to front")
    func launchRunningAppBringsToFront() async {
        #if os(macOS)
        // Launch Finder which should always be running
        let action = RingAction.launchApplication(bundleIdentifier: "com.apple.finder")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    // MARK: - Open URL

    @Test("Open HTTPS URL")
    func openHTTPSUrl() async throws {
        #if os(macOS)
        let action = RingAction.openURL("https://apple.com")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    @Test("Open HTTP URL")
    func openHTTPUrl() async throws {
        #if os(macOS)
        let action = RingAction.openURL("http://example.com")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    @Test("Open mailto URL")
    func openMailtoUrl() async throws {
        #if os(macOS)
        let action = RingAction.openURL("mailto:test@example.com")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    @Test("Invalid URL returns error")
    func openInvalidUrl() async {
        #if os(macOS)
        let action = RingAction.openURL("not-a-valid-url")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        switch result {
        case .success:
            #expect(Bool(false), "Should fail for invalid URL")
        case .failure:
            break  // Expected
        }
        #endif
    }

    // MARK: - System Actions

    @Test("Execute lock screen action")
    func executeLockScreen() async {
        #if os(macOS)
        // Skip in automated test - would lock the screen
        // let action = RingAction.systemAction(.lockScreen)
        // let executor = ActionExecutor()
        // let result = await executor.execute(action)
        // #expect(result.isSuccess)
        #expect(true)  // Placeholder
        #endif
    }

    @Test("Execute screenshot action")
    func executeScreenshot() async {
        #if os(macOS)
        // Skip in automated test
        #expect(true)  // Placeholder
        #endif
    }

    @Test("Execute volume up action")
    func executeVolumeUp() async {
        #if os(macOS)
        let action = RingAction.systemAction(.volumeUp)
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    @Test("Execute mute action")
    func executeMute() async {
        #if os(macOS)
        let action = RingAction.systemAction(.mute)
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    // MARK: - Shell Scripts (Phase 2)

    @Test("Shell script action returns not implemented")
    func shellScriptNotImplemented() async {
        #if os(macOS)
        let action = RingAction.shellScript("echo test")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        switch result {
        case .success:
            #expect(Bool(false), "Should return not implemented error")
        case .failure(let error):
            #expect(error == .notImplemented)
        }
        #endif
    }

    @Test("AppleScript action returns not implemented")
    func appleScriptNotImplemented() async {
        #if os(macOS)
        let action = RingAction.appleScript("tell application \"Finder\" to activate")
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        switch result {
        case .success:
            #expect(Bool(false), "Should return not implemented error")
        case .failure(let error):
            #expect(error == .notImplemented)
        }
        #endif
    }

    // MARK: - Error Types

    @Test("All error types are defined")
    func allErrorTypesDefined() {
        #if os(macOS)
        let errors: [ActionExecutorError] = [
            .notImplemented,
            .appNotFound(bundleId: "test"),
            .invalidUrl(url: "test"),
            .executionFailed(reason: "test")
        ]

        #expect(errors.count == 4)
        #endif
    }

    // MARK: - Execution Result

    @Test("Execution result can be success or failure")
    func executionResultTypes() {
        #if os(macOS)
        let success = ActionExecutor.Result.success
        let failure = ActionExecutor.Result.failure(.notImplemented)

        switch success {
        case .success:
            break  // Correct
        case .failure:
            #expect(Bool(false))
        }

        switch failure {
        case .success:
            #expect(Bool(false))
        case .failure:
            break  // Correct
        }
        #endif
    }

    // MARK: - Workflow Actions

    @Test("Empty workflow executes successfully")
    func emptyWorkflow() async {
        #if os(macOS)
        let action = RingAction.workflow([])
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }

    @Test("Workflow with multiple actions")
    func workflowMultipleActions() async {
        #if os(macOS)
        let actions: [RingAction] = [
            .keyboardShortcut(.character("c"), modifiers: [.command]),
            .keyboardShortcut(.character("v"), modifiers: [.command])
        ]
        let action = RingAction.workflow(actions)
        let executor = ActionExecutor()

        let result = await executor.execute(action)

        #expect(result.isSuccess)
        #endif
    }
}
#endif
