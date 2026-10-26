#!/bin/bash
# Installs Break.app for the current user only: no admin rights needed.
# Usage: bash install.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/Break.app"
DEST="$HOME/Applications"

if [ ! -d "$SRC" ]; then
  echo "Break.app not found next to this script." >&2
  exit 1
fi

mkdir -p "$DEST"
pkill -x Break 2>/dev/null || true
rm -rf "$DEST/Break.app"
cp -R "$SRC" "$DEST/"

# Files downloaded from the internet are quarantined; Break is not notarized,
# so lift the quarantine to let it open (allowed on the user's own files).
xattr -dr com.apple.quarantine "$DEST/Break.app" 2>/dev/null || true

open "$DEST/Break.app"
echo "✓ Break is installed in $DEST and running in the menu bar."
