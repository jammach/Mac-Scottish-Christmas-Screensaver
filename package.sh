#!/bin/zsh
# Makes dist/Scottish-Christmas-Screensaver-<version>.zip: the built saver plus the one-step installer, ready to attach to a release.
set -e
cd "${0:A:h}"
VERSION="${1:-1.0.0}"
NAME="Scottish Christmas"
[[ -d "build/$NAME.saver" ]] || { echo "Build it first: ./build.sh"; exit 1; }
STAGE="dist/Scottish-Christmas-Screensaver-$VERSION"
rm -rf dist && mkdir -p "$STAGE"
ditto "build/$NAME.saver" "$STAGE/$NAME.saver"
cp install.sh uninstall.sh "$STAGE/"
cat > "$STAGE/INSTALL.txt" <<'TXT'
Scottish Christmas screensaver: install in 3 steps

1. Open Terminal (Cmd+Space, type Terminal, press Return).
2. Type "cd " (with a space), drag this folder onto the Terminal window, press Return.
3. Run:  ./install.sh
   (if macOS refuses, run "chmod +x install.sh" first)

Then open System Settings > Screen Saver and choose "Scottish Christmas".
To remove it later, run ./uninstall.sh from this folder.
TXT
(cd dist && ditto -c -k --keepParent "Scottish-Christmas-Screensaver-$VERSION" "Scottish-Christmas-Screensaver-$VERSION.zip")
ls -lh "dist/Scottish-Christmas-Screensaver-$VERSION.zip"
