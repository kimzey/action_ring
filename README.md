# ActionRing

Turn **any** multi-button mouse into a context-aware radial command hub on macOS.

Hold your chosen mouse button → a glassmorphic **Action Ring** appears at the cursor → drag toward a slot → release to fire. The ring's contents switch automatically based on the focused app (VS Code, Figma, your browser, the terminal…). Release in the center to cancel.

> Works with Logitech, Razer, Keychron, SteelSeries, Apple Magic Mouse, or any generic mouse — it taps the normalized macOS HID stream via `CGEventTap`, so it isn't locked to one vendor's driver.

---

https://youtu.be/F2fBqs8gRUM

## Quick start

```bash
# 1. Build a proper menu-bar .app (stable identity = Accessibility sticks across rebuilds)
make bundle           # → ./ActionRing.app
open ActionRing.app

# 2. See it work right away — no permission needed:
#    menu-bar icon → "Preview Ring", or:  open ActionRing.app --args --preview
#    The ring appears and follows your cursor so you can confirm the look + tracking.

# 3. Grant permission so the trigger button works:
#    System Settings → Privacy & Security → Accessibility → enable ActionRing
#    (event taps require this; it's the only permission ActionRing needs)

# 4. Hold the trigger button (default: side Button 4). The ring appears at your cursor.
#    Open the menu-bar icon → Settings… to change the trigger, ring size, etc.
```

## Installing it on someone else's Mac

If you just want to hand the app to a friend (no Swift toolchain on their end):

```bash
make dmg        # → ./dist/ActionRing-<version>.dmg
```

Send them that `.dmg` (and point them at **[docs/INSTALL.md](docs/INSTALL.md)** /
[docs/install.html](docs/install.html) for the full walkthrough). The short version — they:

1. **Drag** `ActionRing.app` onto the **Applications** folder in the dmg window.
2. **First launch only:** right-click (Control-click) ActionRing in Applications
   → **Open** → **Open**. macOS warns because the app isn't notarized yet; this
   one-time right-click is the supported way to run it. (Or strip the quarantine
   flag: `xattr -dr com.apple.quarantine /Applications/ActionRing.app`.)
3. **Grant Accessibility:** System Settings → Privacy & Security → Accessibility
   → enable ActionRing. (The only permission it needs — event taps require it.)

> Want a **warning-free** install (double-click just works, Homebrew, auto-update)?
> That needs an Apple Developer account ($99/yr) to **sign + notarize** the build.
> The current dmg is the free path and will always show the unidentified-developer
> prompt on first open.

Dev loop:

```bash
make build      # compile all targets
make check      # run the invariant checker (no Xcode needed)
make run        # run from .build (Accessibility identity is per-binary; prefer `make bundle`)
make test       # XCTest suite (requires a full Xcode toolchain)
make install    # build + copy ActionRing.app to /Applications
```

---

## How it works

```
trigger DOWN ─► (unless a fullscreen game is frontmost)
                 show ring at cursor, populated from the active app's profile
   drag ───────► highlight the angular slot under the cursor (35px dead zone = cancel)
trigger UP ───► fire the highlighted slot's action  ·  or cancel in the dead zone
```

- **Universal trigger** — `CGEventTap` captures the configured mouse button and _suppresses_ its press so a side-button "Back" doesn't also fire. You can **record** the button from your mouse in Settings.
- **Cursor tracking** — suppressing the mouse-down also stops the OS emitting drag events (and updating `pressedMouseButtons`) for that button, so the highlight is driven by a 120 Hz poll of `NSEvent.mouseLocation` and the release is taken from the actual mouse-up tap event.
- **Two gestures** — _hold_ the trigger then drag-and-release, or _quick-click_ to open a sticky ring and click again to fire. Center = cancel.
- **Context awareness** — `AppDetector` watches `NSWorkspace` activations; `ContextEngine` resolves a profile through `user(bundleId) → builtin(bundleId) → user(category) → builtin(category) → default`.
- **Fullscreen aware** — `FullscreenDetector` (CGWindowList bounds only — no titles, no screen-recording permission) suppresses the ring over borderless-fullscreen games.
- **Actions** — `ActionExecutor` performs keyboard shortcuts (correct US-ANSI virtual keycodes), app launches, URLs, system actions (volume/brightness/media via real HID media keys), shell/AppleScript, Shortcuts, Unicode text snippets, file opens, and multi-step workflows.

## Privacy

ActionRing makes **zero network calls** in v1. It reads the focused app's bundle id and name only — never window titles, file paths, document contents, or typed text. Profiles and settings are plain JSON under `~/Library/Application Support/ActionRing/`.

---

## Architecture

| Module                     | Responsibility                                                  |
| -------------------------- | --------------------------------------------------------------- |
| `ActionRingCore` (library) | All logic + SwiftUI views, fully unit-testable                  |
| `ActionRing` (executable)  | AppKit menu-bar (`.accessory`) shell, settings, permission flow |
| `ARCheck` (executable)     | Dependency-free invariant checker for Xcode-less environments   |

```
RingController (orchestrator)
 ├─ EventTapManager      CGEventTap → down/up/drag, suppression, button recording
 ├─ ContextEngine        app-switch → resolve RingProfile (debounced)
 │   └─ AppDetector      frontmost bundle id + category mapping
 ├─ FullscreenDetector   suppress ring over fullscreen games
 ├─ ProfileStore         JSON persistence + lookup chain + settings
 │   └─ BuiltInProfiles  shipped presets + per-category fallbacks
 ├─ RingWindow/RingView  click-through NSPanel + glassmorphic SwiftUI ring
 └─ ActionExecutor       perform the selected action (+ ScriptRunner)
```

## Configuring profiles

Open the menu-bar icon → **Settings… → Profiles** for a built-in editor:

- **Create / edit / delete** a profile per app (pick a running app or type a bundle id).
- Edit each slot — **label, SF Symbol icon, color, enabled**, and the **action**
  (keyboard shortcut, launch app, URL, system action, shell/AppleScript, Apple
  Shortcut, type text, open file).
- **Enable/disable** any profile (a disabled app falls back to its category /
  default ring), plus a master **Enable ActionRing** switch.
- **Preview** the ring while editing.

Built-in profiles act as templates: editing one transparently creates a user
override. Everything persists as plain JSON in
`~/Library/Application Support/ActionRing/` (`profiles.json`, `default.json`,
`settings.json`), which you can also hand-edit.

## Roadmap (deferred from v1)

AI shortcut suggestions · MCP tool execution · semantic usage clustering ·
natural-language config · drag-and-drop slot reordering · profile import/export ·
nested sub-rings · iCloud sync.

These were intentionally cut from v1 to ship a ring that _actually works
end-to-end_; `RingAction` already reserves `.mcpToolCall` / `.mcpWorkflow`
cases and the context layer leaves a clean seam for AI.

## Documentation

- **[docs/ActionRing.md](docs/ActionRing.md)** — full reference (Markdown).
- **[docs/index.html](docs/index.html)** — the same docs as a styled, offline single-page site (`open docs/index.html`).

## Requirements

macOS 14+, Swift 6 toolchain. No third-party dependencies.
