# MacRing -- Core Layer Codemap (Business Logic)

> Generated: 2026-02-20 | Source: PRD v2.0.0 | Status: Pre-development (planning phase)

---

## Directory Structure

```
MacRing/
  Core/
    Input/
      EventTapManager.swift       -- CGEventTap at kCGHIDEventTap
      MouseButtonRecorder.swift   -- Brand-agnostic button recording
      KeyboardMonitor.swift       -- Global modifier+key combo tracking
    Context/
      AppDetector.swift           -- NSWorkspace app activation detection
      ContextEngine.swift         -- Orchestrator: app switch -> profile -> ring
      FullscreenDetector.swift    -- Fullscreen suppression
      AppCategoryMap.swift        -- Bundle ID -> category mapping
    Profile/
      RingProfile.swift           -- Profile struct + ProfileSource enum
      RingSlot.swift              -- Slot struct (position, label, icon, action)
      RingAction.swift            -- 13-case action enum
      MCPToolAction.swift         -- MCP tool call parameters
      MCPWorkflowAction.swift     -- Chained MCP workflow steps
      ProfileManager.swift        -- CRUD, lookup chain, cache, Combine
      ProfileImportExport.swift   -- .macring JSON export/import
      BuiltInProfiles.swift       -- 50+ preset profiles seeder
    Execution/
      ActionExecutor.swift        -- Dispatcher via ActionRunnable protocol
      KeyboardSimulator.swift     -- CGEvent key simulation
      SystemActionRunner.swift    -- Lock, screenshot, volume, brightness
      ScriptRunner.swift          -- Shell (Process) + AppleScript, 10s timeout
      WorkflowRunner.swift        -- Multi-step sequences, cancellation
      MCPActionRunner.swift       -- MCP tool/workflow execution bridge
  AI/
    AIService.swift               -- Claude API client, model routing, retry
    AIPromptBuilder.swift         -- Prompt templates, privacy enforcement
    AIResponseParser.swift        -- JSON validation, Codable parsing
    AICache.swift                 -- Response cache (7-day TTL)
    TokenTracker.swift            -- Usage + cost tracking, budget warning
    BehaviorTracker.swift         -- Ring interaction recording, TTL purge
    SuggestionManager.swift       -- Online (Haiku) + offline (rule-based)
    AutoProfileGenerator.swift    -- Sonnet profile gen, preview before apply
    NLConfigEngine.swift          -- NL command parsing, undo stack
    WorkflowBuilder.swift         -- NL -> multi-step workflow generation
    OfflineFallbackManager.swift  -- NWPathMonitor, request routing
  MCP/
    MCPClient.swift               -- mcp-swift-sdk wrapper, stdio + HTTP/SSE
    MCPServerManager.swift        -- Server lifecycle, heartbeat, reconnect
    MCPCredentialManager.swift    -- Per-server Keychain isolation
    MCPRegistry.swift             -- smithery.ai query, 7-day cache
    MCPToolRunner.swift           -- Tool execution, error handling
    MCPActionAdapter.swift        -- RingAction -> MCP call conversion
    MCPWorkflowRunner.swift       -- Chained tool execution, output passing
  Semantic/
    NLEmbeddingEngine.swift       -- NLEmbedding 512-dim vectors
    SequenceExtractor.swift       -- Raw interactions -> 30s-window sequences
    VectorStore.swift             -- SQLite BLOB CRUD, 90-day purge
    CosineSimilarity.swift        -- Accelerate.framework vDSP
    BehaviorClusterer.swift       -- k-NN (k=5), silhouette tracking
    PatternInterpreter.swift      -- Cluster -> Haiku -> workflow name
  Storage/
    Database.swift                -- GRDB setup, WAL, 13 tables, migrations
    KeychainManager.swift         -- Security.framework wrapper
    VectorDatabase.swift          -- Vector query layer
    ShortcutDatabase.swift        -- Preset query by bundle ID / category
```

---

## Input Layer

| Component | Responsibility | Thread | Risk |
|-----------|---------------|--------|------|
| `EventTapManager` | CGEventTap at kCGHIDEventTap, intercept `.otherMouseDown`/`.otherMouseUp`, consume trigger event | EventTap (`.userInteractive`) | HIGH -- requires Accessibility, conflicts with BTT/Options+ |
| `MouseButtonRecorder` | Listen for ANY button, capture CGMouseButton int, save as trigger | EventTap | Low |
| `KeyboardMonitor` | Global CGEventTap for modifier+key combos ONLY (never raw typing) | EventTap | Medium -- must not capture passwords |

**Universal mouse support:** CGEventTap normalizes all brands at HID layer. CGMouseButton is a simple int (0-31). No vendor drivers needed.

---

## Context Layer

| Component | Responsibility | Latency |
|-----------|---------------|---------|
| `AppDetector` | NSWorkspace.didActivateApplicationNotification, extract bundleIdentifier | <10ms |
| `ContextEngine` | Orchestrate: app switch -> profile lookup -> ring update -> MCP discovery | <500ms |
| `FullscreenDetector` | NSScreen + CGWindowListCopyWindowInfo, configurable suppression | <10ms |
| `AppCategoryMap` | Bundle ID -> AppCategory (IDE, Browser, Design...), loaded from JSON | Instant (cached) |

---

## Profile Layer

| Component | Responsibility |
|-----------|---------------|
| `RingProfile` | Struct: id, name, bundleId, category, slots, slotCount, mcpServers, source |
| `RingSlot` | Struct: position, label, icon (SF Symbol), action, isEnabled, color |
| `RingAction` | Enum with 13 cases (11 local + 2 MCP) |
| `ProfileManager` | CRUD, 4-step lookup chain, in-memory cache, Combine publisher |
| `ProfileImportExport` | Export `.macring` JSON (NSSavePanel), import + validate (NSOpenPanel) |
| `BuiltInProfiles` | Seed DB with 50+ presets from `shortcut_presets.json` |

**Profile sources:** `.builtin` | `.user` | `.ai` | `.community` | `.mcp`

---

## Execution Layer

| Runner | Actions Handled | Mechanism | Timeout |
|--------|----------------|-----------|---------|
| `ActionExecutor` | All (dispatcher) | Routes via `ActionRunnable` protocol | -- |
| `KeyboardSimulator` | `keyboardShortcut` | CGEvent keyDown/keyUp + modifiers | <20ms |
| `SystemActionRunner` | `systemAction` | NSWorkspace + CGSession | <20ms |
| `ScriptRunner` | `shellScript`, `appleScript` | Process / NSAppleScript | 10s |
| `WorkflowRunner` | `workflow` | Sequential steps, configurable delay | Unbounded |
| `MCPActionRunner` | `mcpToolCall`, `mcpWorkflow` | MCPClient via MCPActionAdapter | 3s/step |

---

## AI Layer

| Component | Model | Purpose | Offline Fallback |
|-----------|-------|---------|-----------------|
| `AIService` | Haiku/Sonnet | Claude API client, rate limiting, 3x retry | N/A |
| `AIPromptBuilder` | -- | Template builder, privacy enforcement | N/A |
| `AIResponseParser` | -- | JSON validation, Codable parsing | N/A |
| `AICache` | -- | Prompt hash -> response, 7-day TTL | N/A |
| `TokenTracker` | -- | Per-day token count, monthly budget | N/A |
| `BehaviorTracker` | -- | Record ring interactions, TTL purge | Always on |
| `SuggestionManager` | Haiku | Smart suggestions (confidence >= 0.7) | Rule-based (frequency threshold) |
| `AutoProfileGenerator` | Sonnet | Generate 8-slot profile for unknown app | Category preset |
| `NLConfigEngine` | Sonnet | "Add screenshot to slot 3" | Disabled |
| `WorkflowBuilder` | Sonnet | NL -> multi-step action sequence | Manual-only |
| `OfflineFallbackManager` | -- | NWPathMonitor, request routing | -- |

---

## MCP Layer

| Component | Purpose | Transport |
|-----------|---------|-----------|
| `MCPClient` | mcp-swift-sdk wrapper, connect/list/call/disconnect | stdio, HTTP/SSE |
| `MCPServerManager` | Start/stop local servers (Process), heartbeat, auto-reconnect | stdio |
| `MCPCredentialManager` | Per-server Keychain (`macring.mcp.{serverId}`), masked display | -- |
| `MCPRegistry` | Query smithery.ai, cache in `mcp_tools` (7-day TTL) | HTTPS |
| `MCPToolRunner` | Execute tool, handle errors (timeout, auth, not found) | via MCPClient |
| `MCPActionAdapter` | Bridge RingAction -> MCPToolRunner, parameter templates | -- |
| `MCPWorkflowRunner` | Chain tool calls, output passing between steps, per-step progress | via MCPClient |

**Supported servers (v1.0):** GitHub, Slack, Notion, Linear, Filesystem, Docker, Postgres, Brave Search, Puppeteer, Memory

---

## Semantic Layer

| Component | Purpose | Schedule |
|-----------|---------|----------|
| `NLEmbeddingEngine` | NLEmbedding 512-dim vectors from action sequence strings | On demand |
| `SequenceExtractor` | Group raw interactions into 30-second-window sequences | Continuous |
| `VectorStore` | SQLite BLOB CRUD, batch insert, 90-day auto-purge | On write |
| `CosineSimilarity` | Accelerate.framework vDSP vectorized similarity | On cluster |
| `BehaviorClusterer` | k-NN (k=5), silhouette >0.6 target | Every 6h or on demand |
| `PatternInterpreter` | Cluster reps -> Haiku -> workflow name + description | After clustering |

**Fallback:** If silhouette <0.4, fall back to frequency-only analysis (no Haiku needed).

---

## Storage Layer

| Component | Backend | Purpose |
|-----------|---------|---------|
| `Database` | GRDB.swift 6.x (SQLite, WAL mode) | 13 tables, migration chain |
| `KeychainManager` | Security.framework | All secrets, per-service isolation |
| `VectorDatabase` | SQLite BLOB | Vector retrieval by bundleId, time, cluster |
| `ShortcutDatabase` | SQLite | Preset queries by bundle ID / category |

---

## Key Data Flows

### Ring Trigger -> Action Execution
```
EventTapManager (otherMouseDown)
  -> RingViewModel.show(at: cursorPosition)
  -> ProfileManager.activeProfile
  -> RingView renders slots
  -> User moves to slot (atan2 math)
  -> EventTapManager (otherMouseUp)
  -> ActionExecutor.execute(slot.action)
  -> [KeyboardSimulator | ScriptRunner | MCPActionRunner | ...]
```

### App Switch -> Profile Update
```
AppDetector (NSWorkspace notification)
  -> ContextEngine.handleAppSwitch(bundleId)
  -> ProfileManager.lookup(bundleId)     -- 4-step chain
  -> MCPRegistry.relevantServers(bundleId) -- parallel
  -> ContextEngine merges MCP tools
  -> RingViewModel.updateProfile(newProfile)
```

### Behavior -> Suggestion
```
BehaviorTracker.record(actionEvent)      -- every ring use
  -> raw_interactions table (TTL purge)
  -> usage_records table (aggregated)
  ...6h later...
SequenceExtractor -> BehaviorSequence
  -> NLEmbeddingEngine -> 512-dim vector
  -> VectorStore
  -> BehaviorClusterer (k-NN)
  -> PatternInterpreter (Haiku)
  -> SuggestionManager -> AISuggestion
  -> User accept/dismiss -> ProfileManager.update()
```
