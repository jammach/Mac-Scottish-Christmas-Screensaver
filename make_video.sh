#!/bin/zsh
# Renders the film the screensaver plays: two journeys across snowy UK rooftops and treetops (3 min 44 s, 1080p, 30 fps).
# Needs ffmpeg (brew install ffmpeg). Takes about 4 minutes on an Apple Silicon Mac; it uses all your CPU cores while it runs.
set -e
cd "${0:A:h}"
command -v ffmpeg >/dev/null || { echo "ffmpeg is required: brew install ffmpeg"; exit 1; }
FFMPEG_PATH=$(command -v ffmpeg)
./build_tool.sh
mkdir -p video
FILM_CRF="${FILM_CRF:-21}" FFMPEG_PATH="$FFMPEG_PATH" ./build/render video video/christmas-flight.mp4 224 30 1920 1080
ls -lh video/christmas-flight.mp4
