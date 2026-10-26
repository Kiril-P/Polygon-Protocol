#!/bin/bash
# Serves the web build locally so you can play it in a browser. Builds it first if build/Web is missing.
#   tools/web/serve.sh [port]     default port 8000, then open http://localhost:<port>
# Rebuild after code changes with tools/web/build.sh. The preset is single-threaded, so plain
# python http.server is enough (no cross-origin isolation headers).
set -euo pipefail
cd "$(dirname "$0")/../.."
PORT="${1:-8000}"
if [ ! -f build/Web/index.html ]; then
  echo "No web build found, building one..."
  tools/web/build.sh
fi
echo "Serving build/Web at http://localhost:$PORT (Ctrl+C to stop)"
exec python3 -m http.server "$PORT" -d build/Web
