# ActionRing — Documentation

> Turn **any** multi-button mouse into a context-aware radial command hub on macOS.
> Hold a mouse button → a glassmorphic **Action Ring** appears at the cursor → drag toward a slot → release to fire. The ring's contents switch automatically based on the focused app.

- **Version:** 1.0.0
- **Platform:** macOS 14+ · Swift 6 toolchain · SwiftUI + AppKit · Swift Package Manager
- **Dependencies:** none (no third-party packages, no network calls)

---

## Table of contents

1. [What it is](#1-what-it-is)
2. [Features](#2-features)
3. [Install & first run](#3-install--first-run)
4. [How it works](#4-how-it-works)
5. [Privacy](#5-privacy)
6. [Architecture](#6-architecture)
7. [Action types](#7-action-types)
8. [Built-in profiles](#8-built-in-profiles)
9. [Configuration](#9-configuration)
10. [Development](#10-development)
11. [Troubleshooting & FAQ](#11-troubleshooting--faq)
12. [Roadmap](#12-roadmap)

---

## 1. What it is

ActionRing is a native macOS menu-bar app. Press and hold a configured mouse button and a radial menu — the **Action Ring** — fades in at your cursor. Drag in the direction of the action you want; that wedge highlights. Release to fire it. Release in the dead center to cancel.

The ring is **context-aware**: it shows different actions depending on which app is focused (Command Palette in VS Code, the toolset in Figma, transport controls in Spotify, …). It works with **any** mouse — Logitech, Razer, Keychron, SteelSeries, Apple Magic Mouse, or a generic one — because it reads the normalized macOS HID stream via `CGEventTap` rather than any vendor driver.

## 2. Features

- **Universal mouse trigger** — capture any mouse button (side buttons recommended) via `CGEventTap`.
- **Context-aware profiles** — the ring auto-switches per focused app, with category and default fallbacks.
- **Glassmorphic radial UI** — translucent wedge segments, a glass center hub showing the app + selected action, spring animations, 4/6/8 slots, three sizes.
- **11 action types** — keyboard shortcuts, app launch, URLs, system actions, shell/AppleScript, Apple Shortcuts, text snippets, file/folder open, and multi-step workflows.
- **Fullscreen-aware** — the ring is suppressed over borderless-fullscreen games.
- **Button recording** — set the trigger by literally pressing the button on your mouse.
- **Preview mode** — see the ring respond to your cursor without granting any permission.
- **Privacy-first** — zero network calls; reads only the focused app's bundle id + name.
- **Local JSON config** — profiles & settings live in plain files you can edit.

## 3. Install & first run

> **Just want to install it?** If someone handed you an `ActionRing-<version>.dmg`,
> follow the dedicated end‑user guide instead — **[INSTALL.md](INSTALL.md)** (or the
> styled **[install.html](install.html)**). The section below is the build‑from‑source path.

### Build the app

```bash
cd action_ring
make bundle            # → ./ActionRing.app  (release build, ad-hoc signed)
open ActionRing.app
```

ActionRing is a **menu-bar app** (no Dock icon). Look for the ⊕ icon in the right side of the menu bar.

### See it immediately (no permission needed)

Click the menu-bar icon → **Preview Ring**, or launch with the flag:

```bash
open ActionRing.app --args --preview
```

The ring appears centered and follows your cursor for a few seconds so you can confirm the look and tracking before wiring anything up.

### Grant Accessibility (so the trigger works)

The trigger button needs an event tap, which requires Accessibility permission:

1. **System Settings → Privacy & Security → Accessibility**
2. Enable **ActionRing**
3. If the ring doesn't arm immediately, quit and reopen ActionRing.

This is the **only** permission ActionRing requests.

### Use it — two natural gestures

There is one ring (it changes per app). You open and pick from it in whichever way feels natural:

**Hold (press-drag-release):**
```
hold the trigger button   →  the ring appears at your cursor and stays up
drag toward a slot        →  that wedge highlights (35px dead zone in the middle)
release                   →  the highlighted action fires  (release in center = cancel)
```

**Click (tap-move-tap):**
```
quick-click the trigger   →  the ring opens and stays (sticky)
move the cursor           →  the wedge under it highlights
click again               →  fires it  (click in the center = cancel; auto-closes after 6s)
```

Default trigger is **Button 4** (the side/thumb button) so your left/right clicks keep working. Change it in **Settings** (menu-bar icon → Settings…), including a **Record from mouse** button that captures whatever button you press.

## 4. How it works

```
trigger DOWN ─► (unless a fullscreen game is frontmost)
                 show ring at cursor, populated from the active app's profile
   move ───────► a 120 Hz cursor poll highlights the wedge under the cursor
trigger UP ───► hold-release fires the highlight; a quick tap leaves the ring
                "sticky" so a second click fires it. Center = cancel.
```

| Stage      | Component                       | Notes                                                                                                                                                                                                                                                                           |
| ---------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trigger    | `EventTapManager`               | A `CGEventTap` captures the button down/up and **suppresses** the press so a side-button "Back" doesn't also fire.                                                                                                                                                              |
| Tracking   | `RingController` poll           | Suppressing the mouse-down stops the OS from emitting drag events (and from updating `pressedMouseButtons`) for that button, so the highlight is driven by a 120 Hz poll of `NSEvent.mouseLocation`, and the release is taken from the actual mouse-up tap event. Robust regardless of the rest of the event stream. |
| Context    | `ContextEngine` + `AppDetector` | Watches `NSWorkspace` activations (debounced) and resolves the profile through `user(bundleId) → builtin(bundleId) → user(category) → builtin(category) → default`.                                                                                                             |
| Fullscreen | `FullscreenDetector`            | Uses `CGWindowList` window bounds only (no titles, no Screen-Recording permission) to suppress the ring over fullscreen games.                                                                                                                                                  |
| Execute    | `ActionExecutor`                | Posts correct US-ANSI virtual keycodes, real HID media keys for volume/brightness/transport, Unicode text, app launches, scripts, etc.                                                                                                                                          |

### Geometry

| Property           | Value                                                                                                |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| Outer diameter     | Small 220 / **Medium 280** / Large 340 px                                                            |
| Dead zone (cancel) | 30 / **35** / 40 px                                                                                  |
| Slots              | 4 / 6 / **8**                                                                                        |
| Slot pick          | `floor(((atan2(dy,dx)+2π) mod 2π) / (2π/n))`, half-slot shifted so slot 0 is centered on the +x axis |
| Appear             | spring(response 0.26, damping 0.7)                                                                   |

## 5. Privacy

ActionRing makes **zero network calls** in v1. It reads the focused app's **bundle identifier and localized name only** — never window titles, document paths, keyboard input, or any window/document contents. Profiles and settings are plain JSON under `~/Library/Application Support/ActionRing/`.

`CGWindowList` (used for fullscreen detection) is queried for window **bounds and owner PID only**, which doesn't require Screen-Recording permission.

## 6. Architecture

Two targets in one Swift package:

| Target           | Kind       | Responsibility                                                  |
| ---------------- | ---------- | --------------------------------------------------------------- |
| `ActionRingCore` | library    | All logic + SwiftUI views; fully unit-testable                  |
| `ActionRing`     | executable | AppKit menu-bar (`.accessory`) shell, settings, permission flow |
| `ARCheck`        | executable | Dependency-free invariant checker for Xcode-less environments   |

```
RingController (orchestrator, @MainActor)
 ├─ EventTapManager      CGEventTap → trigger down/up, suppression, button recording
 ├─ 120 Hz poll Timer    cursor tracking + HID release detection
 ├─ ContextEngine        app-switch → resolve RingProfile (debounced)
 │   └─ AppDetector      frontmost bundle id + category mapping
 ├─ FullscreenDetector   suppress ring over fullscreen games (CGWindowList bounds)
 ├─ ProfileStore         JSON persistence + lookup chain + settings
 │   └─ BuiltInProfiles  shipped presets + per-category fallbacks
 ├─ RingWindow/RingView  click-through NSPanel + glassmorphic SwiftUI wedge menu
 │   └─ RingViewModel    @Observable state (slots, selection, profile name)
 └─ ActionExecutor       perform the selected action
     └─ ScriptRunner     sandboxed shell/AppleScript with timeout
```

### Source layout

```
Sources/ActionRingCore/
  Geometry/RingGeometry.swift      slot math (pure, tested)
  Profile/RingAction.swift         action model + Codable
  Profile/RingSlot.swift           slot model
  Profile/RingProfile.swift        profile model + default
  Profile/BuiltInProfiles.swift    21 app presets + 7 category fallbacks
  Profile/ProfileStore.swift       persistence + resolution chain
  Input/EventTapManager.swift      CGEventTap wrapper
  Context/AppDetector.swift        frontmost app + categories
  Context/ContextEngine.swift      app-switch → profile
  Context/FullscreenDetector.swift fullscreen suppression
  Execution/ActionExecutor.swift   perform actions
  Execution/KeyCodeMap.swift       US-ANSI virtual keycodes
  Execution/ScriptRunner.swift     shell/AppleScript runner
  Settings/AppSettings.swift       user settings
  Storage/JSONStore.swift          JSON file store
  Controller/RingController.swift  the orchestrator
  UI/RingViewModel.swift           observable ring state
  UI/RingView.swift                glassmorphic wedge menu
  UI/RingWindow.swift              click-through NSPanel
Sources/ActionRing/                menu-bar app shell
Sources/ARCheck/                   invariant checker
Tests/ActionRingCoreTests/         XCTest suite
```

## 7. Action types

11 local actions are executed; 2 MCP cases are reserved for a future release and return `.notImplemented`.

| Action                                 | What it does                                                                     |
| -------------------------------------- | -------------------------------------------------------------------------------- |
| `keyboardShortcut(KeyCode, modifiers)` | Synthesize a key combo (correct US-ANSI keycodes)                                |
| `launchApplication(bundleIdentifier)`  | Launch or focus an app                                                           |
| `openURL(String)`                      | Open a URL in the default handler                                                |
| `systemAction(SystemAction)`           | Volume, brightness, media transport, screenshot, lock, Mission Control, sleep, … |
| `shellScript(String)`                  | Run a shell script (timeout + denylist)                                          |
| `appleScript(String)`                  | Run AppleScript                                                                  |
| `shortcutsApp(String)`                 | Run an Apple Shortcuts workflow by name                                          |
| `textSnippet(String)`                  | Type Unicode text                                                                |
| `openFile(String)`                     | Open a file or folder                                                            |
| `workflow([RingAction])`               | Run a sequence of actions                                                        |
| `mcpToolCall` / `mcpWorkflow`          | _Reserved (future)_                                                              |

**System actions:** `lockScreen`, `screenshot`, `screenshotArea`, `volumeUp/Down`, `mute`, `brightnessUp/Down`, `missionControl`, `showDesktop`, `launchpad`, `mediaPlayPause`, `mediaNext`, `mediaPrevious`, `sleep`.

## 8. Built-in profiles

21 app profiles ship out of the box; opening an app switches the ring automatically. When no app profile matches, a per-category fallback is used, then a universal default.

| Category      | Apps                                  |
| ------------- | ------------------------------------- |
| IDE           | VS Code, Cursor, Xcode, IntelliJ IDEA |
| Browser       | Safari, Chrome, Arc                   |
| Design        | Figma, Photoshop                      |
| Terminal      | Terminal, iTerm2, Warp                |
| Communication | Slack, Discord, Zoom, Mail            |
| Productivity  | Notion, Obsidian, Linear              |
| Media         | Spotify                               |
| System        | Finder                                |

Fallbacks: **IDE, Browser, Terminal, Design, Productivity, Communication, Media**, plus the universal **Default** (Copy / Paste / Cut / Undo / Redo / Save / Select All / Screenshot).

## 9. Configuration

### Settings (menu-bar icon → Settings…)

| Setting                       | Description                                                   | Default  |
| ----------------------------- | ------------------------------------------------------------- | -------- |
| Trigger button                | The mouse button that opens the ring (or "Record from mouse") | Button 4 |
| Default ring size             | Small / Medium / Large                                        | Medium   |
| Show slot labels              | Text under each icon                                          | on       |
| Hide ring in fullscreen games | Suppress over fullscreen apps                                 | on       |
| Script timeout                | Seconds before a shell/AppleScript action is killed           | 10       |

### Custom profiles

Built-in profiles cover common apps. Custom profiles live in:

```
~/Library/Application Support/ActionRing/profiles.json
```

Each profile maps a `bundleId` (or a category) to up to 8 slots; each slot has a `position` (0–7), `label`, SF Symbol `icon`, `color`, and a `RingAction`. Settings live in `settings.json` and the universal fallback in `default.json` in the same folder. (A visual drag-and-drop editor is on the roadmap.)

## 10. Development

```bash
make build      # compile all targets (debug)
make check      # run the invariant checker (no Xcode needed)  → 29 checks
make test       # XCTest suite (requires a full Xcode toolchain)
make run        # run from .build (prefer `make bundle` for Accessibility persistence)
make bundle     # assemble + ad-hoc sign ActionRing.app (release)
make install    # bundle + copy to /Applications
make clean
```

`ARCheck` exists because `XCTest`/`Testing` aren't available with Command Line Tools only; it runs the same core invariants and exits non-zero on failure, so it works anywhere Swift compiles.

## 11. Troubleshooting & FAQ

**The ring doesn't appear when I hold the button.**
Grant Accessibility (System Settings → Privacy & Security → Accessibility → ActionRing) and reopen the app. Confirm the trigger button in Settings matches a button your mouse actually has — use **Record from mouse**. Try **Preview Ring** first to confirm rendering works.

**The ring shows but doesn't react to dragging.**
This was a known issue in early builds and is fixed: tracking is now driven by a 120 Hz cursor poll. If you still see it, make sure you rebuilt (`make bundle`).

**The triggered ring looks faint / old, but "Preview Ring" looks great — and the trigger doesn't fire even though I enabled Accessibility.**
You're running an **old instance** (which still holds the grant and shows the old UI) while the freshly rebuilt app isn't trusted yet. Each ad-hoc `make bundle` changes the app's code hash, so macOS treats it as a new app and the old Accessibility grant no longer applies. Fix it cleanly:

```bash
killall ActionRing                                  # stop every old instance
make reset-perms                                    # clear stale grants (tccutil)
make install                                        # build → /Applications → open fresh
# then enable ActionRing in System Settings → Privacy & Security → Accessibility
# the menu-bar status should read "● Ready — trigger is live"
```

The menu-bar item shows the real state: **● Ready** (tap armed), **▲ Permission OK — click "Re-arm"** (granted but not yet armed — use the Re-arm item, or relaunch), or **○ Needs Accessibility**.

**Permission keeps resetting every time I rebuild.**
Ad-hoc signatures change each build. Create a stable self-signed identity once and `make bundle` will use it so the grant persists:

```bash
make cert        # creates the "ActionRing Dev" code-signing identity (one time)
make install     # now signed stably; grant once and it sticks across rebuilds
```

**My side button still triggers "Back/Forward" in the browser.**
ActionRing suppresses the trigger button's press, so it shouldn't. If another tool (Logitech Options+, etc.) also binds that button, disable its binding.

**Does it work on a trackpad / Magic Mouse?**
The trigger needs a distinct mouse button. Magic Mouse exposes left/right; a trackpad has no extra buttons, so set the trigger to a button you can actually press (or use a multi-button mouse).

**Is anything sent over the network?**
No. v1 makes zero network calls.

**Where is my data?**
`~/Library/Application Support/ActionRing/` (`profiles.json`, `default.json`, `settings.json`).

## 12. Roadmap

Deferred from v1 (clean seams left in the code): AI shortcut suggestions · MCP tool execution (the `.mcpToolCall` / `.mcpWorkflow` cases are reserved) · semantic usage clustering · natural-language config · visual configurator studio · profile import/export/share · nested sub-rings · iCloud sync.
