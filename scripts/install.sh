#!/bin/bash
# Installs Break.app for the current user only: no admin rights needed.
# Usage: bash install.sh  (from the unzipped Break folder or the repository)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Applications"

# Next to this script in the distributed zip, or in build/ when run from the repo.
if [ -d "$HERE/Break.app" ]; then
  SRC="$HERE/Break.app"
elif [ -d "$HERE/../build/Break.app" ]; then
  SRC="$HERE/../build/Break.app"
else
  echo "Break.app not found. From the repository, run ./scripts/build.sh first." >&2
  exit 1
fi

mkdir -p "$DEST"
# Quit a running copy and wait until it is gone: opening the app while the old
# instance is still terminating makes LaunchServices fail with error -600.
if pkill -x Break 2>/dev/null; then
  for _ in $(seq 50); do
    pgrep -x Break >/dev/null || break
    sleep 0.1
  done
  pkill -9 -x Break 2>/dev/null || true
fi
rm -rf "$DEST/Break.app"
cp -R "$SRC" "$DEST/"

# Files downloaded from the internet are quarantined; Break is not notarized,
# so lift the quarantine to let it open (allowed on the user's own files).
xattr -dr com.apple.quarantine "$DEST/Break.app" 2>/dev/null || true

# Register the fresh copy with LaunchServices before opening it.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST/Break.app" 2>/dev/null || true
open "$DEST/Break.app"
echo "✓ Break is installed in $DEST and running in the menu bar."
