#!/bin/bash
# Publishes the web build to Vercel (static hosting; it brotli-compresses .wasm on the fly).
#   tools/web/deploy.sh            deploy a preview URL
#   tools/web/deploy.sh --prod     deploy to the production domain
# One-time: `vercel login`, then `cd build/Web && vercel link` (project name: polygon-protocol),
# and add the domain polygon.kirilpetrovski.com in the Vercel project settings.
set -euo pipefail
cd "$(dirname "$0")/../.."
tools/web/build.sh
cp tools/web/vercel.json build/Web/vercel.json
cd build/Web
vercel deploy "$@"
