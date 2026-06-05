'use strict';
// Portable build — the reliable "release a download" path.
//
// Uses @electron/packager (which bundles the already-cached Electron binary and
// sets the exe metadata via its own @electron/rcedit) → produces an unpacked
// folder, then zips it. This deliberately AVOIDS electron-builder's one-time
// ~150 MB winCodeSign/nsis download from GitHub (the thing that appears to
// "hang" on the first `npm run dist`). The output zip is ready to attach to a
// GitHub Release; users unzip and run ActionRing.exe — no installer needed.
//
// RUN THIS ON WINDOWS. Cross-building win32 from macOS/Linux misses the
// Windows-native binary for uiohook-napi (it's fetched per-platform by npm),
// so the trigger hook wouldn't work in a mac-produced win32 build.

const path = require('node:path');
const fs = require('node:fs');
const { packager } = require('@electron/packager');
const archiver = require('archiver');

const ROOT = path.join(__dirname, '..');
const { version } = require(path.join(ROOT, 'package.json'));

const platform = process.env.AR_PLATFORM || 'win32';
const arch = process.env.AR_ARCH || 'x64';

function zipDir(srcDir, destZip) {
  return new Promise((resolve, reject) => {
    const output = fs.createWriteStream(destZip);
    const archive = archiver('zip', { zlib: { level: 9 } });
    output.on('close', () => resolve(archive.pointer()));
    archive.on('error', reject);
    archive.pipe(output);
    // put the contents under a top-level folder so unzip is tidy
    archive.directory(srcDir, path.basename(srcDir));
    archive.finalize();
  });
}

async function main() {
  const out = path.join(ROOT, 'dist');
  fs.mkdirSync(out, { recursive: true });

  console.log(`Packaging ActionRing ${version} for ${platform}/${arch}…`);
  const appPaths = await packager({
    dir: ROOT,
    out,
    platform,
    arch,
    overwrite: true,
    name: 'ActionRing',
    appCopyright: `ActionRing v${version}`,
    appVersion: version,
    // Keep src + production node_modules; drop dev cruft from the bundle.
    prune: true,
    ignore: [
      /^\/dist($|\/)/,
      /^\/\.git($|\/)/,
      /^\/tests($|\/)/,
      /^\/docs($|\/)/,
      /^\/scripts($|\/)/,
      /^\/Makefile$/,
      /^\/ring\.png$/,
    ],
  });

  const appDir = appPaths[0];
  const zipName = `ActionRing-${platform}-${arch}-${version}.zip`;
  const zipPath = path.join(out, zipName);
  fs.rmSync(zipPath, { force: true });
  console.log('Zipping…');
  const bytes = await zipDir(appDir, zipPath);

  console.log('');
  console.log('  Portable folder : ' + appDir);
  console.log('  Release zip     : ' + zipPath + `  (${(bytes / 1e6).toFixed(1)} MB)`);
  console.log('');
  console.log('Upload the .zip to a GitHub Release (see docs/RELEASES.md).');
}

main().catch((err) => {
  console.error('pack failed:', err);
  process.exit(1);
});
