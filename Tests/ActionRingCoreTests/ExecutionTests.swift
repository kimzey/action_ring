import XCTest
@testable import ActionRingCore

final class ExecutionTests: XCTestCase {

    func testKeyCodeMapIsNotAlphabetical() {
        // The classic bug: assuming a=0,b=1,c=2…  Real ANSI: a=0, s=1, d=2, b=11.
        XCTAssertEqual(KeyCodeMap.letters["a"], 0)
        XCTAssertEqual(KeyCodeMap.letters["s"], 1)
        XCTAssertEqual(KeyCodeMap.letters["d"], 2)
        XCTAssertEqual(KeyCodeMap.letters["b"], 11)
        XCTAssertEqual(KeyCodeMap.letters["c"], 8)
    }

    func testDigitsAreNonContiguous() {
        XCTAssertEqual(KeyCodeMap.digits["1"], 18)
        XCTAssertEqual(KeyCodeMap.digits["5"], 23)
        XCTAssertEqual(KeyCodeMap.digits["6"], 22)   // not 24
        XCTAssertEqual(KeyCodeMap.digits["0"], 29)
    }

    func testResolveUppercaseImpliesShift() {
        XCTAssertEqual(KeyCodeMap.resolve(.character("a"))?.code, 0)
        XCTAssertEqual(KeyCodeMap.resolve(.character("a"))?.needsShift, false)
        XCTAssertEqual(KeyCodeMap.resolve(.character("A"))?.code, 0)
        XCTAssertEqual(KeyCodeMap.resolve(.character("A"))?.needsShift, true)
    }

    func testResolvePunctuationAndSpecial() {
        XCTAssertEqual(KeyCodeMap.resolve(.character("`"))?.code, 50)
        XCTAssertEqual(KeyCodeMap.resolve(.special(.escape))?.code, 53)
        XCTAssertNil(KeyCodeMap.resolve(.character("✓")))   // off-layout → caller types it
    }

    func testScriptValidationRejectsDangerousPatterns() {
        let runner = ScriptRunner()
        XCTAssertFalse(runner.validateShellScript("rm -rf /").isValid)
        XCTAssertFalse(runner.validateShellScript(":(){ :|:& };:").isValid)
        XCTAssertFalse(runner.validateShellScript("chmod 777 /etc/passwd").isValid)
        XCTAssertFalse(runner.validateShellScript("   ").isValid)
        XCTAssertTrue(runner.validateShellScript("echo hello").isValid)
        XCTAssertTrue(runner.validateShellScript("ls -la ~/Documents").isValid)
    }

    func testShellRunsAndCapturesOutput() async {
        let runner = ScriptRunner(timeout: 5)
        let result = await runner.runShell(script: "echo action-ring")
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "action-ring")
    }

    func testMCPActionsReportNotImplemented() async {
        let exec = ActionExecutor()
        let mcp = RingAction.mcpToolCall(MCPToolAction(serverId: "x", toolName: "t", parameters: [:], displayName: "d"))
        let result = await exec.execute(mcp)
        XCTAssertEqual(result, .failure(.notImplemented))
    }

    func testActionDescriptions() {
        XCTAssertEqual(RingAction.keyboardShortcut(.character("c"), modifiers: [.command]).description, "⌘C")
        XCTAssertEqual(RingAction.systemAction(.mute).description, "Mute")
    }
}
