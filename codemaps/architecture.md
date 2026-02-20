# MacRing Architecture Codemap

> **Last Updated:** 2026-02-21
> **Phase:** Foundation (Phase 1 ✅ Complete)
> **Platform:** macOS 14+

---

## Implementation Status

| Layer | Status | Files |
|-------|--------|-------|
| App | Planned | .gitkeep only |
| UI | ✅ **Complete** | RingGeometry, RingView, RingWindow, MenuBarIntegration |
| Profile | ✅ **Complete** | RingAction, RingSlot, RingProfile |
| Input | ✅ **Complete** | EventTapManager |
| Context | ✅ **Complete** | AppDetector |
| Execution | ✅ **Complete** | ActionExecutor |
| AI | Planned | .gitkeep only |
| MCP | Planned | .gitkeep only |
| Semantic | Planned | .gitkeep only |
| Storage | Planned | .gitkeep only |

**Progress:** Phase 1 Foundation complete. Ready for Phase 2 (Context Awareness).

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ RingWindow │  │ RingView   │  │ MenuBar    │            │
│  │ (NSPanel)  │  │ (SwiftUI)  │  │ Integration│            │
│  │  ✅        │  │   ✅       │  │    ✅      │            │
│  └────────────┘  └────────────┘  └────────────┘            │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                      CORE LOGIC LAYER                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ RingProfile│  │ RingSlot   │  │ RingAction │            │
│  │   ✅       │  │    ✅      │  │  13 types  │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│                                                              │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │RingGeometry│  │AppDetector │  │Action      │            │
│  │    ✅      │  │    ✅      │  │Executor ✅ │            │
│  └────────────┘  └────────────┘  └────────────┘            │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                       INPUT LAYER                            │
│  ┌──────────────────────────────────────────────┐           │
│  │     EventTapManager (CGEventTap) ✅          │           │
│  │     Universal mouse capture (any brand)      │           │
│  └──────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

---

## Module Structure

```
Sources/MacRingCore/
├── Profile/                    ✅ COMPLETE
│   ├── RingAction.swift        (13 action types, 283 lines)
│   ├── RingSlot.swift          (Slot model, 85 lines)
│   └── RingProfile.swift       (Profile model, 178 lines)
│
├── Input/                      ✅ COMPLETE
│   └── EventTapManager.swift   (CGEventTap, 196 lines)
│
├── Context/                    ✅ COMPLETE
│   └── AppDetector.swift       (App detection, 331 lines)
│
├── Execution/                  ✅ COMPLETE
│   └── ActionExecutor.swift    (Execute actions, 315 lines)
│
└── UI/                         ✅ COMPLETE
    ├── RingGeometry.swift      (Math for layout, 145 lines)
    ├── RingView/
    │   └── RingView.swift      (SwiftUI view, 174 lines)
    ├── RingWindow.swift        (NSPanel, 147 lines)
    └── MenuBarIntegration.swift (Menu bar, 143 lines)
```

---

## Data Flow

```
1. EventTapManager detects mouse button hold
   ↓
2. AppDetector identifies current app (bundle ID)
   ↓
3. ProfileManager loads profile for app (planned)
   ↓
4. RingWindow appears at cursor position
   ↓
5. User selects slot (mouse movement)
   ↓
6. ActionExecutor executes selected action
```

---

## Thread Architecture

| Thread | QoS | Responsibility | Status |
|--------|-----|----------------|--------|
| Main | `.userInteractive` | SwiftUI rendering, user interaction | ✅ |
| EventTap | `.userInteractive` | `CGEventTap` callback | ✅ |
| AI Queue | `.utility` | Claude API calls | Planned |
| MCP Queue | `.utility` | MCP tool execution | Planned |
| Tracker Queue | `.background` | DB writes, usage recording | Planned |
| Semantic Queue | `.background` | Embedding generation, clustering | Planned |

---

## Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Swift | 5.10+ |
| Platform | macOS | 14+ |
| UI Framework | SwiftUI | 5.0+ |
| Input Capture | CGEventTap | Quartz Framework |
| App Detection | NSWorkspace | -- |
| Build System | Swift Package Manager | 6.0 |
| Test Framework | swift-testing | (Observation-based) |

---

## Action Types (13)

| # | Type | Data Structure | Status | Phase |
|---|------|----------------|--------|-------|
| 1 | `keyboardShortcut` | `KeyCode + [KeyModifier]` | ✅ Executable | 1 |
| 2 | `launchApplication` | `bundleIdentifier: String` | ✅ Executable | 1 |
| 3 | `openURL` | `String` | ✅ Executable | 1 |
| 4 | `systemAction` | `SystemAction` enum | ✅ Executable | 1 |
| 5 | `shellScript` | `String` | ⏳ Stub | 2 |
| 6 | `appleScript` | `String` | ⏳ Stub | 2 |
| 7 | `shortcutsApp` | `String` | ⏳ Stub | 3 |
| 8 | `textSnippet` | `String` | ⏳ Stub | 3 |
| 9 | `openFile` | `String` | ⏳ Stub | 3 |
| 10 | `workflow` | `[RingAction]` | ✅ Executable | 4 |
| 11 | `subRing` | `RingProfile` | Planned | Future |
| 12 | `mcpToolCall` | `MCPToolAction` struct | ⏳ Stub | 5 |
| 13 | `mcpWorkflow` | `MCPWorkflowAction` struct | ⏳ Stub | 5 |

---

## Development Phases (18 weeks)

| Phase | Weeks | Status | Deliverable |
|-------|-------|--------|-------------|
| 1 Foundation | 1-3 | ✅ **Complete** | Ring, mouse capture, menu bar |
| 2 Context | 4-5 | Next | App-switching profiles, 10+ presets |
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

## Related Codemaps

- [profile.md](profile.md) -- Profile system data models
- [ui.md](ui.md) -- UI components and geometry
- [core-layer.md](core-layer.md) -- Business logic modules
