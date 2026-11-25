#!/bin/zsh
# Removes the screensaver for the current user.
NAME="Scottish Christmas"
rm -rf "$HOME/Library/Screen Savers/$NAME.saver"
killall legacyScreenSaver 2>/dev/null || true
echo "Removed '$NAME'. If it is still listed in System Settings, close and reopen the Screen Saver pane."
