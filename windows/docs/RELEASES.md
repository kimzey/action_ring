# Building & releasing ActionRing for Windows

How to produce a downloadable build and publish it on GitHub Releases.

> **Do this on a Windows machine.** The native deps (`koffi`, `uiohook-napi`)
> need their **Windows** binaries, which `npm install` only fetches when run on
> Windows. A build cross-made from macOS/Linux will start but the trigger hook
> won't work.

---

## Two ways to build

### 1. `npm run pack` — portable ZIP  ✅ recommended

```powershell
npm install        # once
npm run pack        # → dist\ActionRing-win32-x64-1.0.0.zip
```

- Uses [`@electron/packager`](https://github.com/electron/packager): bundles the
  Electron runtime you already downloaded during `npm install`, sets the exe
  metadata, and zips the folder.
- **No extra downloads** — it does **not** fetch `winCodeSign`/`nsis`, so it
  never hits the hang described below.
- Output: a folder `dist\ActionRing-win32-x64\` (run `ActionRing.exe` inside it)
  and a ready-to-upload `dist\ActionRing-win32-x64-<version>.zip`.
- Users **unzip and run `ActionRing.exe`** — no installer. On first launch
  Windows SmartScreen shows "Windows protected your PC" → **More info → Run
  anyway** (because the build isn't code-signed).

### 2. `npm run dist` — NSIS installer (`.exe`)

```powershell
npm run dist        # → dist\ActionRing-Setup-1.0.0.exe
```

- Produces a proper installer (Start-menu entry, uninstaller, choose-folder).
- **First run is slow and looks stuck** — see below. After the one-time
  download it's fast.

---

## "The build downloads something then hangs" — what's happening

On the **first** `npm run dist`, `electron-builder` downloads its Windows
toolchain from GitHub into a cache:

```
%LOCALAPPDATA%\electron-builder\Cache\
   winCodeSign\   (~110 MB — used for rcedit/signing even on unsigned builds)
   nsis\          (the installer compiler)
   nsis-resources\
```

That's **~150 MB from `github.com`** and it shows little/no progress, so it
looks frozen. It's usually **just slow, not stuck** — corporate networks,
antivirus, or GitHub rate-limiting make it crawl.

**What to do:**

1. **Be patient the first time** — give it 5–15 min. Watch the cache folder grow:
   ```powershell
   dir "$env:LOCALAPPDATA\electron-builder\Cache" -Recurse | Measure-Object Length -Sum
   ```
   If the byte count keeps rising, it's working — let it finish. The next build
   is fast (cache reused).
2. **Or skip it entirely** — use `npm run pack` (above). The portable ZIP needs
   none of these downloads and is the recommended path for handing out a build.
3. **If it truly stalls** (no growth for minutes): it's a network/AV/proxy block
   on `github.com`. Try another network/VPN, temporarily allow the cache folder
   in your antivirus, or pre-seed the cache by downloading the matching
   `winCodeSign` / `nsis` release assets from
   `github.com/electron-userland/electron-builder-binaries/releases` into the
   cache folders above, then re-run. (See electron-builder
   [issue #1859](https://github.com/electron-userland/electron-builder/issues/1859).)
4. **Behind a proxy?** Set `HTTPS_PROXY` (and `HTTP_PROXY`) before building so
   the downloader can reach GitHub.

---

## Publishing a GitHub Release

`gh` (GitHub CLI) isn't required, but it's the quickest. Both paths below
attach the build artifact so people can download it from the repo's
**Releases** page.

### A. With the GitHub web UI (no tools)

1. Build an artifact: `npm run pack` (zip) or `npm run dist` (installer).
2. Go to **github.com/kimzey/action_ring → Releases → Draft a new release**.
3. **Choose a tag** — e.g. `windows-v1.0.0` (use a prefixed tag so it doesn't
   collide with the macOS app's versioning).
4. Set a title + notes, then **drag the file** from `dist\` into the
   "Attach binaries" box:
   - `ActionRing-win32-x64-1.0.0.zip`, and/or
   - `ActionRing-Setup-1.0.0.exe`
5. **Publish release.** The download link is
   `…/releases/download/windows-v1.0.0/ActionRing-win32-x64-1.0.0.zip`.

### B. With the GitHub CLI

```powershell
# one-time: winget install GitHub.cli   (then: gh auth login)
gh release create windows-v1.0.0 ^
  dist\ActionRing-win32-x64-1.0.0.zip ^
  dist\ActionRing-Setup-1.0.0.exe ^
  --title "ActionRing for Windows v1.0.0" ^
  --notes "Hold your mouse side button to open the ring. Unzip and run ActionRing.exe, or run the installer."
```

### C. Auto-publish from electron-builder (optional)

`electron-builder` can upload to GitHub Releases itself:

```powershell
$env:GH_TOKEN = "<a GitHub personal-access-token with repo scope>"
npm run dist -- --publish always
```

This creates/updates a draft release for the current `version` and uploads the
installer. (It still needs the one-time toolchain download.) For the portable
ZIP path, just upload with option A or B.

---

## Tell users where to download

In the release notes, point people at **[`docs/INSTALL.md`](INSTALL.md)** and
note the one-time SmartScreen "More info → Run anyway" step (unsigned build).

> **Warning-free downloads** (no SmartScreen) require an EV/OV code-signing
> certificate (paid) to sign the exe/installer — the same trade-off as the
> macOS app needing an Apple Developer account to notarize. The free path always
> shows the first-run warning.
