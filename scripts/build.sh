#!/bin/bash
# Builds a universal (Apple Silicon + Intel) Break.app and a distributable zip.
#   build/Break.app
#   build/Break.zip  (Break.app + install.sh)
#
# Calls swiftc directly rather than `swift build`: it works with Xcode as well
# as with Command Line Tools installs whose Package.swift support is broken.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Break.app
DIST=build/dist/Break
OBJ=build/obj

if [ ! -f Resources/AppIcon.icns ]; then
  echo "→ Generating icon"
  swift scripts/make-icon.swift Resources/AppIcon.icns
fi

echo "→ Compiling (release, universal)"
rm -rf "$OBJ"
mkdir -p "$OBJ"
for arch in arm64 x86_64; do
  xcrun swiftc -O -parse-as-library \
    -target "$arch-apple-macos14.0" \
    -module-name Break \
    Sources/Break/*.swift \
    -o "$OBJ/Break-$arch"
done
lipo -create "$OBJ/Break-arm64" "$OBJ/Break-x86_64" -output "$OBJ/Break"
BIN="$OBJ/Break"

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
