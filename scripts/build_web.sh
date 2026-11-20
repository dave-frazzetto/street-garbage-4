#!/usr/bin/env bash
# Exports the single-threaded HTML5 build to build/web/ and zips it for itch.io (index.html at the zip root).
# Usage: GODOT=/path/to/Godot_console.exe scripts/build_web.sh
set -eu
GODOT="${GODOT:-/d/Programs/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
rm -f build/street-garbage-web.zip
if command -v zip >/dev/null 2>&1; then
  (cd build/web && zip -qr ../street-garbage-web.zip .)
else
  powershell.exe -NoProfile -Command "Compress-Archive -Path 'build/web/*' -DestinationPath 'build/street-garbage-web.zip' -Force"
fi
ls -la build/web build/street-garbage-web.zip
