#!/bin/bash
# Builds a universal (Apple Silicon + Intel) Break.app and a distributable zip.
#   build/Break.app
#   build/Break.zip  (Break.app + install.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS=(--arch arm64 --arch x86_64)
APP=build/Break.app
DIST=build/dist/Break

if [ ! -f Resources/AppIcon.icns ]; then
  echo "→ Generating icon"
  swift scripts/make-icon.swift Resources/AppIcon.icns
fi

echo "→ Building (release, universal)"
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/Break"

echo "→ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Break"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

# Ad-hoc signature: no Apple developer account needed.
codesign --force --sign - "$APP"

echo "→ Archiving build/Break.zip"
rm -rf build/dist build/Break.zip
mkdir -p "$DIST"
cp -R "$APP" "$DIST/"
cp scripts/install.sh "$DIST/install.sh"
(cd build/dist && ditto -c -k --norsrc --noextattr --keepParent Break ../Break.zip)

echo "✓ $APP"
echo "✓ build/Break.zip"
