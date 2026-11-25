#!/bin/zsh
# Builds build/livetest, a test tool for the live engine (single frames and timings).
set -e
cd "${0:A:h}"
mkdir -p build
swiftc -O -module-name LiveTest -target arm64-apple-macos14.0 \
  Sources/Support.swift Sources/Nature.swift Sources/Buildings.swift Sources/Santa.swift Sources/ChristmasScene.swift \
  Live/LiveEngine.swift Tools/livetest/main.swift -o build/livetest
echo "Built build/livetest"
