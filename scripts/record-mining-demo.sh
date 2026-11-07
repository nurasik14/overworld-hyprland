#!/usr/bin/env bash
# record-mining-demo.sh — record the block-break window close for the README (docs/screenshots/00-mining.{webp,gif,mp4}).
#
#   scripts/record-mining-demo.sh            # ~10 s: opens a demo kitty on workspace 77, mines it, comes back
#
# Needs Overworld ON, wf-recorder, ffmpeg. It switches to the empty workspace 77 for a few seconds and back; nothing
# else on the desktop is touched. The demo window runs fastfetch so the fragments have real colours.
set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
REPO="$(cd "$(dirname "$(realpath "$0")")/.." && pwd -P)"
source "$REPO/scripts/dev-env.sh" >/dev/null 2>&1 || true
OUT="$REPO/docs/screenshots"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WS=77; CLS=overworld-test-demo
for c in wf-recorder ffmpeg hyprctl jq; do command -v "$c" >/dev/null || { echo "need $c" >&2; exit 1; }; done
[[ -e "$HOME/.config/overworld/enabled" ]] || { echo "turn Overworld on first (overworld on)" >&2; exit 1; }

prev="$(hyprctl activeworkspace -j | jq -r .id)"
back() { hyprctl dispatch workspace "$prev" >/dev/null; }
trap 'back; rm -rf "$TMP"' EXIT

hyprctl dispatch exec "[workspace $WS silent; float; size 900 560; center] kitty --class $CLS -e sh -c 'fastfetch; sleep 30'" >/dev/null
addr=""
for _ in $(seq 50); do
    addr="$(hyprctl clients -j | jq -r --arg c "$CLS" '[.[] | select(.class==$c)][0].address // empty')"; [[ -n "$addr" ]] && break; sleep 0.1
done
[[ -n "$addr" ]] || { echo "demo window did not open" >&2; exit 1; }
hyprctl dispatch workspace "$WS" >/dev/null
hyprctl dispatch focuswindow "address:$addr" >/dev/null
sleep 1.2                                            # fastfetch drawn, open animation over
read -r x y w h < <(hyprctl clients -j | jq -r --arg a "$addr" '.[] | select(.address==$a) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"')
pad=140; rx=$(( x - pad < 0 ? 0 : x - pad )); ry=$(( y - pad < 0 ? 0 : y - pad ))
rw=$(( w + 2*pad )); rh=$(( h + 2*pad ))
wf-recorder -g "$rx,$ry ${rw}x${rh}" -r 30 -f "$TMP/raw.mp4" >/dev/null 2>&1 &
rec=$!
sleep 0.8
overworld kill "$addr" || hyprctl dispatch closewindow "address:$addr" >/dev/null
sleep 1.6                                            # cracks + break + fragment burst
kill -INT "$rec"; wait "$rec" 2>/dev/null || true
back; trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT"
ffmpeg -loglevel error -y -i "$TMP/raw.mp4" -vf "scale=720:-2:flags=lanczos" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT/00-mining.mp4"
ffmpeg -loglevel error -y -i "$TMP/raw.mp4" -vf "fps=20,scale=720:-2:flags=lanczos" -loop 0 -quality 80 -c:v libwebp_anim "$OUT/00-mining.webp"
ffmpeg -loglevel error -y -i "$TMP/raw.mp4" -vf "fps=15,scale=560:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer" -loop 0 "$OUT/00-mining.gif"
ls -la "$OUT"/00-mining.*
