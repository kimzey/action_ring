<!-- Updated: 2025-02-20 -->
# MacRing -- Profile System Codemap

> Status: **Implemented** -- Core profile models complete with tests

---

## Overview

The Profile system defines the data models for the radial action ring: `RingProfile`, `RingSlot`, and `RingAction`. These are value types (Swift structs) with full `Codable`, `Equatable`, and `Sendable` conformance.

---

## File Structure

```
Sources/MacRingCore/Profile/
  RingAction.swift      -- 13 action types enum + supporting types
  RingSlot.swift        -- Single slot in the ring (position, label, icon, action)
  RingProfile.swift     -- Complete profile with slots, metadata, lifecycle

Tests/MacRingCoreTests/Profile/
  RingActionTests.swift    -- 28 tests
  RingSlotTests.swift      -- 23 tests
  RingProfileTests.swift   -- 29 tests
```

---

## Type Hierarchy

```
RingProfile (container)
    |
    +-- RingSlot[] (0-8 slots)
          |
          +-- RingAction? (optional action per slot)
```

---

## Core Types

### RingAction (13 cases)

Located in `G:\code\action_ring\Sources\MacRingCore\Profile\RingAction.swift`

```swift
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
    case workflow([RingAction])      // Multi-step macro
    case mcpToolCall(MCPToolAction)
    case mcpWorkflow(MCPWorkflowAction)
}
```

**Supporting Types:**

| Type | Purpose |
|------|---------|
| `KeyCode` | Character or SpecialKey enum |
| `SpecialKey` | enter, tab, space, escape, delete, arrows, F1-F12 |
| `KeyModifier` | command, shift, option, control, capsLock, function |
| `SystemAction` | lockScreen, screenshot, volumeUp/Down, brightness, etc. |
| `MCPToolAction` | serverId, toolName, parameters, displayName |
| `MCPWorkflowAction` | serverId, workflowId, parameters, displayName |

**Key Methods:**
- `description: String` - Human-readable display string

---

### RingSlot

Located in `G:\code\action_ring\Sources\MacRingCore\Profile\RingSlot.swift`

```swift
public struct RingSlot: Codable, Equatable, Sendable {
    public var position: Int        // 0-7 for 8-slot ring
    public var label: String
    public var icon: String         // SF Symbol name
    public var action: RingAction?
    public var isEnabled: Bool
    public var color: SlotColor     // blue, purple, pink, red, orange, yellow, green, gray
}
```

**Constants:**
- `maxPosition = 7` (8 slots max)

**Validation:**
- `isValid: Bool` - Position 0-7
- `isDisabled: Bool` - Convenience for !isEnabled
- `hasAction: Bool` - Action is non-nil

**Colors:**
```swift
public enum SlotColor: String, Codable, Equatable, Sendable, CaseIterable {
    case blue, purple, pink, red, orange, yellow, green, gray
}
```

---

### RingProfile

Located in `G:\code\action_ring\Sources\MacRingCore\Profile\RingProfile.swift`

```swift
public struct RingProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var bundleId: String?         // nil = category/default
    public var category: AppCategory
    public var slots: [RingSlot]
    public var slotCount: Int            // 4, 6, or 8
    public var isDefault: Bool
    public var mcpServers: [String]      // Associated MCP server IDs
    public var createdAt: Date
    public var updatedAt: Date
    public var source: ProfileSource
}
```

**Enums:**

```swift
public enum ProfileSource: String, Codable, Equatable, Sendable, CaseIterable {
    case builtin, user, ai, community, mcp
}

public enum AppCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case ide, browser, design, productivity, communication,
         media, development, terminal, other
}
```

**Constants:**
- `validSlotCounts = [4, 6, 8]`

**Factory Methods:**
- `createDefault() -> RingProfile` - Creates default 8-slot profile with common shortcuts (Copy, Paste, Cut, Undo, Redo, Save, Select All, Close)

**Validation:**
- `isValid: Bool` - slotCount in [4,6,8] and slots.count <= slotCount

**Timestamp Management:**
- `touch()` - Updates updatedAt to now

**Slot Management:**
- `addSlot(_:)` - Add/replace slot at position
- `removeSlot(at:)` - Remove slot at position
- `updateSlot(at:with:)` - Update existing slot
- `slotAt(position:) -> RingSlot?` - Query slot by position

---

## Test Coverage

| File | Tests | Coverage |
|------|-------|----------|
| `RingActionTests.swift` | 28 | All action types, Codable, equality, descriptions |
| `RingSlotTests.swift` | 23 | Creation, validation, actions, state |
| `RingProfileTests.swift` | 29 | CRUD, validation, slot management, MCP |

**Total:** 80 tests for Profile system

---

## Codable Implementation Details

### KeyCode (nested enum)
Uses custom CodingKeys with type discriminator:
- `type: "character"` or `"special"`
- `character` or `special` payload based on type

### RingAction (flat enum)
Swift auto-synthesizes Codable for enum with associated values.

### All structs
Auto-synthesized Codable works for all structs with primitive/enum stored properties.

---

## Dependencies

```
RingAction.swift
  - Foundation

RingSlot.swift
  - Foundation
  - RingAction (implicitly via same module)

RingProfile.swift
  - Foundation
  - RingSlot (implicitly via same module)
```

---

## Usage Examples

### Creating a profile
```swift
let profile = RingProfile(
    name: "Xcode",
    bundleId: "com.apple.dt.Xcode",
    category: .ide,
    slotCount: 8,
    source: .builtin
)

// Add slots
profile.addSlot(RingSlot(
    position: 0,
    label: "Build",
    icon: "hammer",
    action: .keyboardShortcut(.character("b"), modifiers: [.command])
))
```

### Querying
```swift
if let slot = profile.slotAt(position: 0) {
    print(slot.label)        // "Build"
    print(slot.hasAction)    // true
}
```

### Default profile
```swift
let default = RingProfile.createDefault()
// Pre-filled with Copy, Paste, Cut, Undo, Redo, Save, Select All, Close
```

---

## Related Areas

- **UI**: Uses `RingGeometry` for slot positioning
- **Context**: Profile lookup by bundle ID
- **Execution**: `RingAction` executed by `ActionExecutor` (planned)
- **Storage**: Profiles persisted to SQLite (planned)
- **MCP**: `mcpServers` array for tool discovery (planned)

---

## Performance Notes

All types are value types (structs) - cheap to copy, no reference counting overhead. `Sendable` conformance enables safe cross-actor isolation for future concurrency implementation.
