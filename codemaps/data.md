# MacRing -- Data Models & Storage Codemap

> Generated: 2026-02-20 | Source: PRD v2.0.0 | Status: Pre-development (planning phase)

---

## Core Models

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
    case keyboardShortcut(KeyboardShortcutAction)   // modifiers + key
    case launchApplication(LaunchAppAction)          // bundle ID or path
    case openURL(OpenURLAction)                      // URL string
    case systemAction(SystemActionType)              // lock, screenshot, volume...
    case shellScript(ShellScriptAction)              // bash/zsh, 10s timeout
    case appleScript(AppleScriptAction)              // NSAppleScript
    case shortcutsApp(ShortcutsAppAction)            // Shortcuts.app workflow
    case textSnippet(TextSnippetAction)              // paste text
    case openFileFolder(FileFolderAction)            // Finder reveal
    case workflow(WorkflowAction)                    // multi-step sequence
    case subRing(SubRingAction)                      // nested ring (v1.1)
    case mcpToolCall(MCPToolAction)                  // single MCP tool
    case mcpWorkflow(MCPWorkflowAction)              // chained MCP tools
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

## Enums

| Enum | Cases |
|------|-------|
| `ProfileSource` | `.builtin`, `.user`, `.ai`, `.community`, `.mcp` |
| `AppCategory` | `.ide`, `.browser`, `.design`, `.communication`, `.productivity`, `.media`, `.system`, `.gaming` |
| `SuggestionSource` | `.haiku`, `.ruleBased`, `.semantic` |
| `SuggestionStatus` | `.pending`, `.accepted`, `.dismissed` |
| `MCPTransport` | `.stdio`, `.httpSSE` |
| `MCPServerStatus` | `.connected`, `.disconnected`, `.connecting`, `.error` |

---

## Behavior & AI Models

| Model | Key Fields | Table |
|-------|-----------|-------|
| `ActionEvent` | id, bundleId, actionType, actionLabel, slotPosition, timestamp | `raw_interactions` |
| `UsageRecord` | id, bundleId, actionType, actionLabel, count, lastUsed | `usage_records` |
| `BehaviorSequence` | id, actions, bundleId, timestamp, embedding: [Float]? (512-dim), clusterId | `behavior_sequences` |
| `AISuggestion` | id, bundleId, suggestedSlot, confidence (0-1), reason, source, status | `ai_suggestions` |
| `BehaviorCluster` | id, bundleId, representativeSequences, centroid: [Float], frequency, silhouetteScore, interpretation | `behavior_clusters` |
| `ClusterInterpretation` | workflowName, description, suggestedAction, confidence | Embedded in BehaviorCluster |

---

## MCP Models

| Model | Key Fields | Table |
|-------|-----------|-------|
| `MCPServer` | id, packageName, transport, isEnabled, autoStart, categories, status | `mcp_servers` |
| `MCPTool` | id (`{serverId}.{toolName}`), serverId, toolName, description, parameters, categories | `mcp_tools` |
| `MCPParameter` | name, type, description, required, defaultValue | Embedded in MCPTool |
| `MouseTrigger` | buttonIndex (0-31), holdDurationMs (default 200), brand? | `triggers` |

---

## Database Schema (13 Tables)

| Table | Primary Key | Retention | Notes |
|-------|-------------|-----------|-------|
| `profiles` | `id` (UUID) | Permanent | Slots stored as JSON column |
| `triggers` | `id` (Int) | Permanent | Single-row table |
| `mcp_servers` | `id` (String) | Permanent | Installed server configs |
| `mcp_credentials` | -- | Permanent | Reference only; actual creds in Keychain |
| `usage_records` | `id` (UUID) | 90 days | Aggregated action counts |
| `behavior_sequences` | `id` (UUID) | 90 days | Grouped action sequences |
| `vector_store` | `sequenceId` (UUID) | 90 days | Embedding BLOBs |
| `behavior_clusters` | `id` (Int) | 90 days | k-NN cluster results |
| `ai_suggestions` | `id` (UUID) | 30 days | Cached suggestions |
| `ai_cache` | prompt hash | 7 days | API response cache |
| `mcp_tools` | `id` (String) | 7 days | Discovered tool cache |
| `raw_interactions` | `id` (UUID) | 24h-30d | User-configurable TTL |
| `shortcut_presets` | `bundleId` (String) | App updates | Bundled presets |

**Database config:** GRDB.swift 6.x, SQLite WAL mode, migration chain.

---

## Keychain Storage Map

| Service Tag | Content | Access |
|-------------|---------|--------|
| `macring.claude.apikey` | Claude API key | AIService only |
| `macring.mcp.github` | GitHub PAT | MCPCredentialManager |
| `macring.mcp.slack` | Slack Bot Token (`xoxb-...`) | MCPCredentialManager |
| `macring.mcp.notion` | Notion Integration Token | MCPCredentialManager |
| `macring.mcp.linear` | Linear API Key | MCPCredentialManager |
| `macring.mcp.brave-search` | Brave Search API Key | MCPCredentialManager |
| `macring.mcp.postgres` | Connection string | MCPCredentialManager |

**Rules:** Keychain only. Never UserDefaults. Never logged. Never in plaintext. Per-server isolation. Masked in UI (last 4 chars).

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

**Enforcement:** `AIPromptBuilder` blocks forbidden fields. Automated privacy tests in CI block merges on failure.

---

## Data Table -> Model Mapping

| Model | Table | Storage |
|-------|-------|---------|
| `RingProfile` | `profiles` | SQLite (GRDB) |
| `RingSlot` | `profiles.slots` (JSON) | Embedded |
| `ActionEvent` | `raw_interactions` | SQLite |
| `UsageRecord` | `usage_records` | SQLite |
| `BehaviorSequence` | `behavior_sequences` | SQLite |
| Embedding vectors | `vector_store` | SQLite BLOB |
| `AISuggestion` | `ai_suggestions` | SQLite |
| `BehaviorCluster` | `behavior_clusters` | SQLite |
| `MCPServer` | `mcp_servers` | SQLite |
| `MCPTool` | `mcp_tools` | SQLite |
| MCP credentials | Keychain | `macring.mcp.{serverId}` |
| `MouseTrigger` | `triggers` | SQLite |
| Shortcut presets | `shortcut_presets` | SQLite |

---

## Immutability Pattern

All models are Swift structs. Mutations produce new copies via copy-on-write:

```swift
// Update profile via ProfileManager (handles persistence + Combine publish)
let updated = ProfileManager.update(profile, name: "New Name")
```

Never mutate in place. `ProfileManager.update()` creates a new struct, persists to DB, and publishes via Combine.

---

## Resource Files

| File | Purpose |
|------|---------|
| `Resources/shortcut_presets.json` | 50+ built-in profiles (bundle ID -> 8 slots) |
| `Resources/app_categories.json` | 100+ bundle IDs -> AppCategory mapping |
| `Resources/mcp_server_defaults.json` | Default configs for 10 MCP servers |
| `~/.macring/mcp-servers.json` | User MCP server configuration (runtime) |
