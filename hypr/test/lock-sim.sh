#!/usr/bin/env bash
# lock-sim.sh [day|night] [out.png] — composes what hypr/hyprlock.conf should look like with ImageMagick, same positions and
# same fonts, to judge the layout. hyprlock cannot be dry-run without locking the session, so this is NOT hyprlock's output.
set -eu
REPO="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd -P)"
t="${1:-day}"; out="${2:-$REPO/qa/screenshots/hyprland-engineer-lock-sim-$t.png}"
F="$REPO/assets/fonts/OverworldMojangles-Regular.ttf"
bash "$REPO/hypr/scripts/lock-assets.sh"
P="${XDG_CACHE_HOME:-$HOME/.cache}/overworld/lock"
raw="$("$REPO/hypr/scripts/splash.sh")"
splash="$(sed -e 's/<[^>]*>//g' <<<"$raw")"
spx=32; case "$raw" in *75%*) spx=24 ;; *60%*) spx=20 ;; esac
args=("$REPO/assets/renders/lock-$t.png" -blur 0x2 -modulate 90 "$P/wordmark.png" -gravity north -geometry +0+90 -composite)
txt() { # txt <gravity> <text> <px> <x> <y> <colour> [rotate]
    args+=( '(' -background none -font "$F" -pointsize "$3" -fill "$6" "label:$2" -rotate "${7:-0}" ')' -gravity "$1" -geometry "$(printf '%+d%+d' "$4" "$5")" -composite )
}
txt north "$splash" "$spx" 473 189 '#3f3f00' -20
txt north "$splash" "$spx" 470 186 '#ffff00' -20
clock="Day $(date +%-j) · $(date +%H:%M)"
txt north "$clock" 32 3 285 '#3f3f3f'
txt north "$clock" 32 0 282 white
args+=(-fill black -stroke '#a0a0a0' -strokewidth 3 -draw 'rectangle 661,415 1259,473' -stroke none)
txt north 'Enter password' 24 0 432 '#707070'
args+=("$P/button.png" -gravity north -geometry +0+486 -composite)
txt north Singleplayer 24 3 503 '#3f3f3f'
txt north Singleplayer 24 0 500 white
txt north 'Press Enter to play · us' 16 0 566 '#e0e0e0'
txt southwest "$(date +'%A %-d %B')" 16 8 32 white
txt southwest 'Battery 100%' 16 8 8 white
txt southeast "“Redstone is just logic with extra steps.”" 16 8 8 white
magick "${args[@]}" "$out"
echo "$out"
