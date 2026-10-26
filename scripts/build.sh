#!/bin/bash
# Builds Break.app and a distributable zip.
# Universal (Apple Silicon + Intel) with Xcode; current architecture only with
# the Command Line Tools, which cannot build for several architectures.
#   build/Break.app
#   build/Break.zip  (Break.app + install.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

if xcodebuild -version >/dev/null 2>&1; then
  ARCHS=(--arch arm64 --arch x86_64)
  KIND="universal"
else
  ARCHS=()
  KIND="$(uname -m) only, Xcode not found"
fi
APP=build/Break.app
DIST=build/dist/Break

if [ ! -f Resources/AppIcon.icns ]; then
  echo "→ Generating icon"
  swift scripts/make-icon.swift Resources/AppIcon.icns
fi

echo "→ Building (release, $KIND)"
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/Break"

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
