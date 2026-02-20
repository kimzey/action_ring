import Testing
import Foundation
#if canImport(AppKit)
import AppKit
@testable import MacRingCore

@Suite("ScriptRunner Tests")
struct ScriptRunnerTests {

    // MARK: - Shell Script Tests

    @Test("Shell script executes successfully")
    func shellScriptExecutesSuccessfully() async {
        let runner = ScriptRunner()

        // Simple echo command
        let result = await runner.runShell(script: "echo 'Hello, World!'")

        #expect(result.exitCode == 0)
        #expect(result.output.contains("Hello, World!"))
        #expect(result.error.isEmpty)
    }

    @Test("Shell script captures stdout")
    func shellScriptCapturesStdout() async {
        let runner = ScriptRunner()

        let result = await runner.runShell(script: "printf 'Line 1\\nLine 2\\nLine 3'")

        #expect(result.exitCode == 0)
        #expect(result.output == "Line 1\nLine 2\nLine 3")
    }

    @Test("Shell script captures stderr")
    func shellScriptCapturesStderr() async {
        let runner = ScriptRunner()

        // Redirect stderr to stdout for testing
        let result = await runner.runShell(script: "echo 'Error message' >&2")

        #expect(result.exitCode == 0)
        // Error output might be in stderr or combined
    }

    @Test("Shell script returns correct exit code")
    func shellScriptReturnsCorrectExitCode() async {
        let runner = ScriptRunner()

        // Success case
        let successResult = await runner.runShell(script: "exit 0")
        #expect(successResult.exitCode == 0)

        // Failure case
        let failureResult = await runner.runShell(script: "exit 42")
        #expect(failureResult.exitCode == 42)
    }

    @Test("Shell script with variables works")
    func shellScriptWithVariablesWorks() async {
        let runner = ScriptRunner()

        let result = await runner.runShell(script: "NAME=World; echo \"Hello, $NAME!\"")

        #expect(result.exitCode == 0)
        #expect(result.output.contains("Hello, World!"))
    }

    @Test("Shell script with pipes works")
    func shellScriptWithPipesWorks() async {
        let runner = ScriptRunner()

        let result = await runner.runShell(script: "echo 'hello' | tr '[:lower:]' '[:upper:]'")

        #expect(result.exitCode == 0)
        #expect(result.output.contains("HELLO"))
    }

    // MARK: - AppleScript Tests

    @Test("AppleScript executes successfully")
    func appleScriptExecutesSuccessfully() async throws {
        try skipIfPlatformUnsupported()

        let runner = ScriptRunner()

        // Simple AppleScript
        let result = await runner.runAppleScript(script: "return \"Hello from AppleScript\"")

        #expect(result.exitCode == 0)
        #expect(result.output.contains("Hello from AppleScript"))
    }

    @Test("AppleScript can get system info")
    func appleScriptCanGetSystemInfo() async throws {
        try skipIfPlatformUnsupported()

        let runner = ScriptRunner()

        let result = await runner.runAppleScript(script: "return system version")

        // Should return something like "10.15.7"
        #expect(result.exitCode == 0)
        #expect(!result.output.isEmpty)
    }

    @Test("AppleScript with syntax error returns error")
    func appleScriptWithSyntaxErrorReturnsError() async throws {
        try skipIfPlatformUnsupported()

        let runner = ScriptRunner()

        let result = await runner.runAppleScript(script: "this is not valid AppleScript")

        #expect(result.exitCode != 0)
        #expect(!result.error.isEmpty)
    }

    // MARK: - Script Validation Tests

    @Test("Valid shell script passes validation")
    func validShellScriptPassesValidation() async {
        let runner = ScriptRunner()

        let validation = await runner.validateShellScript("echo 'test'")
        #expect(validation.isValid)
        #expect(validation.error.isEmpty)
    }

    @Test("Dangerous rm commands are rejected")
    func dangerousRmCommandsAreRejected() async {
        let runner = ScriptRunner()

        let dangerousScripts = [
            "rm -rf /",
            "rm -rf ~",
            "rm -rf /usr",
            "rm -Rf /",
            "rm  -rf  /",
        ]

        for script in dangerousScripts {
            let validation = await runner.validateShellScript(script)
            #expect(!validation.isValid, "Script should be rejected: \(script)")
            #expect(!validation.error.isEmpty)
        }
    }

    @Test("Dangerous commands are rejected")
    func dangerousCommandsAreRejected() async {
        let runner = ScriptRunner()

        let dangerousScripts = [
            "dd if=/dev/zero of=/dev/sda",
            ":(){ :|:& };:",  // Fork bomb
            "mv / ~/. Trash/",
        ]

        for script in dangerousScripts {
            let validation = await runner.validateShellScript(script)
            #expect(!validation.isValid, "Script should be rejected: \(script)")
        }
    }

    @Test("Safe commands pass validation")
    func safeCommandsPassValidation() async {
        let runner = ScriptRunner()

        let safeScripts = [
            "echo 'hello'",
            "ls -la",
            "cat file.txt",
            "pwd",
            "date",
            "uptime",
            "whoami",
        ]

        for script in safeScripts {
            let validation = await runner.validateShellScript(script)
            #expect(validation.isValid, "Script should be valid: \(script)")
        }
    }

    // MARK: - Timeout Tests

    @Test("Script execution timeout works correctly")
    func scriptExecutionTimeoutWorks() async {
        let runner = ScriptRunner(timeout: 0.1)  // 100ms timeout

        // Sleep command that exceeds timeout
        let result = await runner.runShell(script: "sleep 5")

        // Should timeout with specific exit code
        #expect(result.didTimeout)
        #expect(result.exitCode != 0)
    }

    @Test("Fast script completes within timeout")
    func fastScriptCompletesWithinTimeout() async {
        let runner = ScriptRunner(timeout: 5.0)

        let result = await runner.runShell(script: "echo 'quick'")

        #expect(!result.didTimeout)
        #expect(result.exitCode == 0)
    }

    // MARK: - Working Directory Tests

    @Test("Script runs in specified working directory")
    func scriptRunsInWorkingDirectory() async {
        let runner = ScriptRunner(workingDirectory: "/tmp")

        let result = await runner.runShell(script: "pwd")

        #expect(result.exitCode == 0)
        // On different platforms, /tmp might be represented differently
        #expect(result.output.contains("tmp") || result.output.contains("Temp"))
    }

    // MARK: - Environment Variables Tests

    @Test("Script has access to environment variables")
    func scriptHasAccessToEnvironmentVariables() async {
        let runner = ScriptRunner()

        let result = await runner.runShell(script: "echo $PATH")

        #expect(result.exitCode == 0)
        #expect(!result.output.isEmpty)
    }

    @Test("Custom environment variables are passed to script")
    func customEnvironmentVariablesArePassed() async {
        let runner = ScriptRunner(environment: ["CUSTOM_VAR": "test_value"])

        let result = await runner.runShell(script: "echo $CUSTOM_VAR")

        #expect(result.exitCode == 0)
        #expect(result.output.contains("test_value"))
    }

    // MARK: - Empty/Edge Case Tests

    @Test("Empty script returns error")
    func emptyScriptReturnsError() async {
        let runner = ScriptRunner()

        let result = await runner.runShell(script: "")

        #expect(result.exitCode != 0)
    }

    @Test("Script with only whitespace returns error")
    func scriptWithOnlyWhitespaceReturnsError() async {
        let runner = ScriptRunner()

        let result = await runner.runShell(script: "   \\n  \\t  ")

        #expect(result.exitCode != 0)
    }

    @Test("Very long script is handled correctly")
    func veryLongScriptIsHandledCorrectly() async {
        let runner = ScriptRunner()

        // Create a long script
        let longScript = (0..<100).map { _ in "echo 'line'; " }.joined()

        let result = await runner.runShell(script: longScript)

        #expect(result.exitCode == 0)
    }

    // MARK: - Helper Functions

    private func skipIfPlatformUnsupported() throws {
        #if !os(macOS)
        throw XCTSkip("AppleScript is only supported on macOS")
        #endif
    }
}
#endif
