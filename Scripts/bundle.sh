#!/usr/bin/env bash
# Build ActionRing and assemble a proper macOS .app bundle.
#
# A bundle (vs. a bare SPM binary) gives ActionRing a stable code identity, so
# the Accessibility permission you grant survives rebuilds, and LSUIElement
# makes it a true menu-bar agent (no Dock icon) from launch.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="ActionRing.app"
BUNDLE_ID="com.actionring.app"
VERSION="1.0.0"

# Kill any running instance so the trigger isn't handled by a stale (old-UI)
# build that still holds an Accessibility grant.
killall ActionRing 2>/dev/null || true

echo "▶ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN=".build/$CONFIG/ActionRing"
[ -f "$BIN" ] || { echo "✗ binary not found at $BIN"; exit 1; }

echo "▶ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ActionRing"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>ActionRing</string>
    <key>CFBundleDisplayName</key>     <string>ActionRing</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>      <string>ActionRing</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>CFBundleShortVersionString</key>    <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHumanReadableCopyright</key><string>ActionRing</string>
</dict>
</plist>
PLIST

# Sign. If a self-signed code-signing identity named "ActionRing Dev" exists,
# use it: its designated requirement is STABLE across rebuilds, so the
# Accessibility grant persists (create one with `make cert`). Otherwise fall
# back to ad-hoc, whose hash changes each build (grant must be re-given).
# NOTE: compute inside an `if` so a no-match grep can't abort `set -e`.
IDENTITY=""
if security find-identity -v -p codesigning 2>/dev/null | grep -q "ActionRing Dev"; then
    IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk '/ActionRing Dev/{print $2; exit}')
fi
if [ -n "${IDENTITY:-}" ]; then
    echo "▶ Signing with stable identity 'ActionRing Dev' ($IDENTITY)…"
    codesign --force --deep --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP" >/dev/null 2>&1 \
        && echo "  signed (grant will persist across rebuilds)" || echo "  (codesign failed)"
else
    echo "▶ Ad-hoc signing (grant resets each rebuild — run 'make cert' for persistence)…"
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign skipped)"
fi

echo "✅ Built $APP"
echo "   Run:     open $APP"
echo "   Install: cp -R $APP /Applications/"
echo "   Then grant Accessibility: System Settings → Privacy & Security → Accessibility"
