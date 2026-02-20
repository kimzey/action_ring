# MacRing -- System Architecture Codemap

> Generated: 2026-02-20 | Source: PRD v2.0.0 | Status: Pre-development (planning phase)

---

## Layer Diagram

```
+---------------------------------------------------------------+
|  APP          MacRingApp.swift | AppDelegate.swift             |
+---------------------------------------------------------------+
|  UI           RingWindow | Configurator | MenuBar | Onboarding|
+---------------------------------------------------------------+
|  CORE         ProfileManager | ContextEngine | ActionExecutor  |
+---------------------------------------------------------------+
|  AI           AIService | SuggestionManager | BehaviorTracker  |
+---------------------------------------------------------------+
|  MCP          MCPClient | MCPRegistry | MCPToolRunner          |
+---------------------------------------------------------------+
|  SEMANTIC     NLEmbeddingEngine | BehaviorClusterer            |
+---------------------------------------------------------------+
|  INPUT        EventTapManager | KeyboardMonitor | AppDetector  |
+---------------------------------------------------------------+
|  STORAGE      SQLite (GRDB) | Keychain | VectorDB (BLOB)      |
+---------------------------------------------------------------+
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

| Thread | QoS | Responsibility | Latency Budget |
|--------|-----|----------------|---------------|
| Main | `.userInteractive` | SwiftUI rendering, user interaction | 16ms (60fps) |
| EventTap | `.userInteractive` | `CGEventTap` callback | <5ms |
| AI Queue | `.utility` | Claude API calls | Unbounded (network) |
| MCP Queue | `.utility` | MCP tool execution | <3s timeout |
| Tracker Queue | `.background` | DB writes, usage recording | Best-effort |
| Semantic Queue | `.background` | Embedding generation, clustering | <500ms |

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

| Service | Protocol | Purpose | Auth |
|---------|----------|---------|------|
| Claude API (Haiku) | HTTPS | Suggestions, shortcut discovery, MCP selection, pattern interpretation | User API key |
| Claude API (Sonnet) | HTTPS | Auto profile gen, NL config, workflow builder | User API key |
| smithery.ai | HTTPS | MCP server registry (6,480+ servers) | None (public) |
| MCP Servers (local) | stdio | GitHub, Filesystem, Docker, Postgres, Puppeteer | Per-server Keychain |
| MCP Servers (remote) | HTTP/SSE | Slack, Notion, Linear, Brave Search | Per-server Keychain |
| Sparkle 2.x | HTTPS | Auto-update (appcast XML, EdDSA) | None |

---

## Action Types (13)

| # | Type | Execution Method | Phase |
|---|------|-----------------|-------|
| 1 | `keyboardShortcut` | CGEvent keyDown/keyUp | 1 |
| 2 | `launchApplication` | NSWorkspace.open | 1 |
| 3 | `openURL` | NSWorkspace.open(URL) | 1 |
| 4 | `systemAction` | CGSession / NSWorkspace | 1 |
| 5 | `shellScript` | Process (bash/zsh), 10s timeout | 2 |
| 6 | `appleScript` | NSAppleScript | 2 |
| 7 | `shortcutsApp` | Shortcuts.app workflow | 3 |
| 8 | `textSnippet` | Paste text | 3 |
| 9 | `openFileFolder` | NSWorkspace.activateFileViewerSelecting | 3 |
| 10 | `workflow` | WorkflowRunner (multi-step) | 4 |
| 11 | `subRing` | Nested ring (v1.1) | 7 |
| 12 | `mcpToolCall` | MCPClient -> MCP server | 5 |
| 13 | `mcpWorkflow` | MCPWorkflowRunner (chained) | 5 |

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Ring appearance | <50ms P99 |
| Ring frame rate | 60fps (16ms) |
| Slot selection | <5ms |
| Local action execution | <20ms |
| Context switch detection | <10ms |
| MCP tool execution | <3s |
| MCP discovery | <500ms |
| Embedding generation | <200ms/sequence |
| Clustering (100 vectors) | <500ms |
| Memory (idle / active) | <35MB / <55MB |
| CPU (idle) | <0.1% |

---

## Technology Stack

| Concern | Technology |
|---------|-----------|
| Language | Swift 5.10+ |
| UI | SwiftUI 5.0+ (macOS 14+) |
| Mouse capture | CGEventTap (Quartz) -- all brands |
| App detection | NSWorkspace + Accessibility API |
| Database | GRDB.swift 6.x (SQLite, WAL mode) |
| Vector store | SQLite BLOB |
| Embeddings | NaturalLanguage.framework (NLEmbedding) |
| Math | Accelerate.framework (vDSP) |
| AI | Claude API (user-supplied key) |
| MCP | mcp-swift-sdk |
| Secrets | Security.framework Keychain |
| Auto-update | Sparkle 2.x |
| Distribution | DMG + Homebrew Cask (not App Store) |

---

## Development Phases (18 weeks)

| Phase | Weeks | Files | Deliverable |
|-------|-------|-------|-------------|
| 1 Foundation | 1-3 | ~26 | Ring + CGEventTap + menu bar |
| 2 Context | 4-5 | ~9 | App-switching profiles, 10+ presets --> **MVP** |
| 3 Configurator | 6-8 | ~13 | Visual drag-and-drop editor |
| 4 AI | 9-12 | ~15 | Smart suggestions, auto-profile, NL config |
| 5 MCP | 13-15 | ~13 | MCP client, discovery, tool execution |
| 6 Semantic | 16 | ~8 | On-device embeddings, clustering |
| 7 Polish | 17-18 | ~8 | Onboarding, code signing, DMG, Sparkle |
| **Total** | **18** | **~92** | **+ ~39 test files** |
