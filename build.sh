#!/bin/zsh
# Builds build/Scottish Christmas.saver (Apple Silicon + Intel, macOS 14 or later) and ad-hoc signs it.
# Needs the film first: run ./make_video.sh, or put christmas-flight.mp4 in video/.
set -e
cd "${0:A:h}"
NAME="Scottish Christmas"
OUT="build/$NAME.saver"
[[ -f video/christmas-flight.mp4 ]] || { echo "video/christmas-flight.mp4 not found. Run ./make_video.sh first."; exit 1; }
mkdir -p build
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -module-name ChristmasFlight -target "$arch-apple-macos14.0" \
    -framework ScreenSaver -framework AVFoundation -framework Cocoa -Xlinker -bundle \
    Saver/ChristmasFlightView.swift -o "build/ChristmasFlight.$arch"
done
lipo -create build/ChristmasFlight.arm64 build/ChristmasFlight.x86_64 -output "$OUT/Contents/MacOS/ChristmasFlight"
rm -f build/ChristmasFlight.arm64 build/ChristmasFlight.x86_64
cp Saver/Info.plist "$OUT/Contents/Info.plist"
cp video/christmas-flight.mp4 "$OUT/Contents/Resources/christmas-flight.mp4"
codesign --force --deep -s - "$OUT"
echo "Built $OUT"
