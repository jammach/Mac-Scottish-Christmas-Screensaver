#!/bin/zsh
# Makes a download zip in dist/: the built saver plus the one-step installer, ready to attach to a release.
#   ./package.sh film 1.0.0     (needs build/Scottish Christmas.saver, from ./build.sh)
#   ./package.sh live 2.0.0     (needs build/Scottish Christmas Live.saver, from ./build_live.sh)
set -e
cd "${0:A:h}"
KIND="${1:-film}"
case "$KIND" in
  film) NAME="Scottish Christmas"; VERSION="${2:-1.0.0}"; FILE="Scottish-Christmas-Screensaver-$VERSION" ;;
  live) NAME="Scottish Christmas Live"; VERSION="${2:-2.0.0}"; FILE="Scottish-Christmas-Live-Screensaver-$VERSION" ;;
  *) echo "Usage: ./package.sh [film|live] [version]"; exit 1 ;;
esac
[[ -d "build/$NAME.saver" ]] || { echo "Build it first: $([[ $KIND == live ]] && echo ./build_live.sh || echo ./build.sh)"; exit 1; }
STAGE="dist/$FILE"
rm -rf "$STAGE" "dist/$FILE.zip" && mkdir -p "$STAGE"
ditto "build/$NAME.saver" "$STAGE/$NAME.saver"
cp install.sh uninstall.sh "$STAGE/"
ARG=$([[ $KIND == live ]] && echo " live" || echo "")
cat > "$STAGE/INSTALL.txt" <<TXT
$NAME screensaver: install in 3 steps

1. Open Terminal (Cmd+Space, type Terminal, press Return).
2. Type "cd " (with a space), drag this folder onto the Terminal window, press Return.
3. Run:  ./install.sh$ARG
   (if macOS refuses, run "chmod +x install.sh" first)

Then open System Settings > Screen Saver and choose "$NAME".
To remove it later, run ./uninstall.sh$ARG from this folder.
TXT
(cd dist && ditto -c -k --keepParent "$FILE" "$FILE.zip")
ls -lh "dist/$FILE.zip"
