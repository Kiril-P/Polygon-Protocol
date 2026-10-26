#!/bin/bash
# Exports every platform and collects the files to upload to itch.io into build/itch/.
#   tools/release.sh            # web, windows, mac, linux
# Needs the Godot 4.7.2 export templates (Web, Windows, macOS, Linux) installed. Headless only.
# Output: build/itch/polygon-protocol-{web,windows,mac,linux}.zip (mac is the .dmg).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT=build/itch
rm -rf build/Web build/Windows build/Mac build/Linux "$OUT"
mkdir -p build/Web build/Windows build/Mac build/Linux "$OUT"

"$GODOT" --headless --path . --export-release "Web" build/Web/index.html
(cd build/Web && zip -qr "../../$OUT/polygon-protocol-web.zip" .)

"$GODOT" --headless --path . --export-release "Windows Desktop" "build/Windows/Polygon Protocol.exe"
(cd build/Windows && zip -qr "../../$OUT/polygon-protocol-windows.zip" "Polygon Protocol.exe")

"$GODOT" --headless --path . --export-release "Linux" "build/Linux/Polygon Protocol.x86_64"
(cd build/Linux && chmod +x "Polygon Protocol.x86_64" && zip -qr "../../$OUT/polygon-protocol-linux.zip" "Polygon Protocol.x86_64")

"$GODOT" --headless --path . --export-release "macOS" "build/Mac/Polygon Protocol.dmg"
cp "build/Mac/Polygon Protocol.dmg" "$OUT/polygon-protocol-mac.dmg"

ls -lh "$OUT"
