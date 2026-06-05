# Installing & running ActionRing on Windows

A short guide to getting ActionRing running. There are two paths — pick one:

- **A. Run the installer** (`.exe` someone shared with you) — no developer tools.
- **B. Run from source** (you have Node.js and want to build/develop it).

> **Requirements:** Windows 10 or 11. A mouse with at least one side/thumb button works best (default trigger is **Button 4**), but any mouse is fine — you can pick a different trigger in Settings.

---

## A. Run the installer (`ActionRing-Setup-<version>.exe`)

1. **Double-click** `ActionRing-Setup-<version>.exe`.
2. Windows may show a blue **"Windows protected your PC"** box — this happens because the app isn't code-signed yet (the free path). Click **More info → Run anyway**. You do this **once**.
3. Follow the installer (you can choose the install folder), then launch **ActionRing**.
4. ActionRing lives in the **system tray** (the ⊕ icon near the clock) — there's no window. **Hold your mouse side button (Button 4)** and the ring appears at your cursor.

That's it — no special permission is needed (Windows allows global mouse hooks out of the box).

### First things to try

- **Hold** the trigger → drag toward a slot → release to fire. Release in the **center** to cancel.
- **Quick-click** the trigger → the ring stays open (sticky). Click again to fire, or click the center to cancel. It auto-closes after 6 seconds.
- Tray icon → **Preview Ring** to see it without firing anything.
- Tray icon → **Settings…** to change the trigger button, ring size, and per-app profiles.

---

## B. Run from source

You'll need **Node.js 20+** (`node -v` to check).

```powershell
# from the repo root
cd windows
make install        # or: npm install
make run            # or: npm start   → tray app, hold Button 4
```

Other handy commands (all have a plain `npm` equivalent — see the `Makefile`):

```powershell
make preview        # show the ring following your cursor (no trigger needed)
make test           # run the unit tests
make capture        # save ring.png to eyeball the look
make dist           # build ActionRing-Setup-<version>.exe into .\dist
make clean          # remove node_modules and dist
```

If you don't have `make`, every target is a one-liner npm command — open the
`Makefile` and run the command shown in each comment.

> **Building the installer (`make dist`)** is best done **on Windows**.
> Cross-building it from macOS/Linux needs extra tooling (wine), so run that
> target on a Windows machine.

---

## Using it

```
hold trigger ─► ring appears at the cursor, showing the focused app's actions
   drag ──────► the slot under your cursor highlights (center = cancel)
release ──────► fires that slot's action
```

- The ring's **contents change with the focused app** — VS Code, your browser,
  Windows Terminal, Slack, Spotify… each gets its own set of actions. Apps
  without a specific profile fall back to a category ring (IDE / Browser / …)
  or the universal Copy / Paste / Cut / Undo / Redo / Save / Select-All /
  Screenshot ring.
- The ring is **hidden over fullscreen games** so it won't interrupt play
  (toggle this in Settings → "Hide ring in fullscreen games").

## Configuring profiles

Tray icon → **Settings… → Profiles**:

- **New profile** — pick a running app (or type its exe name like `code.exe`),
  then edit up to 8 slots.
- **Edit a slot** — set its label, icon, color, and action: keyboard shortcut,
  launch app, open URL, system action (volume / media / lock / snip / Task
  View / …), PowerShell script, type text, or open a file/folder.
- **Enable / disable** any profile; a disabled app falls back to its category
  or the default ring. The master **Enable ActionRing** switch pauses everything.

Everything is plain JSON under **`%APPDATA%\ActionRing\`**
(`profiles.json`, `default.json`, `settings.json`) — the **same schema as the
macOS app**, so profiles copy across machines. You can hand-edit these files
too.

> **Trust note:** a profile can run PowerShell and launch apps, so treat an
> imported profile pack like running someone's script — read its shell scripts
> and launch targets before enabling it. See the README's *Security note*.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Tray menu shows **"Listen-only fallback"** | The low-level hook couldn't install with suppression — the ring still works, but the trigger press also reaches the focused app. Try tray → **Re-arm**, or restart the app. |
| Tray menu shows **"Hook not installed"** | The mouse hook failed entirely. Use tray → **Re-arm**. If it persists, another tool may be holding a conflicting global hook. |
| The ring doesn't open | Check the trigger button in Settings (a basic mouse may not have Button 4 — pick Left/Right/Middle or **Record from mouse…**), and make sure **Enable ActionRing** is on. |
| Trigger also triggers the app's own "Back" | That's the listen-only fallback (above) — true suppression needs the low-level hook; **Re-arm** or restart. |
| A side-button mouse isn't detected | Use Settings → **Record from mouse…** and press the button you want. |
| The ring rarely stops responding | Windows can drop a global hook under heavy load; ActionRing detects this and reinstalls within a few seconds, or use tray → **Re-arm**. |

## Uninstall

Installer build: **Settings → Apps → Installed apps → ActionRing → Uninstall**.
From source: just delete the folder. To also remove your profiles, delete
`%APPDATA%\ActionRing\`.
