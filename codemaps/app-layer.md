<!-- Updated: 2026-02-20 -->
# MacRing -- App Layer Codemap (UI + Entry Points)

> Status: **Phase 1 (Foundation)** -- RingGeometry scaffold only, all UI views planned

---

## Actual File Status

| File | Status | Notes |
|------|--------|-------|
| `Sources/MacRingCore/UI/RingGeometry.swift` | Scaffold | fatalError stubs, interface defined |
| `Sources/MacRingCore/App/.gitkeep` | Planned | MacRingApp.swift, AppDelegate.swift |
| `Tests/MacRingCoreTests/RingGeometryTests.swift` | Complete | 30 tests, Swift Testing framework |

All other UI files (RingWindow, Configurator, MenuBar, Onboarding, Settings) are planned but not yet created.

---

## Planned Directory Structure

```
Sources/MacRingCore/
  App/
    MacRingApp.swift            -- SwiftUI App entry, service init
    AppDelegate.swift           -- Accessibility request, EventTap, NSWorkspace
  UI/
    RingGeometry.swift          -- EXISTS (scaffold with fatalError stubs)
    Ring/
      RingWindow.swift          -- NSPanel (non-activating, floating, transparent)
      RingView.swift            -- Radial ring (glassmorphism, spring anim)
      RingViewModel.swift       -- State: isVisible, selectedSlot, cursor pos
      SlotView.swift            -- Single slot: icon, label, highlight, scale
    Configurator/
      ConfiguratorWindow.swift  -- NSWindow, split-pane layout
      ActionToolbox.swift       -- Sidebar: draggable action tiles by category
      RingPreview.swift         -- Interactive ring, drop targets
      SlotEditor.swift          -- Detail: label, icon picker, action params
      ProfileListView.swift     -- CRUD profiles, source badge
      DragDropManager.swift     -- Drag state, slot reorder, UTType
      KeyRecorderView.swift     -- Record key combo, conflict check
      MCPToolBrowser.swift      -- Browse MCP tools, install, drag to slot
    MenuBar/
      MenuBarView.swift         -- MenuBarExtra: profile, app, toggle, quit
      StatusBarController.swift -- NSStatusItem lifecycle
    Onboarding/
      OnboardingFlow.swift      -- 7-step flow controller
      WelcomeView.swift         -- Brand animation, "any mouse"
      AccessibilitySetupView.swift -- Permission guide, deep link, status
      MouseSetupView.swift      -- "Press trigger button" recorder
      MCPSetupView.swift        -- Discover + connect MCP servers
      TutorialView.swift        -- Interactive: hold, select, execute
    Settings/
      SettingsWindow.swift      -- Tabs: General, Appearance, Trigger, AI, MCP, Privacy
      GeneralSettingsView.swift -- Launch at login, updates, retention
      AppearanceSettingsView.swift -- Ring size, slot count, theme, preview
      TriggerSettingsView.swift -- Trigger display, record, fallback
      AISettingsView.swift      -- API key, usage chart, budget, toggle
      MCPSettingsView.swift     -- Server list, credentials, logs
      NLConfigView.swift        -- "Ask MacRing..." text field, history
      SemanticInsightsView.swift -- Patterns, clusters, "Create Action"
```

---

## Window Architecture

| Window | Type | Behavior |
|--------|------|----------|
| Ring | `NSPanel` | Non-activating, floating, transparent bg, cursor-positioned |
| Configurator | `NSWindow` | Standard window, split-pane, resizable |
| Settings | `NSWindow` | macOS Settings pattern with tabs |
| Onboarding | `NSWindow` | Modal on first launch, step-by-step |
| Menu Bar | `MenuBarExtra` | SwiftUI popover from status item |

---

## Ring Geometry (Scaffold Exists)

| Property | Small | Medium (default) | Large |
|----------|-------|-------------------|-------|
| Outer diameter | 220px | 280px | 340px |
| Dead zone radius | 35px | 35px | 35px |
| Slot count | 4, 6, or 8 | 4, 6, or 8 | 4, 6, or 8 |

**Slot selection math:**
```
selectedSlot = floor((atan2(dy, dx) + 2pi) % 2pi / slotAngle)
dead zone    = sqrt(dx^2 + dy^2) <= 35px --> cancel (returns nil)
```

**RingGeometry public interface** (all stubs, fatalError):
- `outerRadius` -- half diameter
- `slotAngularWidth` -- 2pi / slotCount
- `selectedSlot(for: CGPoint) -> Int?` -- nil if dead zone
- `slotAngle(for: Int) -> CGFloat` -- radians
- `slotCenter(for: Int) -> CGPoint` -- at mid-radius
- `isInRingArea(point: CGPoint) -> Bool` -- between dead zone and outer radius

**RingSize enum** (stub): `.small` (220), `.medium` (280), `.large` (340)

---

## Ring Animations (Planned)

| Animation | Spec |
|-----------|------|
| Appear | Spring (response: 0.3, damping: 0.7) |
| Dismiss | easeOut (duration: 0.1) |
| Slot highlight | Scale + opacity on hover/select |
| Glassmorphism | `.ultraThinMaterial` background |

---

## UI Component Hierarchy (Planned)

```
MacRingApp
  +-- AppDelegate (Accessibility, EventTap, NSWorkspace)
  +-- MenuBarView (MenuBarExtra)
  |     +-- Current profile display
  |     +-- Active app indicator
  |     +-- Enable/disable toggle
  |     +-- Settings link, Quit
  +-- RingWindow (NSPanel, shown on trigger)
  |     +-- RingView
  |           +-- SlotView x4/6/8 (radial layout, uses RingGeometry)
  |           +-- Dead zone center (cancel)
  +-- ConfiguratorWindow (user-initiated)
  |     +-- ActionToolbox (left pane)
  |     +-- RingPreview (right pane)
  |     +-- SlotEditor (detail panel)
  |     +-- ProfileListView (sidebar)
  +-- SettingsWindow (user-initiated)
  +-- OnboardingFlow (first launch only)
```

---

## Navigation Patterns

- **Ring**: Triggered by mouse button hold, dismissed on release or dead zone
- **Menu Bar**: Click status item -> popover, links to Settings/Configurator
- **Settings**: Standard macOS tabbed window, opened from menu bar
- **Configurator**: Separate window, opened from menu bar or Settings
- **Onboarding**: Modal flow, shown once on first launch, non-skippable steps 1-3
