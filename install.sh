#!/bin/zsh
# Installs a screensaver for the current user.
#   ./install.sh         installs "Scottish Christmas" (the film version)
#   ./install.sh live    installs "Scottish Christmas Live" (drawn live, endless)
# Works from a built copy (build/) or from an unzipped download (next to this script).
set -e
cd "${0:A:h}"
case "${1:-film}" in
  film) NAME="Scottish Christmas" ;;
  live) NAME="Scottish Christmas Live" ;;
  *) echo "Usage: ./install.sh [film|live]"; exit 1 ;;
esac
SRC="$NAME.saver"
[[ -d "$SRC" ]] || SRC="build/$NAME.saver"
[[ -d "$SRC" ]] || { echo "Could not find '$NAME.saver'. Build it first (./build.sh or ./build_live.sh), or unzip the download."; exit 1; }
DEST="$HOME/Library/Screen Savers"
mkdir -p "$DEST"
rm -rf "$DEST/$NAME.saver"
cp -R "$SRC" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/$NAME.saver" 2>/dev/null || true
killall legacyScreenSaver 2>/dev/null || true
echo "Installed. Open System Settings > Screen Saver and choose '$NAME'."
