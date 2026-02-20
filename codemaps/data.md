<!-- Updated: 2025-02-20 -->
# MacRing -- Data Models & Storage Codemap

> Status: **Phase 1 (Foundation)** -- Core models implemented, storage layer planned

---

## Implemented Models

### RingAction (Profile/RingAction.swift -- 283 lines, COMPLETE)

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
    case workflow([RingAction])
    case mcpToolCall(MCPToolAction)
    case mcpWorkflow(MCPWorkflowAction)
}
```

**Supporting Types:**
- `KeyCode: .character(Character) | .special(SpecialKey)`
- `SpecialKey: enter, tab, space, escape, delete, backspace, home, end, pageUp, pageDown, arrows, F1-F12`
- `KeyModifier: command, shift, option, control, capsLock, function`
- `SystemAction: lockScreen, screenshot, volumeUp/Down, mute, brightnessUp/Down, missionControl, showDesktop, launchpad, notificationCenter, sleep, restart, shutdown`
- `MCPToolAction: serverId, toolName, parameters, displayName`
- `MCPWorkflowAction: serverId, workflowId, parameters, displayName`

---

### RingSlot (Profile/RingSlot.swift -- 85 lines, COMPLETE)

```swift
public struct RingSlot: Codable, Equatable, Sendable {
    public var position: Int               // 0-7
    public var label: String
    public var icon: String                // SF Symbol
    public var action: RingAction?
    public var isEnabled: Bool
    public var color: SlotColor            // blue/purple/pink/red/orange/yellow/green/gray

    static let maxPosition = 7
    var isValid: Bool                      // position 0-7
    var isDisabled: Bool                   // !isEnabled
    var hasAction: Bool                    // action != nil
}
```

---

### RingProfile (Profile/RingProfile.swift -- 178 lines, COMPLETE)

```swift
public struct RingProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var bundleId: String?
    public var category: AppCategory
    public var slots: [RingSlot]
    public var slotCount: Int              // 4, 6, or 8
    public var isDefault: Bool
    public var mcpServers: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var source: ProfileSource

    static let validSlotCounts = [4, 6, 8]
    static func createDefault() -> RingProfile

    var isValid: Bool
    func touch() -> updates updatedAt
    func addSlot(_:) -> add/replace slot
    func removeSlot(at:) -> remove slot
    func updateSlot(at:with:) -> update slot
    func slotAt(position:) -> RingSlot?
}
```

**Enums:**
- `ProfileSource: builtin, user, ai, community, mcp`
- `AppCategory: ide, browser, design, productivity, communication, media, development, terminal, other`

---

### RingGeometry (UI/RingGeometry.swift -- 145 lines, COMPLETE)

```swift
public struct RingGeometry: Equatable, Sendable {
    public let outerDiameter: CGFloat      // 220/280/340
    public let deadZoneRadius: CGFloat     // 30/35/40
    public let slotCount: Int              // 4/6/8

    var outerRadius: CGFloat               // diameter / 2
    var slotAngularWidth: CGFloat          // 2pi / slotCount

    func selectedSlot(for: CGPoint) -> Int?
    func slotAngle(for: Int) -> CGFloat
    func slotCenter(for: Int) -> CGPoint
    func isInRingArea(point: CGPoint) -> Bool
}

public enum RingSize {
    case small   // 220px, dead zone 30px
    case medium  // 280px, dead zone 35px
    case large   // 340px, dead zone 40px

    var outerDiameter: CGFloat
    var defaultDeadZoneRadius: CGFloat
}
```

---

## Planned Models (Not Yet Created)

### Behavior & AI Models

| Model | Key Fields | Purpose |
|-------|-----------|---------|
| `ActionEvent` | id, bundleId, actionType, actionLabel, slotPosition, timestamp | Raw interaction record |
| `UsageRecord` | id, bundleId, actionType, actionLabel, count, lastUsed | Aggregated usage stats |
| `BehaviorSequence` | id, actions, bundleId, timestamp, embedding (512-dim), clusterId | Grouped actions for clustering |
| `AISuggestion` | id, bundleId, suggestedSlot, confidence (0-1), reason, source, status | AI-generated suggestions |
| `BehaviorCluster` | id, bundleId, centroid, frequency, silhouetteScore, interpretation | k-NN cluster results |

### MCP Models

| Model | Key Fields | Purpose |
|-------|-----------|---------|
| `MCPServer` | id, packageName, transport, isEnabled, autoStart, categories, status | Server configuration |
| `MCPTool` | id (`{serverId}.{toolName}`), serverId, toolName, description, parameters | Discovered tools |
| `MouseTrigger` | buttonIndex (0-31), holdDurationMs (default 200) | Trigger configuration |

### Context Models

| Model | Key Fields | Purpose |
|-------|-----------|---------|
| `AppContext` | bundleId, processId, windowTitle*, isFullscreen | Current app state |
| `CategoryMapping` | bundleId, category, confidence | Bundle ID -> category lookup |

---

## Database Schema (13 Tables -- Planned)

| Table | Primary Key | Retention | Purpose |
|-------|-------------|-----------|---------|
| `profiles` | `id` (UUID) | Permanent | User and built-in profiles |
| `triggers` | `id` (Int) | Permanent | Mouse trigger configuration |
| `mcp_servers` | `id` (String) | Permanent | MCP server configs |
| `mcp_credentials` | -- | Permanent | Reference only; creds in Keychain |
| `usage_records` | `id` (UUID) | 90 days | Aggregated action counts |
| `behavior_sequences` | `id` (UUID) | 90 days | Grouped action sequences |
| `vector_store` | `sequenceId` (UUID) | 90 days | NLEmbedding BLOBs |
| `behavior_clusters` | `id` (Int) | 90 days | k-NN cluster results |
| `ai_suggestions` | `id` (UUID) | 30 days | Cached suggestions |
| `ai_cache` | prompt hash | 7 days | API response cache |
| `mcp_tools` | `id` (String) | 7 days | Discovered tool cache |
| `raw_interactions` | `id` (UUID) | 24h-30d | User-configurable TTL |
| `shortcut_presets` | `bundleId` (String) | App updates | Bundled presets |

**Database config:** GRDB.swift 6.x, SQLite WAL mode, migration chain. Not yet implemented.

---

## Keychain Storage Map (Planned)

| Service Tag | Content | Access |
|-------------|---------|--------|
| `macring.claude.apikey` | Claude API key | AIService only |
| `macring.mcp.github` | GitHub PAT | MCPCredentialManager |
| `macring.mcp.slack` | Slack Bot Token | MCPCredentialManager |
| `macring.mcp.notion` | Notion Integration Token | MCPCredentialManager |
| `macring.mcp.linear` | Linear API Key | MCPCredentialManager |
| `macring.mcp.brave-search` | Brave Search API Key | MCPCredentialManager |
| `macring.mcp.postgres` | Connection string | MCPCredentialManager |

---

## Privacy Constraints

| Safe to send to Claude API | NEVER send to Claude API |
|---------------------------|--------------------------|
| App bundle IDs | Window titles |
| Shortcut key combinations | File names / paths |
| Usage frequency counts | Document content |
| Ring configuration | Typed text / passwords |
| Aggregated behavior patterns | Raw UI events |
| MCP tool names | Screen / clipboard content |

---

## Codable Implementation

All implemented types are fully `Codable`:
- `RingAction`: Custom `KeyCode` encoding with type discriminator
- `RingSlot`: Auto-synthesized
- `RingProfile`: Auto-synthesized
- `RingGeometry`: Not `Codable` (runtime-only computation)

---

## Test Coverage

| Model | Tests | Status |
|-------|-------|--------|
| `RingAction` | 28 | All action types, Codable, equality, descriptions |
| `RingSlot` | 23 | Creation, validation, actions, state |
| `RingProfile` | 29 | CRUD, validation, slot management, MCP |
| `RingGeometry` | 30 | Geometry, slot selection, areas |

**Total:** 110 tests for implemented models

---

## Related Codemaps

- [profile.md](profile.md) -- Profile system details
- [ui.md](ui.md) -- UI geometry details
- [architecture.md](architecture.md) -- Overall system architecture
