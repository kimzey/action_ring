#!/usr/bin/env bash
# Build ActionRing.app and package it into a distributable .dmg under dist/.
# The dmg contains the app plus an /Applications symlink so the recipient can
# drag-to-install. (Unsigned/un-notarized — first launch needs a right-click →
# Open; see the README.)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="1.0.0"
APP="ActionRing.app"
DIST="dist"
VOL="ActionRing"
DMG="$DIST/ActionRing-$VERSION.dmg"

# Build the app bundle first.
./Scripts/bundle.sh release

mkdir -p "$DIST"
rm -f "$DMG"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "▶ Creating ${DMG}…"
hdiutil create \
    -volname "$VOL" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

echo "✅ Built $DMG"
echo "   Send it to anyone. They drag ActionRing → Applications, then right-click → Open the first time."
