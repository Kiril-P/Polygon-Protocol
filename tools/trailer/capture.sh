#!/bin/bash
# Records the scripted trailer (scenes/trailer.tscn) with Godot's movie maker, then encodes an MP4.
#   tools/trailer/capture.sh [length_seconds] [WIDTHxHEIGHT] [fps] [end card text]
# Needs a real display (movie maker cannot run --headless) and ffmpeg.
# Output: build/trailer/polygon-protocol-trailer.mp4  (build/ is git-ignored)
set -euo pipefail
cd "$(dirname "$0")/../.."
LENGTH="${1:-46}"
RES="${2:-1920x1080}"
FPS="${3:-60}"
CTA="${4:-}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT=build/trailer
mkdir -p "$OUT"
rm -f "$OUT/capture.avi"
"$GODOT" --path . --resolution "$RES" --write-movie "$OUT/capture.avi" --fixed-fps "$FPS" \
  res://scenes/trailer.tscn -- --length="$LENGTH" --cta="$CTA" --seed=7
ffmpeg -y -loglevel error -i "$OUT/capture.avi" -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart "$OUT/polygon-protocol-trailer.mp4"
echo "Wrote $OUT/polygon-protocol-trailer.mp4"
