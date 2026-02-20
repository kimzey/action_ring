# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**MacRing** is a native macOS application that turns any multi-button mouse into a context-aware radial command ring. When a designated mouse button is held, a radial "Action Ring" appears at the cursor and shows shortcuts that automatically adapt to the focused app.

**Status:** Pre-development. Only `MacRing_PRD_v2.md` exists. Consult it as the single source of truth for all architectural decisions, feature specs, and implementation guidance.

---

## Build & Development Commands

> Commands below assume Xcode + Swift Package Manager once the project is scaffolded.

```bash
# Build
xcodebuild -scheme MacRing -configuration Debug build

# Test
xcodebuild test -scheme MacRing -destination 'platform=macOS'

# Single test class
xcodebuild test -scheme MacRing -only-testing MacRingTests/ProfileManagerTests

# Lint
swiftlint lint --config .swiftlint.yml

# Auto-fix lint
swiftlint --fix
```

**Distribution** is via DMG + Homebrew Cask (not App Store). Requires Apple Developer code signing and notarization.

---

## Architecture

### Layer Structure

```
MacRing/
├── App/          - Entry point (MacRingApp.swift, AppDelegate.swift)
├── Core/
│   ├── Input/    - CGEventTap mouse capture (brand-agnostic)
│   ├── Context/  - App detection & profile switching
│   ├── Profile/  - Ring profiles, slots, 13 action types
│   └── Execution/- Action execution (keyboard, scripts, MCP)
├── AI/           - Claude API integration, suggestions, behavior tracking
├── MCP/          - Model Context Protocol client & tool execution
├── Semantic/     - On-device NLEmbedding, vector store, k-NN clustering
├── UI/           - SwiftUI ring, configurator, menu bar, onboarding
└── Storage/      - GRDB.swift (SQLite), Keychain, vector DB
```

### Three-Tier Intelligence (Core Architecture)

MacRing's AI operates in a continuous cycle:

1. **TIER 1 — Discovery** (`<500ms`): On app switch, load profile from DB, query MCP registry, AI generates 6–8 actions if no profile exists.
2. **TIER 2 — Observation** (passive): `BehaviorTracker` records ring interactions + keyboard shortcuts. Raw events purged after 24h (configurable). Aggregated stats kept 90 days.
3. **TIER 3 — Adaptation** (every 6h): On-device `NLEmbedding` generates vectors for action sequences → cosine similarity k-NN clustering → Claude Haiku interprets clusters → generates suggestions with confidence scores → user approves → profile updates permanently.

### Profile Lookup Chain

```
1. Exact Bundle ID → user profile OR built-in preset
2. MCP Discovery   → query registry for app-relevant servers
3. App Category    → category fallback (e.g., "IDE", "Browser")
4. Default Profile → universal fallback
```

### Action Types (13 total)

| Local (11) | MCP (2) |
|------------|---------|
| Keyboard Shortcut, Launch App, Open URL, System Action, Shell Script, AppleScript, Shortcuts.app, Text Snippet, Open File/Folder, Workflow/Macro (multi-step), Sub-Ring | MCP Tool Call, MCP Workflow |

---

## Technology Stack

| Concern | Technology |
|---------|-----------|
| Language | Swift 5.10+ |
| UI | SwiftUI 5.0+ (macOS 14+ required) |
| Mouse capture | `CGEventTap` (Quartz) — works with ALL mice brands |
| App detection | `NSWorkspace` + Accessibility API |
| Database | SQLite via `GRDB.swift 6.x` (WAL mode) |
| Vector store | SQLite BLOB (on-device embeddings) |
| Embeddings | `Core ML NLEmbedding` (`NaturalLanguage.framework`) |
| Math | `Accelerate.framework` (vectorized cosine similarity) |
| AI | Claude API (user supplies own key) |
| MCP | `mcp-swift-sdk` |
| Secrets | `Security.framework` Keychain, per-server isolation |
| Auto-update | Sparkle 2.x |

### AI Model Selection

| Task | Model |
|------|-------|
| Smart suggestions, shortcut discovery, MCP tool selection, pattern interpretation | `claude-haiku-4-5-20251001` |
| Auto profile generation, NL config, workflow builder | `claude-sonnet-4-5-20250929` |

---

## Key Data Models

```swift
struct RingProfile: Codable, Identifiable {
    let id: UUID
    var bundleId: String?
    var slots: [RingSlot]
    var slotCount: Int        // 4, 6, or 8
    var mcpServers: [String]  // associated MCP server IDs
    var source: ProfileSource // .builtin | .user | .ai | .community | .mcp
}

enum RingAction: Codable {
    // 11 local cases + 2 MCP:
    case mcpToolCall(MCPToolAction)
    case mcpWorkflow(MCPWorkflowAction)
}

struct BehaviorSequence: Codable {
    let actions: [ActionEvent]
    let bundleId: String
    let embedding: [Float]?   // NLEmbedding vector
    let clusterId: Int?
}
```

---

## Database Tables

| Table | Retention |
|-------|-----------|
| `profiles`, `triggers`, `mcp_servers`, `mcp_credentials` | Permanent |
| `usage_records`, `behavior_sequences`, `vector_store`, `behavior_clusters` | 90 days |
| `ai_suggestions` | 30 days |
| `ai_cache`, `mcp_tools` | 7 days |
| `raw_interactions` | 24h–30d (user-configurable) |
| `shortcut_presets` | App updates |

---

## Privacy Constraints (Non-Negotiable)

**Never send to Claude API:** window titles, file names/paths, document content, typed text, raw UI events, screen/clipboard content.

**Safe to send:** app bundle IDs, shortcut key combos, usage frequency counts, ring configuration, aggregated behavior patterns, MCP tool names.

---

## Ring Geometry

- Outer diameter: 280px (M), 220px (S), 340px (L)
- Dead zone radius: 35px (center = cancel)
- Slot count: 4, 6, or 8 (default 8)
- Slot selection: `selectedSlot = floor((atan2(dy,dx) + 2π) % (2π) / slotAngle)`
- Render target: ≤16ms (60fps), appearance target: <50ms

---

## Thread Architecture

| Thread | QoS | Responsibility |
|--------|-----|---------------|
| Main | `.userInteractive` | SwiftUI, user interaction |
| EventTap | `.userInteractive` | `CGEventTap` callback |
| AI Queue | `.utility` | Claude API calls |
| MCP Queue | `.utility` | MCP tool execution |
| Tracker Queue | `.background` | DB writes, behavior tracking |
| Semantic Queue | `.background` | Embeddings, clustering |

---

## Development Phases (18 weeks)

| Phase | Weeks | Deliverable |
|-------|-------|-------------|
| Foundation | 1–3 | Ring, CGEventTap, menu bar |
| Context Awareness | 4–5 | App-switching profiles, 10 presets → **MVP** |
| Configurator Studio | 6–8 | Drag-and-drop visual editor |
| AI Integration | 9–12 | Smart suggestions, auto-profile gen, NL config |
| MCP Integration | 13–15 | MCP client, discovery, tool execution, workflows |
| Semantic Analysis | 16 | On-device embeddings, clustering, pattern interpretation |
| Polish & Launch | 17–18 | Onboarding, code signing, DMG, Sparkle |

---

## Testing Requirements

| Category | Focus |
|----------|-------|
| MCP Integration | Server connection, tool execution, timeouts, retry |
| Universal Mouse | Test ≥5 brands (Logitech, Razer, Keychron, SteelSeries, generic) |
| Privacy | Verify no window titles leave device, TTL enforcement |
| Semantic Analysis | Embedding quality, cluster stability (silhouette > 0.6) |
| Performance | Ring latency P99 < 50ms, context switch < 500ms |

---

## Known Risks

- `CGEventTap` can conflict with BetterTouchTool and Logitech Options+: detect on launch and guide user to disable conflicting bindings.
- MCP server credentials must be isolated per-server in Keychain — never in plaintext or shared storage.
- `NLEmbedding` quality fallback: if on-device embedding quality is poor, fall back to frequency-only analysis (no Haiku needed).
- macOS updates can break `CGEventTap` — maintain beta test channel.
