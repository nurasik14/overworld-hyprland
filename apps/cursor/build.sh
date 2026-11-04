#!/usr/bin/env bash
# Build (and optionally --install) the Overworld cursor theme: Xcursor + hyprcursor. See build_cursor.py.
set -euo pipefail
here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
uv_bin="$(command -v uv || ls ~/.hermes/tools/uv-*/uv 2>/dev/null | head -1)"
[[ -n "$uv_bin" ]] || { echo "build.sh: uv not found" >&2; exit 1; }
exec "$uv_bin" run --project "$repo/tools/assetforge" python "$here/build_cursor.py" "$@"
