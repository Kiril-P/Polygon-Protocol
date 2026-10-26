#!/bin/bash
# Exports the "Web" preset and zips it for itch.io (upload the zip, tick "This file will be played in the browser").
# The preset is single-threaded, so no cross-origin isolation headers are needed.
# Output: build/Web/ (serve with tools/web/serve.sh) and build/polygon-protocol-web.zip (~31 MB; the .pck is ~24 MB, the engine .wasm ~39 MB raw / ~7 MB brotli)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
rm -rf build/Web && mkdir -p build/Web
"$GODOT" --headless --path . --export-release "Web" build/Web/index.html
(cd build/Web && rm -f ../polygon-protocol-web.zip && zip -qr ../polygon-protocol-web.zip .)
ls -lh build/polygon-protocol-web.zip
