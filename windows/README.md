# ActionRing for Windows

Turn **any** multi-button mouse into a context-aware radial command hub on Windows — the Windows port of [ActionRing for macOS](../README.md).

Hold your chosen mouse button → a glass **Action Ring** appears at the cursor → drag toward a slot → release to fire. The ring's contents switch automatically based on the focused app (VS Code, your browser, Windows Terminal, Figma…). Release in the center to cancel.

```
trigger DOWN ─► (unless a fullscreen game is frontmost)
                 show ring at cursor, populated from the active app's profile
   drag ───────► highlight the angular slot under the cursor (dead zone = cancel)
trigger UP ───► fire the highlighted slot's action  ·  or cancel in the dead zone
quick-click ──► sticky ring (stays open) · click again to fire · auto-close 6s
```

## Quick start

```powershell
# requires Node.js 20+
cd windows
make install         # or: npm install
make run             # or: npm start   → tray app, hold Button 4 to open the ring

make preview         # or: npm run preview  → ring follows your cursor (no hook needed)
make test            # or: npm test         → unit tests
make dist            # or: npm run dist     → ActionRing-Setup-<version>.exe (NSIS)
make                 # list all targets
```

No `make`? Every target is a one-line `npm` command — run `make` (or open the
`Makefile`) to see them. No special permissions needed — Windows allows global
low-level mouse hooks out of the box (the mac version needs Accessibility; here
you just run it).

📖 **Full install + run + troubleshooting guide:** [`docs/INSTALL.md`](docs/INSTALL.md) — covers both the installer (`.exe`) path and running from source.

## How it's built

| Layer | Windows implementation | mac equivalent |
|---|---|---|
| Trigger capture | `WH_MOUSE_LL` low-level hook via [koffi](https://koffi.dev) FFI — **true suppression** (side-button "Back" won't also fire). Falls back to `uiohook-napi` (listen-only) if the hook fails. | `CGEventTap` |
| Cursor tracking | 120 Hz poll of `screen.getCursorScreenPoint()` (suppressed buttons emit no drag events — same reason as mac) | 120 Hz `NSEvent.mouseLocation` poll |
| Context | `GetForegroundWindow` → process exe name, 250 ms debounce | `NSWorkspace` notifications |
| Fullscreen gate | `SHQueryUserNotificationState` + borderless-fullscreen heuristic (±2 px) | `CGWindowList` bounds |
| Key injection | `SendInput` (VK + scancode, `KEYEVENTF_UNICODE` for text) | `CGEvent` |
| Overlay | transparent, click-through, non-activating `BrowserWindow` (SVG ring) | non-activating `NSPanel` + SwiftUI |
| Scripts | PowerShell with timeout + destructive-command denylist | `/bin/sh` + denylist |

## Config — shared schema with macOS

Profiles and settings live in `%APPDATA%\ActionRing\`:

- `profiles.json` — your profiles / built-in overrides
- `default.json` — the universal fallback ring
- `settings.json` — app settings

The JSON schema is **identical to the macOS app** (same field names, same `RingAction` encoding, sorted keys, ISO-seconds dates), so profiles are portable across machines. App identity uses the same `bundleId` field, holding the exe name lowercased (`code.exe`) instead of a mac bundle id. Keyboard modifiers map at execution time: `command` → **Ctrl**, `option` → **Alt**, `control` → **Ctrl** — a mac-authored profile still fires something sensible.

## Built-in profiles (21)

VS Code · Cursor · Visual Studio · IntelliJ IDEA · Edge · Chrome · Firefox · Arc · Figma · Photoshop · Windows Terminal · Warp · Slack · Discord · Zoom · Outlook · Notion · Obsidian · Linear · Explorer · Spotify — plus 7 category fallbacks (IDE / Browser / Terminal / Design / Productivity / Communication / Media) and a universal Default ring (Copy / Paste / Cut / Undo / Redo / Save / Select All / Screenshot).

Shortcuts use each app's real **Windows** bindings (e.g. Zoom mute = `Alt+A`, browser Back = `Alt+←`, Explorer rename = `F2`).

## Settings

Tray icon → **Settings…**

- **General** — master enable, trigger button (pick or *record from mouse*), ring size, labels, fullscreen suppression, script timeout, hook status.
- **Profiles** — create/edit/delete per-app rings, slot editor (label / icon / color / action), app picker (running apps), enable/disable per profile, preview.

Action types: keyboard shortcut · launch app · open URL · system action (volume/media/lock/snip/Task View/…) · PowerShell script · type text · open file/folder · multi-step workflow (JSON). `appleScript` / `shortcutsApp` actions from mac profiles are preserved but report "macOS-only" when fired.

## Privacy

Zero network calls. Reads the focused app's **exe name only** — never window titles, file paths, document contents, or typed text (same promise as the mac build).

## Security note — trust your profiles

A profile can fire keystrokes, launch apps, open files, and run PowerShell — so **`profiles.json` is as trusted as the code itself**. The app hardens the obvious edges: `openURL` is restricted to `http`/`https`/`mailto`, `openFile` refuses executable types (`.exe/.bat/.ps1/.lnk/…`), `launchApplication` rejects UNC/remote paths, all profiles coming from the editor are schema-validated before they're persisted or executed, and the PowerShell denylist blocks the worst literals. **But the script denylist is a coarse guard, not a security boundary** (case/spacing/encoding bypass it trivially). If you import a profile pack from someone else, **read its shell scripts and launch targets first** — treat it like running their script.

## Architecture

```
src/main/
  index.js            app bootstrap · tray · settings window · IPC
  ringController.js   gesture state machine (hold / sticky / dead-zone cancel)
  contextEngine.js    foreground watcher → profile resolution (debounced)
  profileStore.js     JSON persistence + lookup chain
  executor.js         action execution (SendInput, PowerShell, system actions)
  scriptRunner.js     time-boxed PowerShell/cmd runner
  overlay.js          pre-created click-through ring window
  win32/              koffi FFI: hook · input · foreground · fullscreen
src/shared/           pure logic, unit-tested: geometry · models · resolution ·
                      keymap · builtinProfiles  (schema-parity with mac)
src/renderer/
  ring/               the ring overlay (SVG + CSS, no framework)
  settings/           settings + profile editor UI
tests/                node:test suite
```

## Dev on macOS

The repo's mac machine can develop this port: `npm test` and `npm run preview` are fully cross-platform (the ring window, geometry, profiles all run; only the win32 layer is Windows-gated). `npx electron . --capture /tmp/ring.png` snapshots the rendered ring for visual checks.

## Known limitations (v1)

- Electron's transparent windows can't blur what's behind them → the ring uses translucent dark glass instead of true backdrop blur.
- Icons are emoji/text glyphs (SF Symbol names are stored verbatim for schema parity; rendering maps them).
- Brightness system actions need a laptop panel (WMI); external monitors aren't supported.
- UWP apps report as `applicationframehost.exe` (context falls back to the default ring).
- If Windows silently drops the LL hook (rare; heavy system load), it self-reinstalls within 60 s — or use tray → *Re-arm*.
