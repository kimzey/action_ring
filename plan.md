# Implementation Plan: MacRing v1.0

> **Source:** Derived from `MacRing_PRD_v2.md` (single source of truth)
> **Status:** Awaiting user confirmation before any code is written
> **Total Duration:** 18 weeks across 7 phases
> **Platform:** macOS 14+, Swift 5.10+, SwiftUI 5.0+

---

## Requirements Summary

### P0 (Must Have)

- Ring appears in under 50ms when trigger button is held
- Ring renders at 60fps with glassmorphism (NSPanel, non-activating, floating)
- Slot selection via angle math with 35px dead zone cancel
- Works with ANY mouse brand via CGEventTap (Logitech, Razer, Keychron, SteelSeries, Apple Magic Mouse, generic)
- Button recording mode for trigger assignment
- Context-aware auto-switching profiles by app bundle ID
- 50+ built-in app profile presets
- 100% detection rate for top 50 apps
- Fullscreen detection (disable ring in fullscreen games)
- Core ring works fully offline without API key
- Menu bar integration (status item, popover)
- Privacy: no window titles, file paths, document content, typed text ever sent to API
- Configurable raw interaction TTL (24h default, up to 30d)

### P1 (Should Have)

- AI smart suggestions with >80% acceptance rate
- Auto profile generation for unknown apps
- MCP tool execution from ring slots (GitHub, Slack, Notion tested)
- MCP auto-discovery on app switch
- Visual drag-and-drop configurator studio
- Import/export/share profiles (including MCP server references)
- Zero-config: time to useful ring under 3 seconds

### P2 (Nice to Have)

- Natural language configuration ("Add screenshot to slot 3")
- Semantic clustering quality (silhouette score >0.6)
- NL config intent recognition >90%

---

## Architecture Layers

```
MacRing/
├── App/          - Entry point (MacRingApp.swift, AppDelegate.swift)
├── Core/
│   ├── Input/    - CGEventTap mouse capture (brand-agnostic)
│   ├── Context/  - App detection & profile switching
│   ├── Profile/  - Ring profiles, slots, 13 action types
│   └── Execution/- Action execution (keyboard, scripts, MCP)
├── AI/           - Claude API, suggestions, behavior tracking, caching
├── MCP/          - MCP client, registry, server lifecycle, tool execution
├── Semantic/     - NLEmbedding, vector store, k-NN clustering
├── UI/           - SwiftUI ring, configurator, menu bar, onboarding, settings
└── Storage/      - GRDB (SQLite), Keychain, vector DB
```

---

## Phase 1: Foundation (Weeks 1–3)

**Goal:** Ring appears, user selects a slot, action executes. Universal mouse support. Menu bar icon.

### Week 1: Project Scaffold & Input Layer

| # | File | Action | Complexity | Risk |
|---|------|--------|-----------|------|
| 1 | `MacRing.xcodeproj` | Create macOS app project, add SPM deps (GRDB 6.x, Sparkle 2.x), add `.swiftlint.yml` | Low | Low |
| 2 | `App/MacRingApp.swift` | SwiftUI App entry point, register AppDelegate, init core services | Low | Low |
| 3 | `App/AppDelegate.swift` | Accessibility permission request, EventTap setup, status bar item, NSWorkspace notifications | Medium | Low |
| 4 | `Core/Input/EventTapManager.swift` | CGEventTap at kCGHIDEventTap. Intercept `.otherMouseDown`/`.otherMouseUp`. Consume trigger event. Dedicated `.userInteractive` thread. | **High** | **High** |
| 5 | `Core/Input/MouseButtonRecorder.swift` | Brand-agnostic button recording mode. Listen for ANY button, capture CGMouseButton integer, save as trigger. | Medium | Low |
| 6 | `Core/Input/KeyboardMonitor.swift` | Stub only — define protocol for later use in Phase 4 | Low | Low |

> **Risk note on EventTapManager:** Requires Accessibility permission. Can conflict with BetterTouchTool and Logitech Options+. Detect conflicting software on launch.

### Week 2: Ring UI & Slot Selection

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 7 | `Core/Profile/RingProfile.swift` | Struct: id, name, bundleId, category, slots, slotCount, isDefault, mcpServers, createdAt, updatedAt, source | Low |
| 8 | `Core/Profile/RingSlot.swift` | Struct: position, label, icon (SF Symbol), action (RingAction), isEnabled, color | Low |
| 9 | `Core/Profile/RingAction.swift` | Enum with all 13 cases. Phase 1: implement `.keyboardShortcut`, `.launchApplication`, `.openURL`, `.systemAction`. Others return `.notImplemented`. | Medium |
| 10 | `Core/Profile/MCPToolAction.swift` | Stub: serverId, toolName, parameters, displayName | Low |
| 11 | `Core/Profile/MCPWorkflowAction.swift` | Stub: steps: [MCPToolAction], name, description | Low |
| 12 | `UI/Ring/RingWindow.swift` | Custom NSPanel: non-activating, floating, transparent bg, positioned at cursor. Must appear <50ms. | **High** |
| 13 | `UI/Ring/RingView.swift` | SwiftUI: 4/6/8 slots radially. Glassmorphism (`.ultraThinMaterial`). Diameter: S=220/M=280/L=340px. Spring appear, easeOut dismiss. | **High** |
| 14 | `UI/Ring/RingViewModel.swift` | ObservableObject: isVisible, selectedSlot, currentProfile, cursorPosition. Slot selection: `floor((atan2(dy,dx) + 2π) % 2π / slotAngle)`. Dead zone check. | Medium |
| 15 | `UI/Ring/SlotView.swift` | Individual slot: highlight on hover/select, SF Symbol icon + label, scale animation, color by action type | Medium |

### Week 3: Action Execution & Menu Bar

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 16 | `Core/Execution/ActionExecutor.swift` | Dispatcher: routes RingAction to correct runner via protocol `ActionRunnable`. Phase 1: keyboard, launch app, URL, system. | Medium |
| 17 | `Core/Execution/KeyboardSimulator.swift` | CGEvent keyDown/keyUp with modifier flags. Multi-key combos. Validate key codes. | Medium |
| 18 | `Core/Execution/SystemActionRunner.swift` | Lock screen, screenshot, volume, brightness, Mission Control. NSWorkspace + CGSession. | Medium |
| 19 | `Core/Execution/ScriptRunner.swift` | Stub only — define protocol | Low |
| 20 | `Storage/Database.swift` | GRDB setup, WAL mode. Create all 13 tables from PRD §15.2. Migration chain. | **High** |
| 21 | `Storage/KeychainManager.swift` | Security.framework wrapper. Per-service isolation. Never UserDefaults for secrets. | Medium |
| 22 | `Core/Profile/ProfileManager.swift` | CRUD. Lookup chain: bundle ID → category → default. In-memory cache. Combine publisher. | Medium |
| 23 | `Core/Profile/BuiltInProfiles.swift` | Seed DB with 5 initial profiles: Finder, Safari, VS Code, Chrome, Default | Low |
| 24 | `Resources/shortcut_presets.json` | 5 profile definitions, 8 slots each. Expand to 50+ in Phase 2. | Low |
| 25 | `UI/MenuBar/MenuBarView.swift` | SwiftUI MenuBarExtra: current profile, active app, enable toggle, settings link, quit | Medium |
| 26 | `UI/MenuBar/StatusBarController.swift` | NSStatusItem lifecycle. Coordinate menu bar popover with ring window. | Low |

**Phase 1 Tests:**

| Test File | Coverage |
|-----------|----------|
| `EventTapManagerTests.swift` | Event tap creation, button filtering, trigger detection, event consumption |
| `RingViewModelTests.swift` | Slot selection math (all angles), dead zone, boundary, 4/6/8 slot configs |
| `ActionExecutorTests.swift` | Dispatch to correct runner, keyboard simulation, error handling |
| `ProfileManagerTests.swift` | CRUD, lookup chain, cache invalidation |
| `DatabaseTests.swift` | Migration, WAL mode, table creation, CRUD |
| `KeychainManagerTests.swift` | Store/retrieve/delete secrets, per-service isolation |
| `RingAppearanceUITests.swift` | Ring appears on trigger, dismisses on release, correct position |

**Phase 1 Deliverable:** Ring appears at cursor on button hold, 8 slots visible, slot selection works, action executes (keyboard shortcuts, launch app), menu bar icon.

---

## Phase 2: Context Awareness (Weeks 4–5) → **MVP**

**Goal:** Ring auto-switches profiles per focused app. 10+ presets. Fullscreen detection.

### Week 4: App Detection & Context Switching

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 27 | `Core/Context/AppDetector.swift` | NSWorkspace.didActivateApplicationNotification. Extract bundleIdentifier. Publish changes. Handle apps without bundle IDs. | Medium |
| 28 | `Core/Context/ContextEngine.swift` | Orchestrate: app switch → profile lookup → ring update. Log for BehaviorTracker. <10ms detection. | Medium |
| 29 | `Core/Context/FullscreenDetector.swift` | Detect fullscreen via NSScreen + CGWindowListCopyWindowInfo. Configurable suppression. | Medium |
| 30 | `Core/Context/AppCategoryMap.swift` | Map bundle IDs to categories (IDE, Browser, Design, etc). Loaded from app_categories.json. | Low |
| 31 | `Resources/app_categories.json` | 100+ bundle IDs → categories. Covers top 50 macOS apps. | Low |

### Week 5: Expanded Presets & Script Execution

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 32 | `Resources/shortcut_presets.json` (expand) | Add profiles: Figma, Photoshop, Slack, Terminal, Notion, Xcode, Mail → 10+ total | Low |
| 33 | `Core/Execution/ScriptRunner.swift` | Full impl: bash/zsh via Process, AppleScript via NSAppleScript. 10s timeout. Capture stdout/stderr. | Medium |
| 34 | `Core/Execution/WorkflowRunner.swift` | Stub — define protocol for multi-step sequences | Low |
| 35 | `Core/Execution/MCPActionRunner.swift` | Stub — define protocol | Low |

**Phase 2 Tests:**

| Test File | Coverage |
|-----------|----------|
| `AppDetectorTests.swift` | Bundle ID extraction, notification handling, edge cases |
| `ContextEngineTests.swift` | Profile switching on app change, lookup chain, <10ms timing |
| `FullscreenDetectorTests.swift` | Fullscreen detection, suppression toggle |
| `ScriptRunnerTests.swift` | Shell execution, timeout, error capture, AppleScript |
| `UniversalMouseTests.swift` | Simulate CGMouseButton 0–10, verify trigger detection for all |
| `ContextSwitchingIntegrationTests.swift` | End-to-end: switch app → profile changes → ring slots update |

**Phase 2 Deliverable (MVP):** Ring auto-switches by app. 10+ presets. Fullscreen detection. Shell/AppleScript execution. Any mouse works.

---

## Phase 3: Configurator Studio (Weeks 6–8)

**Goal:** Visual drag-and-drop configurator. Settings panel. Import/export profiles.

### Week 6: Configurator Layout

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 36 | `UI/Configurator/ConfiguratorWindow.swift` | NSWindow, split-pane: Action Toolbox (left) + Ring Preview (right) | Medium |
| 37 | `UI/Configurator/ActionToolbox.swift` | Scrollable sidebar. Action tiles grouped by category. Draggable. Search/filter. MCP placeholder section. | Medium |
| 38 | `UI/Configurator/RingPreview.swift` | Interactive ring matching production geometry. Slots are drop targets. Visual feedback on hover. | **High** |
| 39 | `UI/Configurator/SlotEditor.swift` | Detail editor: label, icon picker (SF Symbols), action type selector, action-specific params, validation | **High** |
| 40 | `UI/Configurator/ProfileListView.swift` | List all profiles. Create/duplicate/delete. Assign bundle ID. Source badge (builtin/user/AI). | Medium |

### Week 7: Settings & Appearance

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 41 | `UI/Settings/SettingsWindow.swift` | macOS Settings window with tabs: General, Appearance, Trigger, AI, MCP (stub), Privacy, About | Medium |
| 42 | `UI/Settings/GeneralSettingsView.swift` | Launch at login, enable toggle, check for updates, data retention slider | Low |
| 43 | `UI/Settings/AppearanceSettingsView.swift` | Ring size (S/M/L), slot count (4/6/8), color theme, icon size, label visibility. Live preview. | Medium |
| 44 | `UI/Settings/TriggerSettingsView.swift` | Current trigger display, "Record New Button", keyboard fallback for Magic Mouse, hold duration slider | Medium |
| 45 | `Storage/ShortcutDatabase.swift` | Query layer for shortcut presets. Indexed by bundle ID and category. Used by configurator. | Low |

### Week 8: Import/Export & Polish

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 46 | `Core/Profile/ProfileImportExport.swift` | Export to `.macring` JSON (NSSavePanel). Import from JSON (NSOpenPanel). Schema validation. MCP reference handling. | Medium |
| 47 | `UI/Configurator/DragDropManager.swift` | Manage drag-and-drop state. Slot reordering. Trash area. UTType registration. | Medium |
| 48 | `UI/Configurator/KeyRecorderView.swift` | Click to record key combo. Display "Cmd+Shift+F" format. Validate conflicts. | Medium |

**Phase 3 Tests:**

| Test File | Coverage |
|-----------|----------|
| `ProfileImportExportTests.swift` | Export/import roundtrip, schema validation, MCP reference handling |
| `SlotSelectionDragDropTests.swift` | Drag from toolbox to slot, reorder, remove |
| `ConfiguratorUITests.swift` | Open configurator, drag action to slot, save, verify ring updates |
| `SettingsUITests.swift` | All settings tabs accessible, changes persist |

**Phase 3 Deliverable:** Full visual configurator. Settings panel. Profile import/export. Ready for AI features.

---

## Phase 4: AI Integration (Weeks 9–12)

**Goal:** Smart suggestions, auto profile generation, NL config, workflow builder, offline fallback.

### Week 9: AI Client Foundation

| # | File | Action | Complexity | Risk |
|---|------|--------|-----------|------|
| 49 | `AI/AIService.swift` | Claude API client (URLSession async/await). Model routing (Haiku/Sonnet). Rate limiting. Exponential backoff retry (3x). API key validation. Structured JSON output. | **High** | Medium |
| 50 | `AI/AIPromptBuilder.swift` | Build prompts from templates (see `docs/prompts.md`). Enforce privacy: never include window titles, file paths, document content. | Medium | Low |
| 51 | `AI/AIResponseParser.swift` | Parse + validate JSON from Claude. Codable + custom validators. Graceful malformed response handling. | Medium | Low |
| 52 | `AI/AICache.swift` | Cache responses in `ai_cache` table. Key: prompt hash. TTL: 7 days. | Low | Low |
| 53 | `AI/TokenTracker.swift` | Track token usage + estimated cost. Per-day totals. Monthly budget warning. | Medium | Low |

### Week 10: Smart Suggestions & Behavior Tracking

| # | File | Action | Complexity | Risk |
|---|------|--------|-----------|------|
| 54 | `AI/BehaviorTracker.swift` | Record ring interactions → `raw_interactions` + `usage_records`. Background Tracker Queue. Auto-purge raw events per TTL. | Medium | Low |
| 55 | `Core/Input/KeyboardMonitor.swift` | Full impl: global CGEventTap for modifier+key combos only. Map to known shortcut names. Feed to BehaviorTracker. | Medium | Medium |
| 56 | `AI/SuggestionManager.swift` | Online: Haiku analysis → suggestions with confidence scores. Offline: rule-based (frequency threshold). Store in `ai_suggestions`. User accept/dismiss with feedback. | **High** | Low |

> **Risk on KeyboardMonitor:** Must NOT capture passwords or raw typing — only modifier+key combos.

### Week 11: Auto Profile Gen & NL Config

| # | File | Action | Complexity | Risk |
|---|------|--------|-----------|------|
| 57 | `AI/AutoProfileGenerator.swift` | New app → Sonnet generates 8-slot profile. Show preview before applying. Fallback to category preset if offline. | Medium | Low |
| 58 | `AI/NLConfigEngine.swift` | Parse NL commands via Sonnet. "Add screenshot to slot 3". Show preview before committing. Undo stack. Online-only. | **High** | Medium |
| 59 | `UI/Settings/NLConfigView.swift` | Text field "Ask MacRing...". Preview parsed intent. Command history. | Medium | Low |

### Week 12: Workflow Builder & Offline Fallback

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 60 | `AI/WorkflowBuilder.swift` | User describes workflow in NL → Sonnet generates multi-step action sequence. Preview each step. Manual editing of generated workflows. | **High** |
| 61 | `Core/Execution/WorkflowRunner.swift` | Full impl: execute multi-step sequences. Configurable delay between steps. Stop-on-error or continue mode. Progress notification. Cancellation. | Medium |
| 62 | `UI/Settings/AISettingsView.swift` | API key input (masked), usage chart, monthly budget, suggestion frequency, enable/disable AI, clear cache | Medium |
| 63 | `AI/OfflineFallbackManager.swift` | NWPathMonitor for online/offline detection. Route AI requests to correct handler. Rule-based offline fallback. | Medium |

**Phase 4 Tests:**

| Test File | Coverage |
|-----------|----------|
| `AIServiceTests.swift` | API calls, response parsing, retry, rate limiting, error handling (mock URLSession) |
| `AIPromptBuilderTests.swift` | Privacy validation — verify NO forbidden data in prompts |
| `SuggestionManagerTests.swift` | Online suggestions, offline fallback, confidence thresholds, accept/dismiss |
| `BehaviorTrackerTests.swift` | Event recording, TTL enforcement, aggregation |
| `NLConfigEngineTests.swift` | NL parsing, profile modification, preview accuracy |
| `WorkflowRunnerTests.swift` | Multi-step execution, error handling, cancellation |
| `TokenTrackerTests.swift` | Cost calculation, budget warnings |
| `AIIntegrationTests.swift` | End-to-end: behavior data in → suggestions out → profile updated (mocked API) |

**Phase 4 Deliverable:** AI smart suggestions (>80% acceptance), auto profile gen, NL config, workflow builder, full offline fallback.

---

## Phase 5: MCP Integration (Weeks 13–15)

**Goal:** MCP tools executable from ring. Auto-discovery. GitHub, Slack, Notion tested end-to-end.

### Week 13: MCP Client Foundation

| # | File | Action | Complexity | Risk |
|---|------|--------|-----------|------|
| 64 | `MCP/MCPClient.swift` | Wrap `mcp-swift-sdk`. stdio + HTTP/SSE transports. Connect, list tools, call tool, disconnect. 3s timeout. MCP Queue (`.utility`). | **High** | Medium |
| 65 | `MCP/MCPServerManager.swift` | Start/stop local servers (via Process). Heartbeat health check. Auto-reconnect. Config at `~/.macring/mcp-servers.json`. | **High** | Medium |
| 66 | `MCP/MCPCredentialManager.swift` | Per-server Keychain storage. Store GitHub PATs, Slack tokens. Masked display. CRUD. | Medium | **High** |
| 67 | `Resources/mcp_server_defaults.json` | Default configs for GitHub, Slack, Notion, Linear, filesystem, Docker. | Low | Low |

> **Risk on MCPCredentialManager:** Credential security is critical. Keychain only. No logging of tokens. Security review before launch.

### Week 14: MCP Discovery & Ring Integration

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 68 | `MCP/MCPRegistry.swift` | Query smithery.ai registry. Cache in `mcp_tools` (7-day TTL). Match servers to app categories. <500ms. Offline: cached data. | Medium |
| 69 | `MCP/MCPToolRunner.swift` | Execute MCP tool calls. Connect via MCPClient, call tool, handle errors (unavailable, not found, param invalid, timeout). Show result notification. | Medium |
| 70 | `MCP/MCPActionAdapter.swift` | Bridge RingAction (`.mcpToolCall`, `.mcpWorkflow`) → MCPToolRunner. Parameter templating (e.g., current branch). | Medium |
| 71 | `Core/Execution/MCPActionRunner.swift` | Full impl. Integrate with ActionExecutor. Show progress indicator for long-running calls. | Medium |
| 72 | `UI/Configurator/MCPToolBrowser.swift` | Browse MCP tools in configurator. Search/filter. Drag to slot. Server status indicator. "Install" button. | Medium |

### Week 15: MCP Workflows & Auto-Discovery

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 73 | `MCP/MCPWorkflowRunner.swift` | Chain MCP tool calls. Sequential execution with error handling. Pass outputs between steps. Per-step progress. | **High** |
| 74 | `Core/Context/ContextEngine.swift` (extend) | On app switch: also query MCPRegistry for relevant servers. Merge MCP tools into profile. Cache per bundle ID. | Medium |
| 75 | `UI/Settings/MCPSettingsView.swift` | List servers with status. Add/remove. Credential management. Enable/disable MCP. Server logs viewer. | Medium |
| 76 | `UI/Onboarding/MCPSetupView.swift` | Onboarding: discover MCP servers, connect popular ones, explain MCP, optional "Skip". | Medium |

**Phase 5 Tests:**

| Test File | Coverage |
|-----------|----------|
| `MCPClientTests.swift` | Connection, tool listing, tool call, disconnect, timeout, retry (mock server) |
| `MCPServerManagerTests.swift` | Start/stop, health check, auto-reconnect |
| `MCPRegistryTests.swift` | Registry query, caching, relevance matching, offline fallback |
| `MCPToolRunnerTests.swift` | Tool execution, error scenarios, parameter validation |
| `MCPCredentialManagerTests.swift` | Store/retrieve/delete tokens, per-server isolation |
| `MCPIntegrationTests.swift` | End-to-end: press ring slot → MCP tool executes → result shown (mock MCP server) |

**Phase 5 Deliverable:** MCP tools executable from ring. Auto-discovery. Credential management. MCP workflows. GitHub, Slack, Notion confirmed.

---

## Phase 6: Semantic Analysis (Week 16)

**Goal:** On-device behavior analysis. Workflow pattern discovery.

| # | File | Action | Complexity | Risk |
|---|------|--------|-----------|------|
| 77 | `Semantic/NLEmbeddingEngine.swift` | NaturalLanguage.framework NLEmbedding. Generate 512-dim vectors for action sequence strings. Handle embedding unavailability gracefully. | Medium | Medium |
| 78 | `Semantic/SequenceExtractor.swift` | Group raw interactions into sequences (30-second window). Filter noise. Output BehaviorSequence. Background Semantic Queue. | Medium | Low |
| 79 | `Semantic/VectorStore.swift` | Store embedding vectors as SQLite BLOBs. CRUD. Batch insert. 90-day auto-purge. | Low | Low |
| 80 | `Storage/VectorDatabase.swift` | Query layer: retrieve vectors by bundleId, time range, cluster membership. Batch fetch for clustering. | Low | Low |
| 81 | `Semantic/CosineSimilarity.swift` | Accelerate.framework (vDSP). Vectorized cosine similarity. Batch similarity for 100+ vectors. | Medium | Low |
| 82 | `Semantic/BehaviorClusterer.swift` | k-NN clustering (k=5) on embeddings. Cluster stability tracking. Target silhouette score >0.6. Runs every 6h or on demand. | **High** | Medium |
| 83 | `Semantic/PatternInterpreter.swift` | Send cluster representatives to Claude Haiku → human-readable workflow name + description. Aggregated patterns only (never raw events). Offline: skip interpretation. | Medium | Low |
| 84 | `UI/Settings/SemanticInsightsView.swift` | Dashboard: discovered workflow patterns, frequency, constituent actions, confidence score, "Create One-Click Action", data deletion controls. | Medium | Low |

> **Risk on NLEmbeddingEngine:** If embedding quality is poor (silhouette <0.4), fall back to frequency-only analysis. No hard dependency on semantic features.

**Phase 6 Tests:**

| Test File | Coverage |
|-----------|----------|
| `NLEmbeddingEngineTests.swift` | Vector generation for known inputs, dimension validation, fallback |
| `BehaviorClustererTests.swift` | Cluster formation, stability, k-NN correctness, silhouette score |
| `CosineSimilarityTests.swift` | Math correctness, edge cases (zero vectors, identical vectors) |
| `SemanticAnalysisTests.swift` | End-to-end: raw events → sequences → embeddings → clusters → patterns |

**Phase 6 Deliverable:** On-device semantic analysis. Workflow patterns discovered and named. Privacy preserved (only aggregated patterns sent to Haiku).

---

## Phase 7: Polish & Launch (Weeks 17–18)

**Goal:** Onboarding, performance, code signing, distribution.

### Week 17: Onboarding, Testing, Performance

| # | File | Action | Complexity |
|---|------|--------|-----------|
| 85 | `UI/Onboarding/OnboardingFlow.swift` | 7-step flow: Welcome → Accessibility → Mouse Setup → Auto-Detection (<3s) → AI Setup (optional) → MCP Setup (optional) → Tutorial | Medium |
| 86 | `UI/Onboarding/WelcomeView.swift` | Brand animation, "works with any mouse", Get Started | Low |
| 87 | `UI/Onboarding/AccessibilitySetupView.swift` | Step-by-step Accessibility permission guide. Deep link. Real-time status check. Block progression until granted. | Medium |
| 88 | `UI/Onboarding/MouseSetupView.swift` | "Press your trigger button" prompt → MouseButtonRecorder → confirm | Low |
| 89 | `UI/Onboarding/TutorialView.swift` | Interactive tutorial: hold trigger, select slot, execute action | Medium |
| 90 | Performance Profiling | Instruments: verify ring <50ms P99, 60fps, <35MB idle / <55MB active, <0.1% CPU idle, embedding <200ms, clustering <500ms | **High** |
| 91 | Accessibility Audit | VoiceOver, keyboard navigation for all UI, high contrast, reduced motion | Medium |
| 92 | Privacy Audit | No window titles/paths/content in API calls. TTL enforcement. Keychain for all secrets. Data deletion complete. Automated test. | Medium |

### Week 18: Distribution

| # | Action | Complexity |
|---|--------|-----------|
| 93 | Code signing + notarization (Apple Developer cert) | Medium |
| 94 | Branded DMG with drag-to-Applications | Low |
| 95 | Sparkle 2.x auto-update (appcast XML, EdDSA signing) | Medium |
| 96 | Homebrew Cask formula + submission | Low |
| 97 | Landing page + README.md + privacy policy | Low |

**Phase 7 Tests:**

| Test File | Coverage |
|-----------|----------|
| `OnboardingUITests.swift` | Full onboarding flow, permission check, button recording, tutorial |
| `E2ETests.swift` | Complete user journey: launch → onboard → switch apps → ring adapts → configure → AI suggest |
| `PrivacyTests.swift` | No forbidden data in API prompts, TTL enforcement, data deletion |
| `PerformanceTests.swift` | Ring latency, memory, CPU benchmarks |

**Phase 7 Deliverable:** MacRing v1.0 shipped — code signed, notarized, DMG + Homebrew cask, auto-update functional.

---

## Dependency Graph

```
Phase 1 (Foundation)
  ├── EventTapManager ──→ MouseButtonRecorder
  ├── Database ──→ ProfileManager ──→ BuiltInProfiles
  ├── RingAction ──→ ActionExecutor ──→ KeyboardSimulator, SystemActionRunner
  ├── RingProfile ──→ RingView ──→ RingWindow
  └── RingViewModel (RingProfile + EventTapManager + ActionExecutor)

Phase 2 (Context) ── depends on Phase 1
  ├── AppDetector ──→ ContextEngine ──→ ProfileManager
  └── FullscreenDetector ──→ ContextEngine

Phase 3 (Configurator) ── depends on Phase 1, 2
  └── ProfileManager ──→ ConfiguratorWindow ──→ ActionToolbox + RingPreview + SlotEditor

Phase 4 (AI) ── depends on Phase 1, 2, 3
  ├── AIService ──→ AIPromptBuilder + AIResponseParser + AICache
  ├── BehaviorTracker ──→ SuggestionManager ──→ AIService
  ├── KeyboardMonitor ──→ BehaviorTracker
  ├── AutoProfileGenerator ──→ AIService + ProfileManager
  ├── NLConfigEngine ──→ AIService + ProfileManager
  └── WorkflowBuilder ──→ AIService + WorkflowRunner

Phase 5 (MCP) ── depends on Phase 1, 2, 3 (AI optional but enhances)
  ├── MCPClient ──→ MCPServerManager
  ├── MCPRegistry ──→ ContextEngine (extension)
  ├── MCPToolRunner ──→ MCPClient ──→ MCPActionAdapter ──→ ActionExecutor
  └── MCPCredentialManager ──→ KeychainManager

Phase 6 (Semantic) ── depends on Phase 4
  ├── SequenceExtractor ──→ BehaviorTracker (raw data)
  ├── NLEmbeddingEngine ──→ VectorStore ──→ VectorDatabase
  ├── BehaviorClusterer ──→ CosineSimilarity + VectorStore
  └── PatternInterpreter ──→ BehaviorClusterer + AIService

Phase 7 (Polish) ── depends on ALL phases
```

---

## Risk Register

| Risk | Severity | Phase | Mitigation |
|------|----------|-------|------------|
| CGEventTap permission UX confusion | High | 1 | Step-by-step onboarding, deep links, real-time status check |
| CGEventTap conflict with BetterTouchTool/Options+ | Medium | 1 | Auto-detect conflicting software on launch. Migration guide. |
| macOS update breaks CGEventTap | High | All | macOS beta channel. Community issue tracker. Quick-patch via Sparkle. |
| NSPanel z-ordering/focus issues | Medium | 1 | Extensive testing: Spaces, fullscreen, multiple monitors |
| Ring appearance >50ms | Medium | 1 | Pre-render ring. Cache profile in memory. Instruments profiling from week 1. |
| AI generates poor/harmful profiles | Medium | 4 | Always show preview. Confidence scores. Undo. Never auto-apply without consent. |
| AI cost exceeds user expectations | Medium | 4 | Real-time cost tracking. Monthly budget cap. "AI is optional" messaging. |
| Claude API downtime | Medium | 4 | Exponential backoff. Aggressive caching. Full offline fallback. |
| MCP server crashes/instability | Medium | 5 | Heartbeat. Auto-reconnect. Graceful degradation (slot shows "unavailable"). |
| **MCP credential leakage** | **Critical** | 5 | **Keychain-only. Per-server isolation. Never log tokens. Security review.** |
| NLEmbedding quality insufficient | Medium | 6 | Fallback to frequency-only if silhouette <0.4. Semantic features are optional. |
| **Privacy violation (data leak to API)** | **Critical** | All | **Automated privacy tests in CI. PromptBuilder blocks forbidden fields explicitly.** |
| Scope creep | Medium | All | Strict phase gates. Cut P2 features if schedule slips. |

---

## Complexity Summary

| Phase | Weeks | New Files | Complexity |
|-------|-------|-----------|-----------|
| 1: Foundation | 1–3 | ~26 | High |
| 2: Context Awareness | 4–5 | ~9 | Medium |
| 3: Configurator Studio | 6–8 | ~13 | Medium-High |
| 4: AI Integration | 9–12 | ~15 | High |
| 5: MCP Integration | 13–15 | ~13 | High |
| 6: Semantic Analysis | 16 | ~8 | Medium-High |
| 7: Polish & Launch | 17–18 | ~8 | Medium |
| **Total** | **18** | **~92 files** | |

**Test files:** ~39 test files targeting 80%+ coverage

---

## Success Criteria Checklist

- [ ] Ring appears at cursor in <50ms (P99) on trigger hold
- [ ] Ring renders at 60fps (no dropped frames)
- [ ] Works with Logitech, Razer, Keychron, SteelSeries, generic mice
- [ ] 100% context detection rate for top 50 apps
- [ ] 50+ built-in profile presets shipped
- [ ] Core ring works fully offline (no API key required)
- [ ] AI suggestion acceptance rate >80% in user testing
- [ ] MCP tool execution confirmed (GitHub, Slack, Notion)
- [ ] Privacy: no window titles / file paths / document content ever sent to Claude API
- [ ] Memory: <35MB idle, <55MB ring open
- [ ] CPU: <0.1% idle
- [ ] 80%+ test coverage
- [ ] Onboarding completion >80% in user testing
- [ ] Code signed, notarized, DMG + Homebrew cask published
- [ ] Sparkle auto-update functional

---

**WAITING FOR CONFIRMATION:** Proceed with this implementation plan? (yes / modify / skip to specific phase)
