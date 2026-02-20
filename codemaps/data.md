<!-- Updated: 2026-02-20 -->
# MacRing -- Data Models & Storage Codemap

> Status: **Phase 1 (Foundation)** -- RingGeometry + RingSize defined (stubs), all other models planned

---

## Implemented Models

### RingGeometry (UI/RingGeometry.swift -- scaffold, fatalError stubs)

```swift
struct RingGeometry {
    let outerDiameter: CGFloat   // 220 | 280 | 340
    let deadZoneRadius: CGFloat  // 35
    let slotCount: Int           // 4 | 6 | 8

    func selectedSlot(for point: CGPoint) -> Int?  // nil = dead zone
    func slotAngle(for index: Int) -> CGFloat      // radians
    func slotCenter(for index: Int) -> CGPoint     // mid-radius point
    var slotAngularWidth: CGFloat                  // 2pi / slotCount
    var outerRadius: CGFloat                       // outerDiameter / 2
    func isInRingArea(point: CGPoint) -> Bool       // dead zone < d < outer
}
```

### RingSize (UI/RingGeometry.swift -- scaffold, fatalError stub)

```swift
enum RingSize {
    case small    // outerDiameter = 220
    case medium   // outerDiameter = 280
    case large    // outerDiameter = 340
}
```

---

## Planned Models (Not Yet Created)

### RingProfile

```swift
struct RingProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var bundleId: String?           // nil = category or default
    var category: AppCategory?
    var slots: [RingSlot]
    var slotCount: Int              // 4 | 6 | 8
    var isDefault: Bool
    var mcpServers: [String]        // MCP server IDs
    var createdAt: Date
    var updatedAt: Date
    var source: ProfileSource       // .builtin | .user | .ai | .community | .mcp
}
```

### RingSlot

```swift
struct RingSlot: Codable, Identifiable {
    let id: UUID
    var position: Int               // 0-indexed (0-7)
    var label: String
    var icon: String                // SF Symbol name
    var action: RingAction
    var isEnabled: Bool
    var color: SlotColor?           // nil = action type default
}
```

### RingAction (13 cases)

```swift
enum RingAction: Codable {
    case keyboardShortcut(KeyboardShortcutAction)
    case launchApplication(LaunchAppAction)
    case openURL(OpenURLAction)
    case systemAction(SystemActionType)
    case shellScript(ShellScriptAction)
    case appleScript(AppleScriptAction)
    case shortcutsApp(ShortcutsAppAction)
    case textSnippet(TextSnippetAction)
    case openFileFolder(FileFolderAction)
    case workflow(WorkflowAction)
    case subRing(SubRingAction)
    case mcpToolCall(MCPToolAction)
    case mcpWorkflow(MCPWorkflowAction)
}
```

### Supporting Action Structs

| Struct | Key Fields |
|--------|-----------|
| `KeyboardShortcutAction` | `modifiers: [KeyModifier]`, `key: String` |
| `SystemActionType` (enum) | `lockScreen`, `screenshot`, `screenshotArea`, `volumeUp/Down/Mute`, `brightnessUp/Down`, `missionControl`, `notificationCenter`, `launchpad` |
| `MCPToolAction` | `serverId`, `toolName`, `parameters: [String: String]`, `displayName` |
| `MCPWorkflowAction` | `name`, `description`, `steps: [MCPWorkflowStep]` |
| `MCPWorkflowStep` | `action: MCPToolAction`, `stopOnError: Bool`, `outputMapping: [String: String]?` |

---

## Enums (Planned)

| Enum | Cases |
|------|-------|
| `ProfileSource` | `.builtin`, `.user`, `.ai`, `.community`, `.mcp` |
| `AppCategory` | `.ide`, `.browser`, `.design`, `.communication`, `.productivity`, `.media`, `.system`, `.gaming` |
| `SuggestionSource` | `.haiku`, `.ruleBased`, `.semantic` |
| `SuggestionStatus` | `.pending`, `.accepted`, `.dismissed` |
| `MCPTransport` | `.stdio`, `.httpSSE` |
| `MCPServerStatus` | `.connected`, `.disconnected`, `.connecting`, `.error` |

---

## Behavior & AI Models (Planned)

| Model | Key Fields | Table |
|-------|-----------|-------|
| `ActionEvent` | id, bundleId, actionType, actionLabel, slotPosition, timestamp | `raw_interactions` |
| `UsageRecord` | id, bundleId, actionType, actionLabel, count, lastUsed | `usage_records` |
| `BehaviorSequence` | id, actions, bundleId, timestamp, embedding (512-dim), clusterId | `behavior_sequences` |
| `AISuggestion` | id, bundleId, suggestedSlot, confidence (0-1), reason, source, status | `ai_suggestions` |
| `BehaviorCluster` | id, bundleId, centroid, frequency, silhouetteScore, interpretation | `behavior_clusters` |

---

## MCP Models (Planned)

| Model | Key Fields | Table |
|-------|-----------|-------|
| `MCPServer` | id, packageName, transport, isEnabled, autoStart, categories, status | `mcp_servers` |
| `MCPTool` | id (`{serverId}.{toolName}`), serverId, toolName, description, parameters | `mcp_tools` |
| `MouseTrigger` | buttonIndex (0-31), holdDurationMs (default 200), brand? | `triggers` |

---

## Database Schema (13 Tables -- Planned)

| Table | Primary Key | Retention | Notes |
|-------|-------------|-----------|-------|
| `profiles` | `id` (UUID) | Permanent | Slots stored as JSON column |
| `triggers` | `id` (Int) | Permanent | Single-row table |
| `mcp_servers` | `id` (String) | Permanent | Installed server configs |
| `mcp_credentials` | -- | Permanent | Reference only; creds in Keychain |
| `usage_records` | `id` (UUID) | 90 days | Aggregated action counts |
| `behavior_sequences` | `id` (UUID) | 90 days | Grouped action sequences |
| `vector_store` | `sequenceId` (UUID) | 90 days | Embedding BLOBs |
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

## Immutability Pattern

All models are Swift structs. Mutations produce new copies:

```swift
let updated = ProfileManager.update(profile, name: "New Name")
// Creates new struct, persists to DB, publishes via Combine
```

---

## Resource Files (Planned)

| File | Purpose |
|------|---------|
| `Resources/shortcut_presets.json` | 50+ built-in profiles |
| `Resources/app_categories.json` | 100+ bundle IDs -> AppCategory |
| `Resources/mcp_server_defaults.json` | Default configs for 10 MCP servers |
| `~/.macring/mcp-servers.json` | User MCP server configuration (runtime) |
