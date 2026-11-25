#!/bin/zsh
# Builds the test renderer (build/render) from the scene sources.
set -e
cd "${0:A:h}"
mkdir -p build
swiftc -O -module-name ChristmasFlight -target arm64-apple-macos14.0 \
  Sources/Support.swift Sources/Nature.swift Sources/Buildings.swift Sources/Santa.swift Sources/ChristmasScene.swift Tools/main.swift \
  -o build/render
echo "Built build/render"
