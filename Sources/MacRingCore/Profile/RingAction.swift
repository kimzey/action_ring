import Foundation

// MARK: - Key Code

/// Represents a key that can be pressed
public enum KeyCode: Equatable, Sendable {
    case character(Character)
    case special(SpecialKey)

    /// The character value if this is a character key
    public var character: Character? {
        if case .character(let char) = self {
            return char
        }
        return nil
    }

    /// The special key if this is a special key
    public var specialKey: SpecialKey? {
        if case .special(let key) = self {
            return key
        }
        return nil
    }
}

// MARK: - KeyCode Codable

extension KeyCode: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case character
        case special
    }

    private enum KeyCodeError: Error {
        case invalidCharacter
        case invalidType(String)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "character":
            let charString = try container.decode(String.self, forKey: .character)
            guard let char = charString.first else {
                throw KeyCodeError.invalidCharacter
            }
            self = .character(char)
        case "special":
            let special = try container.decode(SpecialKey.self, forKey: .special)
            self = .special(special)
        default:
            throw KeyCodeError.invalidType(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .character(let char):
            try container.encode("character", forKey: .type)
            try container.encode(String(char), forKey: .character)
        case .special(let key):
            try container.encode("special", forKey: .type)
            try container.encode(key, forKey: .special)
        }
    }
}

// MARK: - Special Key

/// Special keys that don't have a direct character representation
public enum SpecialKey: String, Codable, Equatable, Sendable, CaseIterable {
    case enter
    case tab
    case space
    case escape
    case delete
    case backspace
    case home
    case end
    case pageUp
    case pageDown
    case leftArrow
    case rightArrow
    case upArrow
    case downArrow
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9
    case f10
    case f11
    case f12
}

// MARK: - Key Modifier

/// Modifier keys for keyboard shortcuts
public enum KeyModifier: String, Codable, Equatable, Sendable, CaseIterable {
    case command
    case shift
    case option
    case control
    case capsLock
    case function
}

// MARK: - System Action

/// Built-in system actions
public enum SystemAction: String, Codable, Equatable, Sendable, CaseIterable {
    case lockScreen
    case screenshot
    case volumeUp
    case volumeDown
    case mute
    case brightnessUp
    case brightnessDown
    case missionControl
    case showDesktop
    case launchpad
    case notificationCenter
    case sleep
    case restart
    case shutdown
}

// MARK: - MCP Tool Action

/// Model Context Protocol tool call action
public struct MCPToolAction: Codable, Equatable, Sendable {
    public var serverId: String
    public var toolName: String
    public var parameters: [String: String]
    public var displayName: String

    public init(serverId: String, toolName: String, parameters: [String: String], displayName: String) {
        self.serverId = serverId
        self.toolName = toolName
        self.parameters = parameters
        self.displayName = displayName
    }
}

// MARK: - MCP Workflow Action

/// Model Context Protocol workflow action
public struct MCPWorkflowAction: Codable, Equatable, Sendable {
    public var serverId: String
    public var workflowId: String
    public var parameters: [String: String]
    public var displayName: String

    public init(serverId: String, workflowId: String, parameters: [String: String], displayName: String) {
        self.serverId = serverId
        self.workflowId = workflowId
        self.parameters = parameters
        self.displayName = displayName
    }
}

// MARK: - Ring Action

/// An action that can be assigned to a ring slot
public enum RingAction: Codable, Equatable, Sendable {
    /// Keyboard shortcut (e.g., Command+C)
    case keyboardShortcut(KeyCode, modifiers: [KeyModifier])

    /// Launch application by bundle identifier
    case launchApplication(bundleIdentifier: String)

    /// Open a URL
    case openURL(String)

    /// System action (lock screen, screenshot, etc.)
    case systemAction(SystemAction)

    /// Execute shell script
    case shellScript(String)

    /// Execute AppleScript
    case appleScript(String)

    /// Run Shortcuts.app shortcut
    case shortcutsApp(String)

    /// Insert text snippet
    case textSnippet(String)

    /// Open file or folder
    case openFile(String)

    /// Multi-step workflow/macro
    case workflow([RingAction])

    /// MCP tool call
    case mcpToolCall(MCPToolAction)

    /// MCP workflow
    case mcpWorkflow(MCPWorkflowAction)
}

// MARK: - Ring Action Description

extension RingAction: CustomStringConvertible {
    public var description: String {
        switch self {
        case .keyboardShortcut(let keyCode, let modifiers):
            let modifierString = modifiers.map { $0.rawValue.capitalized }.joined(separator: "+")
            let keyString: String
            if case .character(let char) = keyCode {
                keyString = String(char).uppercased()
            } else if case .special(let key) = keyCode {
                keyString = key.rawValue.capitalized
            } else {
                keyString = "Key"
            }
            return modifierString.isEmpty ? keyString : "\(modifierString)+\(keyString)"

        case .launchApplication(let bundleId):
            // Extract app name from bundle ID
            let appName = bundleId.split(separator: ".").last?.capitalized ?? bundleId
            return "Open \(appName)"

        case .openURL(let url):
            return "Open \(url)"

        case .systemAction(let action):
            switch action {
            case .lockScreen: return "Lock Screen"
            case .screenshot: return "Screenshot"
            case .volumeUp: return "Volume Up"
            case .volumeDown: return "Volume Down"
            case .mute: return "Mute"
            case .brightnessUp: return "Brightness Up"
            case .brightnessDown: return "Brightness Down"
            case .missionControl: return "Mission Control"
            case .showDesktop: return "Show Desktop"
            case .launchpad: return "Launchpad"
            case .notificationCenter: return "Notification Center"
            case .sleep: return "Sleep"
            case .restart: return "Restart"
            case .shutdown: return "Shutdown"
            }

        case .shellScript:
            return "Run Shell Script"

        case .appleScript:
            return "Run AppleScript"

        case .shortcutsApp(let name):
            return "Run Shortcuts: \(name)"

        case .textSnippet(let text):
            let preview = String(text.prefix(20))
            return "Insert: \(preview)\(text.count > 20 ? "..." : "")"

        case .openFile(let path):
            return "Open \(URL(fileURLWithPath: path).lastPathComponent)"

        case .workflow(let actions):
            return "Workflow (\(actions.count) actions)"

        case .mcpToolCall(let mcp):
            return "MCP: \(mcp.displayName)"

        case .mcpWorkflow(let mcp):
            return "MCP Workflow: \(mcp.displayName)"
        }
    }
}
