<!-- Updated: 2025-02-20 -->
# MacRing -- System Architecture Codemap

> Status: **Phase 1 (Foundation)** -- Profile and UI models implemented, testing infrastructure in place

---

## Implementation Status

| Layer | Status | Files |
|-------|--------|-------|
| App | Planned | .gitkeep only |
| UI | **Implemented** | `RingGeometry.swift` complete with 30 tests |
| Profile | **Implemented** | `RingAction.swift`, `RingSlot.swift`, `RingProfile.swift` with 80 tests |
| Input | Planned | .gitkeep only |
| Context | Planned | .gitkeep only |
| Execution | Planned | .gitkeep only |
| AI | Planned | .gitkeep only |
| MCP | Planned | .gitkeep only |
| Semantic | Planned | .gitkeep only |
| Storage | Planned | .gitkeep only |

**Progress:** Core data models complete. Ready for Input/Context implementation.

---

## Layer Architecture

```
+-----------------------------------------------------------------------+
|  APP                     MacRingApp.swift | AppDelegate.swift       |  <- planned
+-----------------------------------------------------------------------+
|  UI                      RingGeometry.swift (COMPLETE)                  |
|                          RingWindow | Configurator | MenuBar          |  <- planned
+-----------------------------------------------------------------------+
|  PROFILE                 RingProfile.swift (COMPLETE)                   |
|                          RingSlot.swift (COMPLETE)                      |
|                          RingAction.swift (COMPLETE)                    |
+-----------------------------------------------------------------------+
|  INPUT                   EventTapManager | KeyboardMonitor            |  <- planned
|  CONTEXT                 ContextEngine | AppDetector | Fullscreen     |  <- planned
|  EXECUTION               ActionExecutor | ScriptRunner | MCPAction     |  <- planned
+-----------------------------------------------------------------------+
|  AI                      AIService | BehaviorTracker | Suggestions    |  <- planned
|  MCP                     MCPClient | Registry | ToolRunner             |  <- planned
|  SEMANTIC                NLEmbedding | Clustering | PatternInterpreter  |  <- planned
|  STORAGE                 GRDB Database | Keychain | VectorStore        |  <- planned
+-----------------------------------------------------------------------+
                       | HTTPS / stdio / SSE
              Claude API  |  MCP Servers  |  smithery.ai
```

---

## Three-Tier Intelligence Flow

```
TIER 1: DISCOVERY (<500ms)          TIER 2: OBSERVATION (passive)       TIER 3: ADAPTATION (6h cycle)
+---------------------------+       +---------------------------+       +---------------------------+
| App switch detected       |       | BehaviorTracker records   |       | NLEmbedding vectorizes    |
| Load profile from DB      |  -->  | ring interactions         |  -->  | action sequences          |
| Query MCP registry        |       | KeyboardMonitor tracks    |       | k-NN clustering (k=5)    |
| AI generates 6-8 actions  |       | modifier+key combos       |       | Haiku interprets clusters |
| Ring populates            |       | Raw: 24h TTL, Agg: 90d   |       | User approves suggestions |
+---------------------------+       +---------------------------+       +---------------------------+
```

---

## Thread Architecture

| Thread | QoS | Responsibility | Status |
|--------|-----|----------------|--------|
| Main | `.userInteractive` | SwiftUI rendering, user interaction | Planned |
| EventTap | `.userInteractive` | `CGEventTap` callback | Planned |
| AI Queue | `.utility` | Claude API calls | Planned |
| MCP Queue | `.utility` | MCP tool execution | Planned |
| Tracker Queue | `.background` | DB writes, usage recording | Planned |
| Semantic Queue | `.background` | Embedding generation, clustering | Planned |

---

## Profile Lookup Chain

```
1. Exact Bundle ID --> user profile OR built-in preset
       | (miss)
2. MCP Discovery   --> query registry for app-relevant servers
       | (miss)
3. App Category    --> category fallback (IDE, Browser, Design...)
       | (miss)
4. Default Profile --> universal fallback (always exists)
```

---

## External Integrations

| Service | Protocol | Purpose | Auth | Status |
|---------|----------|---------|------|--------|
| Claude API (Haiku) | HTTPS | Suggestions, shortcut discovery, MCP selection | User API key | Planned |
| Claude API (Sonnet) | HTTPS | Auto profile gen, NL config, workflow builder | User API key | Planned |
| smithery.ai | HTTPS | MCP server registry (6,480+ servers) | None (public) | Planned |
| MCP Servers (local) | stdio | GitHub, Filesystem, Docker, Postgres, Puppeteer | Per-server Keychain | Planned |
| MCP Servers (remote) | HTTP/SSE | Slack, Notion, Linear, Brave Search | Per-server Keychain | Planned |
| Sparkle 2.x | HTTPS | Auto-update (appcast XML, EdDSA) | None | Planned |

---

## Action Types (13)

| # | Type | Data Structure | Status | Phase |
|---|------|----------------|--------|-------|
| 1 | `keyboardShortcut` | `KeyCode + [KeyModifier]` | **Implemented** | 1 |
| 2 | `launchApplication` | `bundleIdentifier: String` | **Implemented** | 1 |
| 3 | `openURL` | `String` | **Implemented** | 1 |
| 4 | `systemAction` | `SystemAction` enum | **Implemented** | 1 |
| 5 | `shellScript` | `String` | **Implemented** | 2 |
| 6 | `appleScript` | `String` | **Implemented** | 2 |
| 7 | `shortcutsApp` | `String` | **Implemented** | 3 |
| 8 | `textSnippet` | `String` | **Implemented** | 3 |
| 9 | `openFile` | `String` | **Implemented** | 3 |
| 10 | `workflow` | `[RingAction]` | **Implemented** | 4 |
| 11 | `mcpToolCall` | `MCPToolAction` struct | **Implemented** | 5 |
| 12 | `mcpWorkflow` | `MCPWorkflowAction` struct | **Implemented** | 5 |

---

## Technology Stack

| Concern | Technology | Version |
|---------|-----------|---------|
| Language | Swift | 5.10+ (toolchain 6.0, language mode v5) |
| UI | SwiftUI | 5.0+ (macOS 14+) |
| Testing | Swift Testing | (Observation-based) |
| Mouse capture | CGEventTap | Quartz Framework |
| App detection | NSWorkspace + Accessibility API | -- |
| Database | GRDB.swift | 6.x (planned) |
| Vector store | SQLite BLOB | (planned) |
| Embeddings | NaturalLanguage.framework | NLEmbedding (planned) |
| Math | Accelerate.framework | vDSP (planned) |
| AI | Claude API | (user key) |
| MCP | mcp-swift-sdk | (planned) |
| Secrets | Security.framework | Keychain (planned) |
| Auto-update | Sparkle | 2.x (planned) |
| Distribution | DMG + Homebrew Cask | (not App Store) |

---

## Package Structure

```
G:\code\action_ring\
├── Package.swift                   -- SPM manifest, macOS 14+ target
├── Sources/
│   └── MacRingCore/
│       ├── Profile/
│       │   ├── RingAction.swift    -- COMPLETE (283 lines)
│       │   ├── RingSlot.swift      -- COMPLETE (85 lines)
│       │   └── RingProfile.swift   -- COMPLETE (178 lines)
│       └── UI/
│           └── RingGeometry.swift  -- COMPLETE (145 lines)
└── Tests/
    └── MacRingCoreTests/
        ├── Profile/
        │   ├── RingActionTests.swift    -- 28 tests
        │   ├── RingSlotTests.swift      -- 23 tests
        │   └── RingProfileTests.swift   -- 29 tests
        └── RingGeometryTests.swift      -- 30 tests
```

---

## Development Phases (18 weeks)

| Phase | Weeks | Status | Deliverable |
|-------|-------|--------|-------------|
| 1 Foundation | 1-3 | **In progress** | Data models + RingGeometry |
| 2 Context | 4-5 | Planned | App-switching profiles, 10+ presets |
| 3 Configurator | 6-8 | Planned | Visual drag-and-drop editor |
| 4 AI | 9-12 | Planned | Smart suggestions, auto-profile, NL config |
| 5 MCP | 13-15 | Planned | MCP client, discovery, tool execution |
| 6 Semantic | 16 | Planned | On-device embeddings, clustering |
| 7 Polish | 17-18 | Planned | Onboarding, code signing, DMG, Sparkle |

---

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Ring appearance | <50ms P99 | SwiftUI render |
| Ring frame rate | 60fps (16ms) | Core Animation |
| Slot selection | <5ms | Geometry math |
| Context switch detection | <10ms | NSWorkspace notification |
| Local action execution | <20ms | CGEvent simulation |
| MCP tool execution | <3s | Timeout enforced |
| Memory (idle / active) | <35MB / <55MB | Leaks prevention |
| CPU (idle) | <0.1% | EventTap efficiency |

---

## Data Flow (Planned)

### Ring Trigger -> Action Execution
```
EventTapManager (otherMouseDown)
  -> RingViewModel.show(at: cursorPosition)
  -> ProfileManager.activeProfile
  -> RingView renders slots
  -> User moves to slot (RingGeometry.selectedSlot math)
  -> EventTapManager (otherMouseUp)
  -> ActionExecutor.execute(slot.action)
```

### App Switch -> Profile Update
```
AppDetector (NSWorkspace notification)
  -> ContextEngine.handleAppSwitch(bundleId)
  -> ProfileManager.lookup(bundleId)     -- 4-step chain
  -> MCPRegistry.relevantServers(bundleId)
  -> RingViewModel.updateProfile(newProfile)
```

---

## Related Codemaps

- [profile.md](profile.md) -- Profile system data models
- [ui.md](ui.md) -- UI components and geometry
- [data.md](data.md) -- Data models and storage schema
- [core-layer.md](core-layer.md) -- Business logic modules
- [app-layer.md](app-layer.md) -- UI and entry points
