# Installing ActionRing

A 2‑minute guide for getting ActionRing running on your Mac.

- **Requirements:** macOS 14 (Sonoma) or newer. Any mouse with at least one extra button works best (a side/thumb button), but a plain mouse is fine too.
- **What you need:** the `ActionRing-<version>.dmg` file someone shared with you.

> **Why the extra clicks below?** ActionRing isn't notarized by Apple yet, so macOS shows an "unidentified developer" warning the *first* time you open it. The steps below are the normal, Apple‑supported way to open such an app. You do them **once**.

---

## Step 1 — Open the disk image

Double‑click `ActionRing-<version>.dmg`. A window opens showing **ActionRing** and an **Applications** shortcut.

## Step 2 — Drag it into Applications

Drag the **ActionRing** icon onto the **Applications** folder in the same window.

```
┌─────────────────────────────┐
│   [ActionRing]  →  [Applications]
└─────────────────────────────┘
        drag this onto this
```

You can now eject the disk image (drag it to the Trash / click ⏏ in Finder).

## Step 3 — Open it the first time (right‑click → Open)

Don't double‑click yet — macOS will block it. Instead:

1. Open your **Applications** folder.
2. **Right‑click** (or hold **Control** and click) **ActionRing**.
3. Choose **Open**.
4. In the dialog that appears, click **Open** again.

That's the one‑time unlock. From now on it opens normally (double‑click, Spotlight, etc.).

> **If you don't see an "Open" button** (newer macOS sometimes only offers "Done"):
> go to **System Settings → Privacy & Security**, scroll down, and click
> **"Open Anyway"** next to the ActionRing message.
>
> **Terminal shortcut** (does the same thing instantly):
> ```bash
> xattr -dr com.apple.quarantine /Applications/ActionRing.app
> ```

## Step 4 — Grant Accessibility (required)

ActionRing watches for your trigger mouse button using a system *event tap*, which macOS gates behind Accessibility. **Without this, the ring won't appear when you press the button.**

1. **System Settings → Privacy & Security → Accessibility**
2. Find **ActionRing** in the list and turn its switch **on**.
   - If it isn't listed, click **+**, pick `ActionRing` from Applications, then enable it.
3. If the trigger still doesn't respond, **quit and reopen** ActionRing.

This is the **only** permission ActionRing asks for. It makes no network calls and never reads your typed text, window titles, or file contents.

## Step 5 — Find it and try it

ActionRing has **no Dock icon** — it lives in the **menu bar** (top‑right of your screen, look for the ⊕ ring icon).

- Click the menu‑bar icon → **Preview Ring** to see it appear and follow your cursor (no permission needed for the preview).
- Then **hold the trigger button** — by default the **side/thumb button (Button 4)** — and the ring appears at your cursor. Drag toward a slice and release to fire it; release in the center to cancel.
- Open the menu‑bar icon → **Settings…** to change the trigger button (there's a **Record from mouse** button), ring size, and slot count.

You're done. 🎉

---

## Troubleshooting

**"ActionRing is damaged and can't be opened. You should move it to the Trash."**
This is Gatekeeper on a quarantined, non‑notarized app — it isn't actually damaged. Run:
```bash
xattr -dr com.apple.quarantine /Applications/ActionRing.app
```
then open it again. (Or re‑do Step 3's right‑click → Open.)

**The menu‑bar icon is there, but pressing the button does nothing.**
Accessibility isn't active. Re‑check Step 4. A reliable reset:
1. System Settings → Privacy & Security → Accessibility → toggle ActionRing **off**, then **on**.
2. Quit ActionRing (menu‑bar icon → Quit) and reopen it.

**The ring flashes and disappears instantly / looks faint.**
Make sure you're running the version from `/Applications` (Step 2), not an older copy. Quit any duplicate instances and reopen the installed one.

**My mouse button isn't being detected.**
Open Settings → click **Record from mouse**, then press the button you want. Avoid binding left/right click (Button 1/2) — use a side button so normal clicking still works.

**Nothing appears in System Settings → Accessibility to enable.**
Click the **+** button there and add `ActionRing` from `/Applications` manually.

**How do I uninstall?**
Quit ActionRing (menu‑bar icon → Quit), then drag `/Applications/ActionRing.app` to the Trash. To also remove its settings:
```bash
rm -rf ~/Library/Application\ Support/ActionRing
```

---

## For developers (building from source)

If you have the repo and a Swift 6 toolchain instead of a `.dmg`:

```bash
make install     # build a release .app and copy it to /Applications
# or
make bundle      # just build ./ActionRing.app
make dmg         # build a shareable ./dist/ActionRing-<version>.dmg
```

Then grant Accessibility as in Step 4. See [ActionRing.md](ActionRing.md) for the full reference and the developer guide.

---

## A note on the warnings (for whoever shipped this)

The "unidentified developer" prompt disappears entirely if the build is **signed with a Developer ID and notarized by Apple** (requires a paid Apple Developer account). Until then, the right‑click → Open / "Open Anyway" flow above is expected and safe for a build you trust.
