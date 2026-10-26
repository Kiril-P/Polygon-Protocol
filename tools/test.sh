#!/bin/bash
# Runs the headless test suite (tests/run_tests.tscn). Never opens a window and never touches
# your save, settings or the online boards. Takes about two minutes.
#   tools/test.sh        prints failures and the summary line
#   tools/test.sh -v     prints every check
# Exit code is 0 when every check passes.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOG="$(mktemp -t polygon-tests)"
"$GODOT" --headless --path . res://tests/run_tests.tscn > "$LOG" 2>&1
CODE=$?
if [ "${1:-}" = "-v" ]; then
  cat "$LOG"
else
  grep -E "^(  FAIL|SCRIPT ERROR|Parse Error)|checks," "$LOG" || true
fi
if [ $CODE -ne 0 ]; then echo "FAILED (exit $CODE). Full log: $LOG"; else rm -f "$LOG"; fi
exit $CODE
