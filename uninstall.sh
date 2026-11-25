#!/bin/zsh
# Removes a screensaver for the current user.
#   ./uninstall.sh         removes "Scottish Christmas" (the film version)
#   ./uninstall.sh live    removes "Scottish Christmas Live"
case "${1:-film}" in
  film) NAME="Scottish Christmas" ;;
  live) NAME="Scottish Christmas Live" ;;
  *) echo "Usage: ./uninstall.sh [film|live]"; exit 1 ;;
esac
rm -rf "$HOME/Library/Screen Savers/$NAME.saver"
killall legacyScreenSaver 2>/dev/null || true
echo "Removed '$NAME'. If it is still listed in System Settings, close and reopen the Screen Saver pane."
