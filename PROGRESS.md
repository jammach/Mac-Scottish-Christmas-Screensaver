# Mac Scottish Christmas Screensaver — progress (saved 2026-11-25, updated for the live version)

**What it is:** a Christmas screensaver for the Mac in the style of a children's animation: a fixed camera flying over snowy UK rooftops and
treetops (English terraces, countryside, forest canopy, Scottish village, town), with Santa's sleigh dropping presents down the chimneys.

## Where it stands
- **Done:** the artwork was approved from the 90-second preview. The final screensaver is built and tested.
- **How it works:** the scene code (`Sources/`) draws a film; `Saver/ChristmasFlightView.swift` plays that film silently in a loop (hardware decoded, so
  almost no CPU). Drawing the scene live was about 70-120 ms a frame on one core, too slow for a smooth 30 fps saver, hence the film.
- **The film:** 224 s (two full journeys with different houses and trees, the second ends where the first begins), 1080p, 30 fps, about 146 MB.
  First 90 s match the approved preview.
- **Tested:** bundle builds for Apple Silicon and Intel and is ad-hoc signed; a test host loaded it, confirmed silent playback, random start point,
  correct fit on normal / ultra-wide / settings-preview sizes, pause on stop, and a clean loop at the end of the film; the installer and uninstaller
  were run from the unzipped download using a temporary home folder.
- **Not tested:** inside macOS's real screensaver host on a live display (that needs a person at the Mac). First thing to check after installing.
- **Publishing to GitHub:** `gh` was installed with Homebrew; waiting for the one-time `gh auth login`. Repo name: Mac-Scottish-Christmas-Screensaver.

## Commands
```
./make_video.sh      # renders video/christmas-flight.mp4 (about 3 min on an M2 Max, needs ffmpeg)
./build.sh           # builds build/Scottish Christmas.saver (arm64 + x86_64) and signs it
./install.sh         # installs for the current user
./package.sh 1.0.0   # dist/Scottish-Christmas-Screensaver-1.0.0.zip for a GitHub release
./uninstall.sh
```

## Ideas for later
- A live-rendered endless version (would need baked scrolling tiles to reach 30 fps; the film approach avoids that).
- A longer film or a Welsh valley / coastal scene; optional quiet music.
- A Developer ID signature and notarisation, so downloads need no quarantine step.

## Live version (branch `live-version`, version 2.0.0)
- **What:** `Scottish Christmas Live.saver`, drawn live and endless (each journey of 112 s is built from its own seed). Same artwork as the film.
- **How it stays fast:** scenery (hills, mid-row, houses, trees, ground) is baked into 1024-unit tiles on a background thread; each frame only draws what
  moves (snow, smoke, twinkles, Santa, presents) into two transparent overlay pictures; Core Animation layers composite and scroll everything on the GPU.
  Twinkles, string-light glows and smoke are recorded while baking (`Emitter`) and replayed live. Santa's halo is a GPU layer.
- **Measured (M2 Max, test host, 1080-1440p):** live frame 3-5 ms (3-14 ms with Santa) on one thread; steady 30.0 frames/s with 0 late frames over 450;
  30-50% of one core; ~172 MB resident; first screen of scenery baked in ~0.2 s; no memory growth over repeated stop/start.
  Frames are paced by a display link; colour space follows the display so Core Animation does no per-frame conversion.
- **Fixes found on the way:** per-frame colour conversion on the main thread (cost 30% CPU) fixed by drawing in the display's colour space;
  memory held per stop/start fixed by clearing layer contents in `tearDown`; timer jitter fixed by a display link.
- **Not tested:** inside macOS's real screensaver host on a live display, and multi-display behaviour. First thing to check after installing.
- **Differences from the film:** far hills/mountains and the Highland castle are anchored to the landscape (they slide past) instead of morphing;
  sheep and the snowman are drawn live; presents are coloured from their chimney's position; the moon and stars no longer drift.
- **Commands:** `./build_live.sh`, `./install.sh live`, `./uninstall.sh live`, `./package.sh live 2.0.0`; tests: `./build_livetest.sh` then `build/livetest still|bench|santa`.
