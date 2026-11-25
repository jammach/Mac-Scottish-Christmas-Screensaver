#!/bin/zsh
# Builds build/Scottish Christmas Live.saver: the live-drawn, endless version (Apple Silicon + Intel, macOS 14 or later). No film needed.
set -e
cd "${0:A:h}"
NAME="Scottish Christmas Live"
OUT="build/$NAME.saver"
mkdir -p build
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -module-name ScottishChristmasLive -target "$arch-apple-macos14.0" \
    -framework ScreenSaver -framework AppKit -framework QuartzCore -Xlinker -bundle \
    Sources/Support.swift Sources/Nature.swift Sources/Buildings.swift Sources/Santa.swift Sources/ChristmasScene.swift \
    Live/LiveEngine.swift Live/FramePipeline.swift Live/LiveView.swift -o "build/ScottishChristmasLive.$arch"
done
lipo -create build/ScottishChristmasLive.arm64 build/ScottishChristmasLive.x86_64 -output "$OUT/Contents/MacOS/ScottishChristmasLive"
rm -f build/ScottishChristmasLive.arm64 build/ScottishChristmasLive.x86_64
cp Live/Info.plist "$OUT/Contents/Info.plist"
codesign --force --deep -s - "$OUT"
echo "Built $OUT"
