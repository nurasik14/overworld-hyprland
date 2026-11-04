#!/usr/bin/env bash
# Build the QA widget gallery to /tmp/ow-kv-bin/overworld-test-kv (app-id overworld-test-kv so scripts/dev-shot.sh allows it).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p /tmp/ow-kv-bin
g++ -std=c++17 -fPIC $(pkg-config --cflags Qt6Widgets) "$here/gallery.cpp" -o /tmp/ow-kv-bin/overworld-test-kv $(pkg-config --libs Qt6Widgets)
echo /tmp/ow-kv-bin/overworld-test-kv
