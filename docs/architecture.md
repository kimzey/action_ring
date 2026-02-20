# MacRing — System Architecture Reference

> Quick reference for developers. See `MacRing_PRD_v2.md` §8–10 for full detail.

---

## Three-Tier Intelligence (Core Concept)

```
┌──────────────────────────────────────────────────────────┐
│                   THE ADAPTIVE CYCLE                     │
│                                                          │
│  TIER 1: DISCOVERY (< 500ms)                             │
│  • App switch → load profile from DB                     │
│  • Query MCP registry for relevant servers               │
│  • AI (Haiku) suggests 6–8 actions if no profile exists  │
│  • Ring populates immediately                            │
│                      ↓                                   │
│  TIER 2: OBSERVATION (passive, continuous)               │
│  • BehaviorTracker records ring interactions             │
│  • KeyboardMonitor tracks modifier+key combos            │
│  • Raw events: configurable TTL (24h default, max 30d)   │
│  • Aggregated stats: 90-day retention                    │
│                      ↓                                   │
│  TIER 3: ADAPTATION (every 6h or on demand)              │
│  • NLEmbedding generates vectors for action sequences    │
│  • Cosine similarity k-NN clustering (k=5)               │
│  • Claude Haiku interprets clusters                      │
│  • Generates suggestions with confidence scores          │
│  • User approves → ring updates permanently              │
└──────────────────────────────────────────────────────────┘
```

---

## Layer Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  UI LAYER   RingWindow │ Configurator │ MenuBar │ Onboarding     │
│─────────────────────────────────────────────────────────────────│
│  CORE       ProfileManager │ ContextEngine │ ActionExecutor      │
│─────────────────────────────────────────────────────────────────│
│  AI         AIService │ SuggestionManager │ BehaviorTracker      │
│─────────────────────────────────────────────────────────────────│
│  MCP        MCPClient │ MCPRegistry │ MCPToolRunner              │
│─────────────────────────────────────────────────────────────────│
│  SEMANTIC   NLEmbeddingEngine │ BehaviorClusterer                │
│─────────────────────────────────────────────────────────────────│
│  INPUT      EventTapManager │ KeyboardMonitor │ AppDetector      │
│─────────────────────────────────────────────────────────────────│
│  STORAGE    SQLite(GRDB) │ Keychain │ VectorDB                   │
│─────────────────────────────────────────────────────────────────│
│                   │ HTTPS                                        │
│              Claude API  │  MCP Servers  │  smithery.ai          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Thread Architecture

| Thread | QoS | Responsibility |
|--------|-----|---------------|
| Main | `.userInteractive` | SwiftUI rendering, user interaction |
| EventTap | `.userInteractive` | `CGEventTap` callback — MUST be fast |
| AI Queue | `.utility` | Claude API calls |
| MCP Queue | `.utility` | MCP tool execution |
| Tracker Queue | `.background` | DB writes, usage recording |
| Semantic Queue | `.background` | Embedding generation, clustering |

---

## Profile Lookup Chain

```
1. Exact Bundle ID → user profile OR built-in preset
       ↓ (miss)
2. MCP Discovery  → query registry for app-relevant servers
       ↓ (miss)
3. App Category   → category fallback (IDE, Browser, Design…)
       ↓ (miss)
4. Default Profile → universal fallback (always exists)
```

---

## Ring Geometry

| Property | Value |
|----------|-------|
| Outer diameter | S=220px, M=280px (default), L=340px |
| Dead zone radius | 35px (center = cancel/dismiss) |
| Slot count | 4, 6, or 8 (default 8) |
| Slot selection | `floor((atan2(dy,dx) + 2π) % 2π / slotAngle)` |
| Appear latency | < 50ms P99 |
| Frame rate | 60fps |
| Appear animation | Spring (response: 0.3, damping: 0.7) |
| Dismiss animation | easeOut (duration: 0.1) |

---

## Action Types (13 total)

### Local Actions (11)
1. `keyboardShortcut` — Simulate key combo via CGEvent
2. `launchApplication` — NSWorkspace.open
3. `openURL` — NSWorkspace.open(URL)
4. `systemAction` — Lock, screenshot, volume, brightness, Mission Control
5. `shellScript` — Process (bash/zsh), 10s timeout
6. `appleScript` — NSAppleScript
7. `shortcutsApp` — Apple Shortcuts.app workflow
8. `textSnippet` — Paste text
9. `openFileFolder` — NSWorkspace.activateFileViewerSelecting
10. `workflow` — Multi-step sequence (WorkflowRunner)
11. `subRing` — Open nested ring (v1.1)

### MCP Actions (2)
12. `mcpToolCall(MCPToolAction)` — Execute single MCP tool
13. `mcpWorkflow(MCPWorkflowAction)` — Chain multiple MCP tools

---

## Universal Mouse Support

macOS `CGEventTap` normalizes all mice brands at the HID layer:
- `CGMouseButton` is a simple integer (0–31)
- Button 3 is button 3 on Logitech, Razer, or a generic $5 mouse
- No vendor-specific drivers needed

**Common mappings:**

| Button | All brands |
|--------|-----------|
| Left | 0 |
| Right | 1 |
| Middle (scroll click) | 2 |
| Side Back | 3 |
| Side Forward | 4 |
| Extra buttons | 5–31 |

**Edge cases:**
- Apple Magic Mouse (no side buttons) → keyboard trigger fallback (e.g., Caps Lock hold)
- Gaming mice DPI buttons → Button Recording Mode identifies them by integer
- Logitech Options+ conflict → detect on launch, guide user to disable specific button

---

## Database Schema Summary

| Table | Retention | Notes |
|-------|-----------|-------|
| `profiles` | Permanent | Ring configurations |
| `triggers` | Permanent | Button assignments |
| `mcp_servers` | Permanent | Installed MCP servers |
| `mcp_credentials` | Permanent | In Keychain, referenced here |
| `usage_records` | 90 days | Aggregated action usage |
| `behavior_sequences` | 90 days | Grouped action sequences |
| `vector_store` | 90 days | Embedding BLOBs |
| `behavior_clusters` | 90 days | k-NN cluster results |
| `ai_suggestions` | 30 days | Cached suggestions |
| `ai_cache` | 7 days | API response cache |
| `mcp_tools` | 7 days | Discovered tool cache |
| `raw_interactions` | 24h–30d | Configurable TTL |
| `shortcut_presets` | App updates | Bundled presets |

---

## Privacy Constraints (Non-Negotiable)

| ✅ Safe to send to Claude API | ❌ NEVER send |
|------------------------------|--------------|
| App bundle IDs | Window titles |
| Shortcut key combinations | File names / paths |
| Usage frequency counts | Document content |
| Ring configuration | Typed text / passwords |
| Aggregated behavior patterns | Raw UI events |
| MCP tool names | Screen / clipboard content |

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Ring appearance | < 50ms P99 |
| Ring frame rate | 60fps |
| Slot selection | < 5ms |
| Action execution (local) | < 20ms |
| MCP tool execution | < 3s (network dependent) |
| MCP discovery | < 500ms |
| Context switch detection | < 10ms |
| Embedding generation | < 200ms per sequence |
| Clustering (100 vectors) | < 500ms |
| Memory (idle) | < 35MB |
| Memory (ring open) | < 55MB |
| CPU (idle) | < 0.1% |
