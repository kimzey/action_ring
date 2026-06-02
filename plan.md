# ActionRing — Implementation Plan (v1.0)

> **What it is:** A native macOS app that turns **any multi-button mouse** into a context-aware radial command hub. Hold a mouse button → a glassmorphism **Action Ring** appears at the cursor → drag toward a slot → release to fire. The ring auto-switches its contents based on the focused app.
>
> **Platform:** macOS 14+ · Swift 6 toolchain (language mode 5) · SwiftUI + AppKit · SPM
> **Status:** Foundation rebuilt + wired into a runnable app. Build green via `swift build`.

---

## Scope decisions (what changed from the old MacRing PRD)

The original PRD was an 18-week, 7-phase vision (Claude AI, MCP 6000+ tools, vector clustering, NL config, drag-drop studio). That is not a shippable v1. This plan **cuts the speculative AI/MCP/ML surface** and focuses on a **ring that actually works end-to-end**, then leaves clean seams to add the rest later.

| Area | Decision |
|------|----------|
| Universal mouse trigger (CGEventTap) | ✅ **Core v1** — press-and-hold, drag-select, release-execute, dead-zone cancel |
| Glassmorphism ring overlay (NSPanel, 60fps, <50ms) | ✅ **Core v1** |
| Context-aware profile auto-switching (bundle ID → category → default) | ✅ **Core v1** |
| Action execution (11 local action types) | ✅ **Core v1** |
| Fullscreen detection (disable in games) | ✅ **Core v1** |
| Menu bar status item + settings + button-recording | ✅ **Core v1** |
| Built-in app profiles | ✅ **Core v1** — start with a curated set, grow over time |
| JSON profile persistence (Application Support) | ✅ **Core v1** (SQLite/GRDB was overkill) |
| Claude AI suggestions / NL config / auto-profile gen | ⏸ **Deferred** (needs API key + network; clean seam left in `Context`/`Profile`) |
| MCP tool execution (6000+ tools) | ⏸ **Deferred** (`RingAction` already has `.mcpToolCall`/`.mcpWorkflow` cases reserved → return `.notImplemented`) |
| Semantic behavior clustering / vector embeddings | ⏸ **Deferred** |
| Visual drag-and-drop configurator studio | ⏸ **Deferred to v1.1** (v1 ships a basic settings UI + JSON editing) |

---

## Architecture (v1)

```
┌──────────────────────────────────────────────────────────────┐
│ ActionRing (executable, .accessory app)                        │
│   AppDelegate · MenuBarController · SettingsWindow · Permissions│
└───────────────┬────────────────────────────────────────────────┘
                │ owns
┌───────────────▼────────────────────────────────────────────────┐
│ RingController  — the orchestrator                              │
│   EventTap → (hold) show RingWindow → track drag → (release)    │
│   resolve selected slot → ActionExecutor.execute                │
│   ContextEngine pushes the active RingProfile on app switch     │
│   FullscreenDetector gates the ring off in fullscreen games     │
└──┬──────────┬───────────┬──────────┬───────────┬────────────────┘
   │          │           │          │           │
┌──▼───┐  ┌───▼────┐  ┌───▼─────┐ ┌──▼──────┐ ┌──▼─────────┐
│Input │  │  UI    │  │ Context │ │ Profile │ │ Execution  │
│EventTap  │RingView│  │AppDetect│ │Store    │ │ActionExec  │
│Manager│  │RingWin │  │ContextEng│ │BuiltIns │ │ScriptRunner│
└──────┘  └────────┘  │Fullscreen│ │RingProf │ └────────────┘
                      └─────────┘ └─────────┘
```

**Module layout**
- `ActionRingCore` (library, fully unit-testable) — all logic + SwiftUI views (guarded by `#if canImport`).
- `ActionRing` (executable) — the AppKit shell: `NSApplication(.accessory)`, status item, settings, permission flow.

---

## Action types (v1 — 11 local + 2 reserved MCP)

Local (executed): `keyboardShortcut` · `launchApplication` · `openURL` · `systemAction` · `shellScript` · `appleScript` · `shortcutsApp` · `textSnippet` · `openFile` · `workflow`
Reserved (return `.notImplemented`): `mcpToolCall` · `mcpWorkflow`

## Ring geometry
| Property | Value |
|----------|-------|
| Outer diameter | S 220 / **M 280 (default)** / L 340 px |
| Dead zone | 30 / **35** / 40 px (center = cancel) |
| Slots | 4 / 6 / **8 (default)** |
| Slot pick | `floor(((atan2(dy,dx)+2π) mod 2π) / (2π/n))` |
| Appear | spring(response 0.3, damping 0.7), target < 50ms |
| Dismiss | easeOut 0.1s |

---

## Build phases (this session)

1. **Foundation rebuild** — rename → `ActionRing`; `Package.swift` (lib + exe); restore & **fix all build-breaking bugs** in models/geometry/executor/context.
2. **Orchestrator** — `RingController` wiring event-tap → ring → execution; `ProfileStore` (JSON) implementing the lookup chain; `AppSettings`.
3. **App shell** — `@main` AppKit accessory app, `NSStatusItem` menu, settings window, accessibility-permission flow, button-recording.
4. **Built-in profiles** — curated set across IDE / browser / design / terminal / productivity / comms + universal default.
5. **Green build + tests** — `swift build` clean; unit tests for geometry/models/profile-lookup/executor-routing/script-safety.
6. **Review + docs** — adversarial review (concurrency, AppKit correctness, script safety); `README` with build/run/permission steps.

## P0 acceptance (v1)
- [ ] `swift build` is green; `swift run ActionRing` launches a menu-bar app.
- [ ] Holding the configured mouse button shows the ring at the cursor within perceived-instant latency.
- [ ] Dragging past the dead zone highlights the angular slot; releasing fires its action; releasing in the dead zone cancels.
- [ ] Works on a generic/any mouse via CGEventTap (button number configurable + recordable).
- [ ] Ring contents change when the focused app changes (built-in profile or category fallback or default).
- [ ] Ring is suppressed while a fullscreen game is frontmost.
- [ ] No window titles / file paths / typed text leave the machine (v1 makes **zero** network calls).

## Deferred → Future roadmap
AI suggestions · MCP execution · semantic clustering · NL config · drag-drop studio · profile import/export/share · sub-rings · iCloud sync.
