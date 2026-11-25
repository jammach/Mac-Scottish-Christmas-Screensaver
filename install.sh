#!/bin/zsh
# Installs the screensaver for the current user. Works from a built copy (build/) or from an unzipped download (next to this script).
set -e
cd "${0:A:h}"
NAME="Scottish Christmas"
SRC="build/$NAME.saver"
[[ -d "$SRC" ]] || SRC="$NAME.saver"
[[ -d "$SRC" ]] || { echo "Could not find '$NAME.saver'. Build it with ./build.sh or unzip the download first."; exit 1; }
DEST="$HOME/Library/Screen Savers"
mkdir -p "$DEST"
rm -rf "$DEST/$NAME.saver"
cp -R "$SRC" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/$NAME.saver" 2>/dev/null || true
killall legacyScreenSaver 2>/dev/null || true
echo "Installed. Open System Settings > Screen Saver and choose '$NAME'."
