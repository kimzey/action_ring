import Foundation

// MARK: - Key Code

/// A key that can be pressed: either a literal character or a named special key.
public enum KeyCode: Equatable, Sendable {
    case character(Character)
    case special(SpecialKey)

    public var character: Character? {
        if case .character(let c) = self { return c }
        return nil
    }

    public var specialKey: SpecialKey? {
        if case .special(let k) = self { return k }
        return nil
    }
}

extension KeyCode: Codable {
    private enum CodingKeys: String, CodingKey { case type, character, special }
    private enum DecodeError: Error { case invalidCharacter, invalidType(String) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "character":
            let s = try c.decode(String.self, forKey: .character)
            guard let ch = s.first else { throw DecodeError.invalidCharacter }
            self = .character(ch)
        case "special":
            self = .special(try c.decode(SpecialKey.self, forKey: .special))
        case let other:
            throw DecodeError.invalidType(other)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .character(let ch):
            try c.encode("character", forKey: .type)
            try c.encode(String(ch), forKey: .character)
        case .special(let k):
            try c.encode("special", forKey: .type)
            try c.encode(k, forKey: .special)
        }
    }
}

// MARK: - Special Key

/// Keys without a direct character representation.
public enum SpecialKey: String, Codable, Equatable, Sendable, CaseIterable {
    case enter, tab, space, escape, delete, backspace
    case home, end, pageUp, pageDown
    case leftArrow, rightArrow, upArrow, downArrow
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
}

// MARK: - Key Modifier

public enum KeyModifier: String, Codable, Equatable, Sendable, CaseIterable {
    case command, shift, option, control, capsLock, function
}

// MARK: - System Action

/// Built-in system actions executed by `ActionExecutor`.
public enum SystemAction: String, Codable, Equatable, Sendable, CaseIterable {
    case lockScreen, screenshot, screenshotArea
    case volumeUp, volumeDown, mute
    case brightnessUp, brightnessDown
    case missionControl, showDesktop, launchpad, notificationCenter
    case mediaPlayPause, mediaNext, mediaPrevious
    case sleep
}

// MARK: - MCP (reserved for a future release; not executed in v1)

public struct MCPToolAction: Codable, Equatable, Sendable {
    public var serverId: String
    public var toolName: String
    public var parameters: [String: String]
    public var displayName: String
    public init(serverId: String, toolName: String, parameters: [String: String], displayName: String) {
        self.serverId = serverId; self.toolName = toolName
        self.parameters = parameters; self.displayName = displayName
    }
}

public struct MCPWorkflowAction: Codable, Equatable, Sendable {
    public var serverId: String
    public var workflowId: String
    public var parameters: [String: String]
    public var displayName: String
    public init(serverId: String, workflowId: String, parameters: [String: String], displayName: String) {
        self.serverId = serverId; self.workflowId = workflowId
        self.parameters = parameters; self.displayName = displayName
    }
}

// MARK: - Ring Action

/// An action assignable to a ring slot.
public enum RingAction: Codable, Equatable, Sendable {
    case keyboardShortcut(KeyCode, modifiers: [KeyModifier])
    case launchApplication(bundleIdentifier: String)
    case openURL(String)
    case systemAction(SystemAction)
    case shellScript(String)
    case appleScript(String)
    case shortcutsApp(String)
    case textSnippet(String)
    case openFile(String)
    case workflow([RingAction])
    // Reserved — return `.notImplemented` from the executor in v1.
    case mcpToolCall(MCPToolAction)
    case mcpWorkflow(MCPWorkflowAction)
}

// MARK: - Description

extension RingAction: CustomStringConvertible {
    public var description: String {
        switch self {
        case .keyboardShortcut(let key, let mods):
            let m = mods.map(\.symbol).joined()
            let k: String
            switch key {
            case .character(let ch): k = String(ch).uppercased()
            case .special(let sp): k = sp.label
            }
            return m.isEmpty ? k : "\(m)\(k)"
        case .launchApplication(let bundleId):
            let name = bundleId.split(separator: ".").last.map(String.init)?.capitalized ?? bundleId
            return "Open \(name)"
        case .openURL(let url): return "Open \(url)"
        case .systemAction(let a): return a.label
        case .shellScript: return "Run Shell Script"
        case .appleScript: return "Run AppleScript"
        case .shortcutsApp(let n): return "Shortcut: \(n)"
        case .textSnippet(let t):
            let p = String(t.prefix(20))
            return "Insert: \(p)\(t.count > 20 ? "…" : "")"
        case .openFile(let path):
            return "Open \(URL(fileURLWithPath: path).lastPathComponent)"
        case .workflow(let actions): return "Workflow (\(actions.count) steps)"
        case .mcpToolCall(let m): return "MCP: \(m.displayName)"
        case .mcpWorkflow(let m): return "MCP Flow: \(m.displayName)"
        }
    }
}

// MARK: - Display helpers

extension KeyModifier {
    /// Mac-style modifier glyph.
    public var symbol: String {
        switch self {
        case .command: return "⌘"
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        case .capsLock: return "⇪"
        case .function: return "fn"
        }
    }
}

extension SpecialKey {
    public var label: String {
        switch self {
        case .enter: return "↩"
        case .tab: return "⇥"
        case .space: return "Space"
        case .escape: return "⎋"
        case .delete: return "⌦"
        case .backspace: return "⌫"
        case .home: return "↖"
        case .end: return "↘"
        case .pageUp: return "⇞"
        case .pageDown: return "⇟"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        }
    }
}

extension SystemAction {
    public var label: String {
        switch self {
        case .lockScreen: return "Lock Screen"
        case .screenshot: return "Screenshot"
        case .screenshotArea: return "Screenshot Area"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .mute: return "Mute"
        case .brightnessUp: return "Brightness Up"
        case .brightnessDown: return "Brightness Down"
        case .missionControl: return "Mission Control"
        case .showDesktop: return "Show Desktop"
        case .launchpad: return "Launchpad"
        case .notificationCenter: return "Notifications"
        case .mediaPlayPause: return "Play/Pause"
        case .mediaNext: return "Next Track"
        case .mediaPrevious: return "Previous Track"
        case .sleep: return "Sleep"
        }
    }
}
