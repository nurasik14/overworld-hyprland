#!/usr/bin/env bash
# lock-assets.sh — pieces of the title-screen lock that hyprlock cannot draw itself, in ~/.cache/overworld/lock/:
#   button.png    the Minecraft button sprite at GUI scale 3 (600x60), Mojang's if present, else our fallback art
#   wordmark.png  the OVERWORLD wordmark, the real-texture render if present, else the committed original
# Derived from Mojang's textures, so it lives in the cache and is never committed. Rebuilt only when missing or older.
set -eu
REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd -P)"
OUT="${XDG_CACHE_HOME:-$HOME/.cache}/overworld/lock"
mkdir -p "$OUT"

pick() { for f in "$@"; do [[ -r "$f" ]] && { printf '%s\n' "$f"; return 0; }; done; return 1; }

btn="$(pick "$REPO/assets/mc/textures/gui/sprites/widget/button.png" "$REPO/assets/gen/textures/gui/sprites/widget/button.png")" || btn=""
if [[ -n "$btn" && ( ! -s "$OUT/button.png" || "$btn" -nt "$OUT/button.png" ) ]] && command -v magick >/dev/null 2>&1; then
    magick "$btn" -filter point -resize 300% -define png:color-type=6 "$OUT/button.png"
fi
word="$(pick "$REPO/assets/renders/wordmark.png" "$REPO/assets/gen/wordmark/overworld.png")" || word=""
[[ -n "$word" ]] && ln -sfn "$word" "$OUT/wordmark.png"
exit 0
