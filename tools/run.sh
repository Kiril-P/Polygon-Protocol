#!/bin/bash
# Launches the game from the project root (opens a window). Extra arguments go to Godot:
#   tools/run.sh                              play from the main scene
#   tools/run.sh --fullscreen                 any Godot flag works
#   tools/run.sh res://scenes/trailer.tscn    start a specific scene
#   tools/run.sh --headless --quit-after 60   smoke test: boot, run 60 frames, exit (no window)
set -euo pipefail
cd "$(dirname "$0")/.."
# Godot binary: $GODOT, else the macOS app, else `godot` on the PATH.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT" ]; then
  GODOT="$(command -v godot || true)"
fi
if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
  echo "run.sh: Godot not found. Install Godot 4.5+ or set GODOT=/path/to/Godot, e.g." >&2
  echo "  GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run.sh" >&2
  exit 127
fi
echo "run.sh: $GODOT --path . $*" >&2
exec "$GODOT" --path . "$@"
