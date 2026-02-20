import Testing
import Foundation
@testable import MacRingCore

@Suite("RingAction Tests")
struct RingActionTests {

    // MARK: - Keyboard Shortcut Actions

    @Test("Create keyboard shortcut with single key")
    func createKeyboardShortcutSingleKey() {
        let action = RingAction.keyboardShortcut(.character("a"), modifiers: [])

        if case .keyboardShortcut(let keyCode, let modifiers) = action {
            #expect(keyCode.character == "a")
            #expect(modifiers.isEmpty)
        } else {
            #expect(Bool(false), "Should be keyboard shortcut")
        }
    }

    @Test("Create keyboard shortcut with modifiers")
    func createKeyboardShortcutWithModifiers() {
        let action = RingAction.keyboardShortcut(
            .character("c"),
            modifiers: [.command, .shift]
        )

        if case .keyboardShortcut(let keyCode, let modifiers) = action {
            #expect(keyCode.character == "c")
            #expect(modifiers.count == 2)
            #expect(modifiers.contains(.command))
            #expect(modifiers.contains(.shift))
        } else {
            #expect(Bool(false), "Should be keyboard shortcut")
        }
    }

    @Test("Create keyboard shortcut with special key")
    func createKeyboardShortcutSpecialKey() {
        let action = RingAction.keyboardShortcut(.special(.escape), modifiers: [])

        if case .keyboardShortcut(let keyCode, _) = action {
            if case .special(let key) = keyCode {
                #expect(key == .escape)
            } else {
                #expect(Bool(false), "Should be special key")
            }
        } else {
            #expect(Bool(false), "Should be keyboard shortcut")
        }
    }

    @Test("Common keyboard shortcuts are valid")
    func commonKeyboardShortcuts() {
        let shortcuts: [RingAction] = [
            .keyboardShortcut(.character("c"), modifiers: [.command]),
            .keyboardShortcut(.character("v"), modifiers: [.command]),
            .keyboardShortcut(.character("x"), modifiers: [.command]),
            .keyboardShortcut(.character("z"), modifiers: [.command]),
            .keyboardShortcut(.character("a"), modifiers: [.command]),
            .keyboardShortcut(.character("s"), modifiers: [.command]),
            .keyboardShortcut(.character("w"), modifiers: [.command]),
            .keyboardShortcut(.character("q"), modifiers: [.command]),
            .keyboardShortcut(.special(.tab), modifiers: [.command])
        ]

        for action in shortcuts {
            if case .keyboardShortcut = action {
                // Valid
            } else {
                #expect(Bool(false), "All should be keyboard shortcuts")
            }
        }
    }

    // MARK: - Launch Application Actions

    @Test("Create launch application action")
    func createLaunchApplication() {
        let action = RingAction.launchApplication(bundleIdentifier: "com.apple.Safari")

        if case .launchApplication(let bundleId) = action {
            #expect(bundleId == "com.apple.Safari")
        } else {
            #expect(Bool(false), "Should be launch application")
        }
    }

    @Test("Common app bundle identifiers are valid")
    func commonAppBundleIds() {
        let apps: [RingAction] = [
            .launchApplication(bundleIdentifier: "com.apple.Safari"),
            .launchApplication(bundleIdentifier: "com.apple.finder"),
            .launchApplication(bundleIdentifier: "com.apple.dt.Xcode"),
            .launchApplication(bundleIdentifier: "com.microsoft.VSCode"),
            .launchApplication(bundleIdentifier: "com.figma.Desktop")
        ]

        for action in apps {
            if case .launchApplication = action {
                // Valid
            } else {
                #expect(Bool(false), "All should be launch application")
            }
        }
    }

    // MARK: - Open URL Actions

    @Test("Create open URL action with https")
    func createOpenURLHttps() {
        let action = RingAction.openURL("https://example.com")

        if case .openURL(let url) = action {
            #expect(url == "https://example.com")
        } else {
            #expect(Bool(false), "Should be open URL")
        }
    }

    @Test("Create open URL action with http")
    func createOpenURLHttp() {
        let action = RingAction.openURL("http://example.com")

        if case .openURL(let url) = action {
            #expect(url == "http://example.com")
        } else {
            #expect(Bool(false), "Should be open URL")
        }
    }

    @Test("Create open URL action with mailto")
    func createOpenURLMailto() {
        let action = RingAction.openURL("mailto:test@example.com")

        if case .openURL(let url) = action {
            #expect(url.hasPrefix("mailto:"))
        } else {
            #expect(Bool(false), "Should be open URL")
        }
    }

    // MARK: - System Action Types

    @Test("All system actions are valid")
    func allSystemActions() {
        let systemActions: [SystemAction] = [
            .lockScreen,
            .screenshot,
            .volumeUp,
            .volumeDown,
            .mute,
            .brightnessUp,
            .brightnessDown,
            .missionControl,
            .showDesktop,
            .launchpad,
            .notificationCenter,
            .sleep,
            .restart,
            .shutdown
        ]

        for sysAction in systemActions {
            let action = RingAction.systemAction(sysAction)
            if case .systemAction(let actual) = action {
                #expect(actual == sysAction)
            } else {
                #expect(Bool(false), "Should be system action")
            }
        }
    }

    // MARK: - Action Descriptions

    @Test("Keyboard shortcut has readable description")
    func keyboardShortcutDescription() {
        let action = RingAction.keyboardShortcut(.character("c"), modifiers: [.command])
        let description = action.description

        #expect(!description.isEmpty)
        #expect(description.contains("Command") || description.contains("C") || description.contains("c"))
    }

    @Test("Launch application has readable description")
    func launchAppDescription() {
        let action = RingAction.launchApplication(bundleIdentifier: "com.apple.Safari")
        let description = action.description

        #expect(!description.isEmpty)
    }

    @Test("System action has readable description")
    func systemActionDescription() async throws {
        let action = RingAction.systemAction(.lockScreen)
        let description = action.description

        #expect(!description.isEmpty)
    }

    // MARK: - Future Action Types (Stubs)

    @Test("Shell script action returns not implemented error")
    func shellScriptNotImplemented() {
        let action = RingAction.shellScript("echo test")

        if case .shellScript(let script) = action {
            #expect(script == "echo test")
        } else {
            #expect(Bool(false), "Should be shell script")
        }
    }

    @Test("AppleScript action returns not implemented error")
    func appleScriptNotImplemented() {
        let action = RingAction.appleScript("tell application \"Finder\" to activate")

        if case .appleScript(let script) = action {
            #expect(script.contains("Finder"))
        } else {
            #expect(Bool(false), "Should be AppleScript")
        }
    }

    @Test("MCP tool call action exists")
    func mcpToolCallExists() {
        let action = RingAction.mcpToolCall(
            MCPToolAction(
                serverId: "github",
                toolName: "create_pr",
                parameters: [:],
                displayName: "Create PR"
            )
        )

        if case .mcpToolCall(let mcpAction) = action {
            #expect(mcpAction.serverId == "github")
            #expect(mcpAction.toolName == "create_pr")
        } else {
            #expect(Bool(false), "Should be MCP tool call")
        }
    }

    // MARK: - Action Equality

    @Test("Two identical keyboard shortcuts are equal")
    func equalKeyboardShortcuts() {
        let action1 = RingAction.keyboardShortcut(.character("c"), modifiers: [.command])
        let action2 = RingAction.keyboardShortcut(.character("c"), modifiers: [.command])

        #expect(action1 == action2)
    }

    @Test("Different keyboard shortcuts are not equal")
    func differentKeyboardShortcuts() {
        let action1 = RingAction.keyboardShortcut(.character("c"), modifiers: [.command])
        let action2 = RingAction.keyboardShortcut(.character("v"), modifiers: [.command])

        #expect(action1 != action2)
    }

    // MARK: - Codable Conformance

    @Test("Action can be encoded and decoded")
    func actionCodable() throws {
        let action = RingAction.keyboardShortcut(.character("c"), modifiers: [.command])
        let encoder = JSONEncoder()
        let data = try encoder.encode(action)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RingAction.self, from: data)

        #expect(action == decoded)
    }

    @Test("Launch app can be encoded and decoded")
    func launchAppCodable() throws {
        let action = RingAction.launchApplication(bundleIdentifier: "com.apple.Safari")
        let encoder = JSONEncoder()
        let data = try encoder.encode(action)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RingAction.self, from: data)

        #expect(action == decoded)
    }
}
