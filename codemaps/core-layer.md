<!-- Updated: 2025-02-20 -->
# MacRing -- Core Layer Codemap (Business Logic)

> Status: **Phase 1 (Foundation)** -- Profile and UI models complete, other modules planned

---

## Actual Directory Structure

```
Sources/MacRingCore/
  Profile/                    -- COMPLETE
    RingAction.swift         -- 13 action types (283 lines)
    RingSlot.swift           -- Slot model (85 lines)
    RingProfile.swift        -- Profile model (178 lines)
  UI/                        -- COMPLETE
    RingGeometry.swift       -- Geometry calculations (145 lines)
  App/          .gitkeep     -- Planned
  AI/           .gitkeep     -- Planned
  Context/      .gitkeep     -- Planned
  Execution/    .gitkeep     -- Planned
  Input/        .gitkeep     -- Planned
  MCP/          .gitkeep     -- Planned
  Semantic/     .gitkeep     -- Planned
  Storage/      .gitkeep     -- Planned

Tests/MacRingCoreTests/
  Profile/                    -- COMPLETE
    RingActionTests.swift    -- 28 tests
    RingSlotTests.swift      -- 23 tests
    RingProfileTests.swift   -- 29 tests
  RingGeometryTests.swift     -- 30 tests
  Context/      .gitkeep     -- Planned
  Execution/    .gitkeep     -- Planned
  Input/        .gitkeep     -- Planned
```

---

## Implemented Modules

### Profile Layer (COMPLETE)

| File | Lines | Exports | Tests |
|------|-------|---------|-------|
| `RingAction.swift` | 283 | `RingAction`, `KeyCode`, `SpecialKey`, `KeyModifier`, `SystemAction`, `MCPToolAction`, `MCPWorkflowAction` | 28 |
| `RingSlot.swift` | 85 | `RingSlot`, `SlotColor` | 23 |
| `RingProfile.swift` | 178 | `RingProfile`, `ProfileSource`, `AppCategory` | 29 |

**Key Types:**
- `RingAction` -- 12-case enum defining all executable actions
- `RingSlot` -- Single position in the ring with optional action
- `RingProfile` -- Complete profile with slots, metadata, lifecycle methods

**Dependencies:** `Foundation` only

---

### UI Layer (COMPLETE)

| File | Lines | Exports | Tests |
|------|-------|---------|-------|
| `RingGeometry.swift` | 145 | `RingGeometry`, `RingSize`, CGPoint extensions | 30 |

**Key Types:**
- `RingSize` -- small/medium/large presets with diameters
- `RingGeometry` -- Coordinate transforms, slot selection, area detection

**Dependencies:** `Foundation`, `AppKit` (conditional)

---

## Planned Modules

### Input Layer

| File | Responsibility | Thread | Risk |
|------|---------------|--------|------|
| `EventTapManager.swift` | CGEventTap at kCGHIDEventTap, intercept `.otherMouseDown`/`.otherMouseUp` | EventTap (`.userInteractive`) | HIGH -- Accessibility required |
| `MouseButtonRecorder.swift` | Brand-agnostic button recording | EventTap | Low |
| `KeyboardMonitor.swift` | Global modifier+key combo tracking | EventTap | Medium |

---

### Context Layer

| File | Responsibility | Latency |
|------|---------------|---------|
| `AppDetector.swift` | NSWorkspace.didActivateApplicationNotification | <10ms |
| `ContextEngine.swift` | App switch -> profile lookup -> ring update -> MCP | <500ms |
| `FullscreenDetector.swift` | Fullscreen suppression | <10ms |
| `AppCategoryMap.swift` | Bundle ID -> AppCategory, JSON-backed | Instant |

---

### Execution Layer

| File | Actions Handled | Timeout |
|------|----------------|---------|
| `ActionExecutor.swift` | All (dispatcher via `ActionRunnable`) | -- |
| `KeyboardSimulator.swift` | `keyboardShortcut` | <20ms |
| `SystemActionRunner.swift` | `systemAction` | <20ms |
| `ScriptRunner.swift` | `shellScript`, `appleScript` | 10s |
| `WorkflowRunner.swift` | `workflow` (multi-step) | Unbounded |
| `MCPActionRunner.swift` | `mcpToolCall`, `mcpWorkflow` | 3s/step |

---

### AI Layer

| File | Model | Purpose |
|------|-------|---------|
| `AIService.swift` | Haiku/Sonnet | Claude API client, retry |
| `AIPromptBuilder.swift` | -- | Templates, privacy enforcement |
| `AIResponseParser.swift` | -- | JSON validation |
| `AICache.swift` | -- | 7-day TTL cache |
| `TokenTracker.swift` | -- | Usage + cost tracking |
| `BehaviorTracker.swift` | -- | Interaction recording |
| `SuggestionManager.swift` | Haiku | Smart suggestions |
| `AutoProfileGenerator.swift` | Sonnet | Profile generation |
| `NLConfigEngine.swift` | Sonnet | NL command parsing |
| `WorkflowBuilder.swift` | Sonnet | NL -> workflow |
| `OfflineFallbackManager.swift` | -- | NWPathMonitor routing |

---

### MCP Layer

| File | Purpose | Transport |
|------|---------|-----------|
| `MCPClient.swift` | mcp-swift-sdk wrapper | stdio, HTTP/SSE |
| `MCPServerManager.swift` | Server lifecycle, heartbeat | stdio |
| `MCPCredentialManager.swift` | Per-server Keychain | -- |
| `MCPRegistry.swift` | smithery.ai query, 7-day cache | HTTPS |
| `MCPToolRunner.swift` | Tool execution | via MCPClient |
| `MCPActionAdapter.swift` | RingAction -> MCP bridge | -- |
| `MCPWorkflowRunner.swift` | Chained tool execution | via MCPClient |

---

### Semantic Layer

| File | Purpose | Schedule |
|------|---------|----------|
| `NLEmbeddingEngine.swift` | NLEmbedding 512-dim vectors | On demand |
| `SequenceExtractor.swift` | 30-second-window grouping | Continuous |
| `VectorStore.swift` | SQLite BLOB CRUD, 90-day purge | On write |
| `CosineSimilarity.swift` | Accelerate vDSP | On cluster |
| `BehaviorClusterer.swift` | k-NN (k=5), silhouette >0.6 | Every 6h |
| `PatternInterpreter.swift` | Cluster -> Haiku -> workflow | After clustering |

---

### Storage Layer

| File | Backend | Purpose |
|------|---------|---------|
| `Database.swift` | GRDB.swift 6.x (WAL) | 13 tables, migrations |
| `KeychainManager.swift` | Security.framework | All secrets |
| `VectorDatabase.swift` | SQLite BLOB | Vector retrieval |
| `ShortcutDatabase.swift` | SQLite | Preset queries |

---

## Key Data Flows

### Ring Trigger -> Action Execution
```
EventTapManager (otherMouseDown)
  -> RingViewModel.show(at: cursorPosition)
  -> ProfileManager.activeProfile
  -> RingView renders slots
  -> User moves to slot (RingGeometry.selectedSlot math)
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

---

## Module Dependencies

```
Input (EventTapManager) --[notifications]--> Context
      |
      +--[cursor position]--> UI (RingGeometry)

Context (ContextEngine) --[profile lookup]--> Profile
      |
      +--[app info]--> AI (AIService)

Profile (ProfileManager) --[slots]--> UI
      |
      +--[actions]--> Execution (ActionExecutor)

Execution --[MCP actions]--> MCP (MCPClient)

AI --[behavior data]--> Semantic (NLEmbeddingEngine)
      |
      +--[suggestions]--> Profile

All modules --[persistence]--> Storage (Database)
```

---

## Related Codemaps

- [architecture.md](architecture.md) -- Overall system architecture
- [profile.md](profile.md) -- Profile system details
- [ui.md](ui.md) -- UI components
- [data.md](data.md) -- Data models and storage
