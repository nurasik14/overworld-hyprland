#!/usr/bin/env bash
# make-world.sh — render one new procedural world wallpaper. Used by the Select World screen's "Create New World".
#
#   scripts/make-world.sh [--seed N] [--scene S] [--time T] [--mode light|dark] [--out PATH]
#
#   --scene  plains birch-forest snowy-taiga desert cherry-grove ocean-beach mountains mushroom-fields nether the-end
#            (default: random)
#   --time   day dawn dusk night (default: day in light mode, night in dark mode; nether and the-end are always night)
#   --mode   light dark (default: from the time; day/dawn = light, dusk/night = dark)
#   --seed   any integer (default: random)
#   --out    output PNG (default: assets/wallpapers/<mode>/NN-<scene>-<time>.png, NN counting up from 50)
#
# Prints the finished file's path on stdout and nothing else there; progress goes to stderr. Appends the world to
# assets/wallpapers/index.json and emits the world.created event. Runs at nice 10 on at most 8 threads; about 15 s
# once numba's compile cache exists, under a minute the first time. Run it in the background; it never touches the
# wallpaper in use. Exit codes: 0 done, 2 bad arguments, 3 Mojang textures missing, 4 uv missing.
set -euo pipefail

REPO="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
PROJECT="$REPO/tools/worldgen"

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//' >&2; }
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
    esac
done

UV="$(command -v uv || true)"
if [[ -z "$UV" ]]; then
    for candidate in "$HOME"/.hermes/tools/uv-*/uv; do
        [[ -x "$candidate" ]] && UV="$candidate"
    done
fi
[[ -n "$UV" ]] || { echo "make-world: uv not found" >&2; exit 4; }
[[ -d "$REPO/assets/mc/textures/block" ]] || {
    echo "make-world: assets/mc is missing; run scripts/fetch-minecraft-assets.sh first" >&2; exit 3; }

export NUMBA_NUM_THREADS=8 OMP_NUM_THREADS=8
export NUMBA_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/overworld/numba"
mkdir -p "$NUMBA_CACHE_DIR"

path="$(cd "$PROJECT" && nice -n 10 "$UV" run --quiet --project "$PROJECT" python -m worldgen new "$@")"

# The bus is optional: the shell may not be running, and a CLI render should still succeed.
if [[ -x "$REPO/scripts/overworld" ]]; then
    "$REPO/scripts/overworld" event world.created "$(jq -cn --arg p "$path" '{path:$p}')" >/dev/null 2>&1 || true
fi
printf '%s\n' "$path"
