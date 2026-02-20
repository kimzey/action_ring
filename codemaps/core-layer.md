<!-- Updated: 2026-02-20 -->
# MacRing -- Core Layer Codemap (Business Logic)

> Status: **Phase 1 (Foundation)** -- RingGeometry scaffold exists, all other modules are planned

---

## Actual Directory Structure

```
Sources/MacRingCore/
  App/          .gitkeep                                          <- planned
  AI/           .gitkeep                                          <- planned
  Context/      .gitkeep                                          <- planned
  Execution/    .gitkeep                                          <- planned
  Input/        .gitkeep                                          <- planned
  MCP/          .gitkeep                                          <- planned
  Profile/      .gitkeep                                          <- planned
  Semantic/     .gitkeep                                          <- planned
  Storage/      .gitkeep                                          <- planned
  UI/
    RingGeometry.swift    <- scaffold (fatalError stubs, interface defined)

Tests/MacRingCoreTests/
  Context/      .gitkeep                                          <- planned
  Execution/    .gitkeep                                          <- planned
  Input/        .gitkeep                                          <- planned
  Profile/      .gitkeep                                          <- planned
  RingGeometryTests.swift <- 30 tests (Swift Testing framework)
```

---

## Implemented Files

### UI/RingGeometry.swift -- SCAFFOLD (fatalError stubs)

| Symbol | Type | Status | Purpose |
|--------|------|--------|---------|
| `RingSize` | enum | Stub | `.small` / `.medium` / `.large` with `outerDiameter` property |
| `RingGeometry` | struct | Stub | `outerDiameter`, `deadZoneRadius`, `slotCount` stored properties |
| `.selectedSlot(for:)` | method | Stub | Point -> slot index (nil if dead zone) |
| `.slotAngle(for:)` | method | Stub | Slot index -> angle in radians |
| `.slotCenter(for:)` | method | Stub | Slot index -> CGPoint at mid-radius |
| `.slotAngularWidth` | computed | Stub | `2pi / slotCount` |
| `.outerRadius` | computed | Stub | `outerDiameter / 2` |
| `.isInRingArea(point:)` | method | Stub | True if between dead zone and outer radius |

Imports: `Foundation`, `CoreGraphics`

### Tests/RingGeometryTests.swift -- COMPLETE (30 tests)

| Test Group | Count | Covers |
|------------|-------|--------|
| Outer radius | 1 | Half-diameter calculation |
| Slot angular width | 3 | 4, 6, 8 slot configurations |
| Dead zone | 4 | Origin, inside, boundary, just-outside |
| Outside ring | 1 | Beyond outer radius still selects |
| isInRingArea | 3 | Dead zone false, valid true, outside false |
| Slot selection (8) | 6 | Right(0), up-right(1), up(2), left(4), down(6), wrap(7) |
| Slot selection (4) | 4 | Right(0), up(1), left(2), down(3) |
| Slot angle | 4 | Slot 0/2/4/7 angles |
| Slot center | 2 | Slot 0 on +x, slot 2 on +y |
| RingSize constants | 3 | small=220, medium=280, large=340 |
| Edge cases | 3 | Negative coords, tiny distance, boundary between slots |

Framework: Swift Testing (`@Suite`, `@Test`, `#expect`)

---

## Planned Files (Not Yet Created)

### Input Layer

| File | Responsibility | Thread | Risk |
|------|---------------|--------|------|
| `EventTapManager.swift` | CGEventTap at kCGHIDEventTap, intercept `.otherMouseDown`/`.otherMouseUp` | EventTap (`.userInteractive`) | HIGH -- Accessibility required |
| `MouseButtonRecorder.swift` | Brand-agnostic button recording | EventTap | Low |
| `KeyboardMonitor.swift` | Global modifier+key combo tracking | EventTap | Medium |

### Context Layer

| File | Responsibility | Latency |
|------|---------------|---------|
| `AppDetector.swift` | NSWorkspace.didActivateApplicationNotification | <10ms |
| `ContextEngine.swift` | App switch -> profile lookup -> ring update -> MCP | <500ms |
| `FullscreenDetector.swift` | Fullscreen suppression | <10ms |
| `AppCategoryMap.swift` | Bundle ID -> AppCategory, JSON-backed | Instant |

### Profile Layer

| File | Responsibility |
|------|---------------|
| `RingProfile.swift` | Profile struct + ProfileSource enum |
| `RingSlot.swift` | Slot struct (position, label, icon, action) |
| `RingAction.swift` | 13-case action enum |
| `MCPToolAction.swift` | MCP tool call parameters |
| `MCPWorkflowAction.swift` | Chained MCP workflow steps |
| `ProfileManager.swift` | CRUD, 4-step lookup chain, cache, Combine |
| `ProfileImportExport.swift` | `.macring` JSON export/import |
| `BuiltInProfiles.swift` | 50+ preset profiles seeder |

### Execution Layer

| File | Actions Handled | Timeout |
|------|----------------|---------|
| `ActionExecutor.swift` | All (dispatcher via `ActionRunnable`) | -- |
| `KeyboardSimulator.swift` | `keyboardShortcut` | <20ms |
| `SystemActionRunner.swift` | `systemAction` | <20ms |
| `ScriptRunner.swift` | `shellScript`, `appleScript` | 10s |
| `WorkflowRunner.swift` | `workflow` (multi-step) | Unbounded |
| `MCPActionRunner.swift` | `mcpToolCall`, `mcpWorkflow` | 3s/step |

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

### Semantic Layer

| File | Purpose | Schedule |
|------|---------|----------|
| `NLEmbeddingEngine.swift` | NLEmbedding 512-dim vectors | On demand |
| `SequenceExtractor.swift` | 30-second-window grouping | Continuous |
| `VectorStore.swift` | SQLite BLOB CRUD, 90-day purge | On write |
| `CosineSimilarity.swift` | Accelerate vDSP | On cluster |
| `BehaviorClusterer.swift` | k-NN (k=5), silhouette >0.6 | Every 6h |
| `PatternInterpreter.swift` | Cluster -> Haiku -> workflow | After clustering |

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
