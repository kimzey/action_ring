# MacRing -- App Layer Codemap (UI + Entry Points)

> Generated: 2026-02-20 | Source: PRD v2.0.0 | Status: Pre-development (planning phase)

---

## Directory Structure

```
MacRing/
  App/
    MacRingApp.swift            -- SwiftUI App entry, service init
    AppDelegate.swift           -- Accessibility request, EventTap, NSWorkspace
  UI/
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

## Ring Geometry

| Property | Small | Medium (default) | Large |
|----------|-------|-------------------|-------|
| Outer diameter | 220px | 280px | 340px |
| Dead zone radius | 35px | 35px | 35px |
| Slot count | 4, 6, or 8 | 4, 6, or 8 | 4, 6, or 8 |

**Slot selection math:**
```
selectedSlot = floor((atan2(dy, dx) + 2pi) % 2pi / slotAngle)
dead zone    = sqrt(dx^2 + dy^2) < 35px --> cancel
```

---

## Ring Animations

| Animation | Spec |
|-----------|------|
| Appear | Spring (response: 0.3, damping: 0.7) |
| Dismiss | easeOut (duration: 0.1) |
| Slot highlight | Scale + opacity on hover/select |
| Glassmorphism | `.ultraThinMaterial` background |

---

## UI Component Hierarchy

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
  |           +-- SlotView x4/6/8 (radial layout)
  |           +-- Dead zone center (cancel)
  +-- ConfiguratorWindow (user-initiated)
  |     +-- ActionToolbox (left pane)
  |     +-- RingPreview (right pane)
  |     +-- SlotEditor (detail panel)
  |     +-- ProfileListView (sidebar)
  +-- SettingsWindow (user-initiated)
  |     +-- GeneralSettingsView
  |     +-- AppearanceSettingsView
  |     +-- TriggerSettingsView
  |     +-- AISettingsView
  |     +-- MCPSettingsView
  |     +-- NLConfigView
  |     +-- SemanticInsightsView
  +-- OnboardingFlow (first launch only)
        +-- WelcomeView
        +-- AccessibilitySetupView
        +-- MouseSetupView
        +-- MCPSetupView (optional)
        +-- TutorialView
```

---

## Key View Responsibilities

### Ring Module

| View | Purpose | Critical Path |
|------|---------|--------------|
| `RingWindow` | NSPanel lifecycle, cursor positioning | <50ms appear |
| `RingView` | Radial layout, glassmorphism, animations | 60fps render |
| `RingViewModel` | State machine: hidden/visible/selecting, slot math | <5ms selection |
| `SlotView` | Icon + label, color by action type, highlight state | -- |

### Configurator Module

| View | Purpose |
|------|---------|
| `ConfiguratorWindow` | Split-pane layout, window lifecycle |
| `ActionToolbox` | Browsable/searchable action palette, drag source |
| `RingPreview` | Production-geometry ring, drop targets, visual feedback |
| `SlotEditor` | Action-type-specific parameter editing, validation |
| `ProfileListView` | Create/duplicate/delete profiles, assign to apps |
| `MCPToolBrowser` | MCP server tools list, install, drag to slot |
| `KeyRecorderView` | Capture key combo, display "Cmd+Shift+F", validate |
| `DragDropManager` | UTType registration, reorder, trash area |

### Onboarding Module (7 steps)

| Step | View | Gate |
|------|------|------|
| 1 | WelcomeView | None |
| 2 | AccessibilitySetupView | Permission granted |
| 3 | MouseSetupView | Trigger button recorded |
| 4 | Auto-detection | <3s time-to-useful |
| 5 | AI Setup (optional) | API key or skip |
| 6 | MCP Setup (optional) | Connect or skip |
| 7 | TutorialView | Interactive demo complete |

---

## Navigation Patterns

- **Ring**: Triggered by mouse button hold, dismissed on release or dead zone
- **Menu Bar**: Click status item -> popover, links to Settings/Configurator
- **Settings**: Standard macOS tabbed window, opened from menu bar
- **Configurator**: Separate window, opened from menu bar or Settings
- **Onboarding**: Modal flow, shown once on first launch, non-skippable steps 1-3
