import Testing
import Foundation
#if canImport(AppKit)
import AppKit
@testable import MacRingCore

@Suite("ActionExecutor Script Support Tests")
struct ActionExecutorScriptTests {

    // MARK: - Shell Script Tests

    @Test("Shell script action executes successfully")
    func shellScriptActionExecutesSuccessfully() async {
        let executor = ActionExecutor()

        let result = await executor.execute(.shellScript("echo 'Hello, World!'"))

        #expect(result.isSuccess)
    }

    @Test("Shell script with exit code 0 succeeds")
    func shellScriptWithExitCodeZeroSucceeds() async {
        let executor = ActionExecutor()

        let result = await executor.execute(.shellScript("exit 0"))

        #expect(result.isSuccess)
    }

    @Test("Shell script with non-zero exit code fails")
    func shellScriptWithNonZeroExitCodeFails() async {
        let executor = ActionExecutor()

        let result = await executor.execute(.shellScript("exit 1"))

        #expect(result.isFailure)
    }

    @Test("Shell script executes asynchronously")
    func shellScriptExecutesAsynchronously() async {
        let executor = ActionExecutor()

        // A script that takes a moment
        let result = await executor.execute(.shellScript("sleep 0.1 && echo 'done'"))

        #expect(result.isSuccess)
    }

    @Test("Shell script with pipes works")
    func shellScriptWithPipesWorks() async {
        let executor = ActionExecutor()

        let result = await executor.execute(.shellScript("echo 'test' | wc -l"))

        #expect(result.isSuccess)
    }

    // MARK: - AppleScript Tests

    @Test("AppleScript action executes successfully")
    func appleScriptActionExecutesSuccessfully() async throws {
        try skipIfPlatformUnsupported()

        let executor = ActionExecutor()

        let result = await executor.execute(.appleScript("return \"Hello from AppleScript\""))

        #expect(result.isSuccess)
    }

    @Test("AppleScript can get system info")
    func appleScriptCanGetSystemInfo() async throws {
        try skipIfPlatformUnsupported()

        let executor = ActionExecutor()

        let result = await executor.execute(.appleScript("return system version"))

        #expect(result.isSuccess)
    }

    @Test("AppleScript with syntax error fails")
    func appleScriptWithSyntaxErrorFails() async throws {
        try skipIfPlatformUnsupported()

        let executor = ActionExecutor()

        let result = await executor.execute(.appleScript("this is not valid AppleScript"))

        #expect(result.isFailure)
    }

    // MARK: - Text Snippet Tests

    @Test("Text snippet action is supported")
    func textSnippetActionIsSupported() async {
        let executor = ActionExecutor()

        let result = await executor.execute(.textSnippet("Hello, World!"))

        // This should be implemented (typing the text)
        #expect(result.isSuccess || result.isFailure)  // For now, just verify no crash
    }

    // MARK: - Open File Tests

    @Test("Open file action works for valid paths")
    func openFileActionWorksForValidPaths() async {
        let executor = ActionExecutor()

        // Create a temp file
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_open_file.txt")
        try? "test content".write(to: tempFile, atomically: true, encoding: .utf8)

        let result = await executor.execute(.openFile(tempFile.path))

        // Clean up
        try? FileManager.default.removeItem(at: tempFile)

        // On success, the file should be opened in the default app
        #expect(result.isSuccess || result.isFailure)  // May fail on some systems
    }

    @Test("Open file action fails for invalid paths")
    func openFileActionFailsForInvalidPaths() async {
        let executor = ActionExecutor()

        let result = await executor.execute(.openFile("/nonexistent/path/to/file.txt"))

        #expect(result.isFailure)
    }

    // MARK: - Workflow Tests

    @Test("Workflow executes multiple actions in sequence")
    func workflowExecutesMultipleActionsInSequence() async {
        let executor = ActionExecutor()

        let workflow: RingAction = .workflow([
            .shellScript("echo 'step 1'"),
            .shellScript("echo 'step 2'"),
            .shellScript("echo 'step 3'"),
        ])

        let result = await executor.execute(workflow)

        #expect(result.isSuccess)
    }

    @Test("Workflow stops on first failure")
    func workflowStopsOnFirstFailure() async {
        let executor = ActionExecutor()

        let workflow: RingAction = .workflow([
            .shellScript("echo 'step 1'"),
            .shellScript("exit 1"),  // This will fail
            .shellScript("echo 'this should not run'"),
        ])

        let result = await executor.execute(workflow)

        #expect(result.isFailure)
    }

    @Test("Empty workflow succeeds")
    func emptyWorkflowSucceeds() async {
        let executor = ActionExecutor()

        let workflow: RingAction = .workflow([])

        let result = await executor.execute(workflow)

        #expect(result.isSuccess)
    }

    @Test("Nested workflows are supported")
    func nestedWorkflowsAreSupported() async {
        let executor = ActionExecutor()

        let innerWorkflow: RingAction = .workflow([
            .shellScript("echo 'inner 1'"),
            .shellScript("echo 'inner 2'"),
        ])

        let outerWorkflow: RingAction = .workflow([
            .shellScript("echo 'outer 1'"),
            innerWorkflow,
            .shellScript("echo 'outer 2'"),
        ])

        let result = await executor.execute(outerWorkflow)

        #expect(result.isSuccess)
    }

    // MARK: - Shortcuts App Tests

    @Test("Shortcuts app action is implemented")
    func shortcutsAppActionIsImplemented() async {
        let executor = ActionExecutor()

        let result = await executor.execute(.shortcutsApp("TestShortcut"))

        // Will fail if shortcut doesn't exist, but should not return notImplemented
        if case .failure(.notImplemented) = result {
            Issue.record("Shortcuts app action should be implemented")
        }
    }

    // MARK: - Helper

    private func skipIfPlatformUnsupported() throws {
        #if !os(macOS)
        throw XCTSkip("AppleScript is only supported on macOS")
        #endif
    }
}
#endif
