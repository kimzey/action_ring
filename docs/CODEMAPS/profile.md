# Profile Layer Codemap

**Last Updated:** 2025-02-21

## Overview

The Profile layer defines the data models for ring configurations. It includes the core profile structure, individual slot definitions, action types, and built-in presets for common applications.

## Public Types

### RingProfile
```swift
public struct RingProfile: Codable, Identifiable, Equatable, Sendable
    var id: UUID
    var name: String
    var bundleId: String?              // App-specific (nil = default/category)
    var category: AppCategory           // For fallback matching
    var slots: [RingSlot]
    var slotCount: Int                 // 4, 6, or 8
    var isDefault: Bool
    var mcpServers: [String]            // Associated MCP server IDs
    var createdAt: Date
    var updatedAt: Date
    var source: ProfileSource

    // Factory
    static func createDefault() -> RingProfile

    // Validation
    var isValid: Bool

    // Timestamp
    mutating func touch()

    // Slot Management
    mutating func addSlot(_ slot: RingSlot)
    mutating func removeSlot(at position: Int)
    mutating func updateSlot(at position: Int, with slot: RingSlot)
    func slotAt(position: Int) -> RingSlot?

    // ProfileProvider conformance
    func profile(forBundleId: String) async -> RingProfile?
    func profile(forCategory: AppCategory) async -> RingProfile?
    func default() async -> RingProfile?
```

### RingSlot
```swift
public struct RingSlot: Codable, Equatable, Sendable
    var position: Int                   // 0-7 (for 8-slot ring)
    var label: String                   // Display label
    var icon: String                    // SF Symbol name
    var action: RingAction?             // Optional action
    var isEnabled: Bool
    var color: SlotColor

    var isValid: Bool
    var isDisabled: Bool
    var hasAction: Bool
```

### RingAction
```swift
public enum RingAction: Codable, Equatable, Sendable
    case keyboardShortcut(KeyCode, modifiers: [KeyModifier])
    case launchApplication(bundleIdentifier: String)
    case openURL(String)
    case systemAction(SystemAction)
    case shellScript(String)
    case appleScript(String)
    case shortcutsApp(String)
    case textSnippet(String)
    case openFile(String)
    case workflow([RingAction])         // Nested actions
    case mcpToolCall(MCPToolAction)     // Future
    case mcpWorkflow(MCPWorkflowAction) // Future
```

### Supporting Types

#### KeyCode
```swift
public enum KeyCode: Equatable, Sendable
    case character(Character)
    case special(SpecialKey)

    var character: Character?
    var specialKey: SpecialKey?
```

#### SpecialKey
```swift
public enum SpecialKey: String, Codable, Equatable, Sendable
    case enter, tab, space, escape, delete, backspace
    case home, end, pageUp, pageDown
    case leftArrow, rightArrow, upArrow, downArrow
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
```

#### KeyModifier
```swift
public enum KeyModifier: String, Codable, Equatable, Sendable
    case command, shift, option, control, capsLock, function
```

#### SystemAction
```swift
public enum SystemAction: String, Codable, Equatable, Sendable
    case lockScreen, screenshot
    case volumeUp, volumeDown, mute
    case brightnessUp, brightnessDown
    case missionControl, showDesktop, launchpad
    case notificationCenter, sleep, restart, shutdown
```

#### SlotColor
```swift
public enum SlotColor: String, Codable, Equatable, Sendable
    case blue, purple, pink, red, orange, yellow, green, gray
```

#### ProfileSource
```swift
public enum ProfileSource: String, Codable, Equatable, Sendable
    case builtin      // Built-in preset
    case user         // User-created
    case ai           // AI-generated
    case community    // Community-shared
    case mcp          // MCP-provided
```

#### AppCategory
```swift
public enum AppCategory: String, Codable, Equatable, Sendable
    case ide, browser, design, productivity
    case communication, media, development, terminal, other
```

#### MCPToolAction
```swift
public struct MCPToolAction: Codable, Equatable, Sendable
    var serverId: String
    var toolName: String
    var parameters: [String: String]
    var displayName: String
```

#### MCPWorkflowAction
```swift
public struct MCPWorkflowAction: Codable, Equatable, Sendable
    var serverId: String
    var workflowId: String
    var parameters: [String: String]
    var displayName: String
```

## Dependencies

### Internal Dependencies
```
RingProfile
  -> RingSlot
  -> RingAction (indirect, via RingSlot)

RingSlot
  -> RingAction (optional)
  -> SlotColor

RingAction
  -> KeyCode
  -> KeyModifier
  -> SystemAction
  -> MCPToolAction
  -> MCPWorkflowAction

KeyCode
  -> SpecialKey

BuiltInProfiles
  -> RingProfile
  -> RingSlot
  -> RingAction (all variants)
```

### External Dependencies
- **Foundation:** Core types (UUID, Date, Codable)

## Built-in Profiles

### Profile Summary

| Profile | Bundle ID | Category | Slots |
|---------|-----------|----------|-------|
| VS Code | com.microsoft.VSCode | .ide | 8 |
| Xcode | com.apple.dt.Xcode | .ide | 8 |
| Safari | com.apple.Safari | .browser | 8 |
| Finder | com.apple.finder | .other | 8 |
| Terminal | com.apple.Terminal | .terminal | 8 |
| Notes | com.apple.Notes | .productivity | 8 |
| Messages | com.apple.MobileSMS | .communication | 8 |
| Spotify | com.spotify.client | .media | 8 |
| Slack | com.tinyspeck.slackmacgap | .communication | 8 |
| System | (none) | .other | 8 (default) |

### VS Code Profile Slots

| Position | Label | Icon | Action |
|----------|-------|------|--------|
| 0 | Command Palette | text.magnifyingglass | Cmd+Shift+P |
| 1 | Find in Files | magnifyingglass | Cmd+Shift+F |
| 2 | New File | doc.badge.plus | Cmd+N |
| 3 | Close Editor | xmark.circle | Cmd+W |
| 4 | Toggle Terminal | chevron.left.forwardslash.chevron.right | Cmd+` |
| 5 | Format | text.alignleft | Cmd+Shift+S |
| 6 | Go to Line | number | Cmd+G |
| 7 | Quick Open | folder | Cmd+P |

### Xcode Profile Slots

| Position | Label | Icon | Action |
|----------|-------|------|--------|
| 0 | Build | hammer | Cmd+B |
| 1 | Run | play.fill | Cmd+R |
| 2 | Stop | stop.fill | Cmd+. |
| 3 | Clean | sparkles | Cmd+Shift+K |
| 4 | Test | checkmark.circle.fill | Cmd+U |
| 5 | Find | magnifyingglass | Cmd+F |
| 6 | Open Quickly | folder.badge.gearshape | Cmd+Shift+O |
| 7 | Assistant | info.circle | Cmd+Shift+Option+A |

### Default Profile Slots

| Position | Label | Icon | Action |
|----------|-------|------|--------|
| 0 | Copy | doc.on.doc | Cmd+C |
| 1 | Paste | doc.on.clipboard | Cmd+V |
| 2 | Cut | scissors | Cmd+X |
| 3 | Undo | arrow.uturn.backward | Cmd+Z |
| 4 | Redo | arrow.uturn.forward | Cmd+Shift+Z |
| 5 | Save | square.and.arrow.down | Cmd+S |
| 6 | Select All | square.and.pencil | Cmd+A |
| 7 | Close | xmark | Cmd+W |

## Constants

### Slot Counts
```swift
public static let validSlotCounts = [4, 6, 8]
```

### Position Limits
```swift
public static let maxPosition = 7  // For 8-slot ring
```

## Profile Provider Protocol

The `ProfileProvider` protocol defines the interface for profile lookup:

```swift
public protocol ProfileProvider: Sendable {
    func profile(forBundleId bundleId: String) async -> RingProfile?
    func profile(forCategory category: AppCategory) async -> RingProfile?
    func default() async -> RingProfile?
}
```

`RingProfile` conforms to this protocol, enabling direct profile-to-profile matching for the default profile.

## Serialization

All profile types are `Codable` for JSON serialization:

```swift
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let data = try encoder.encode(profile)
let jsonString = String(data: data, encoding: .utf8)
```

## Slot Position Mapping

For an 8-slot ring, positions map to angles starting from the right (0 radians):

```
        2 (Up)
    3       1
4       0       8
    5       7
        6 (Down)
```

Actual calculation: `slotAngle = index * (2*pi / slotCount)`

## Related Areas

- [context.md](context.md) - Profile lookup chain and switching
- [execution.md](execution.md) - Action execution from RingAction
- [ui.md](ui.md) - Visual representation of profiles
