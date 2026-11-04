#!/usr/bin/env bash
# wallpaper-seed.sh — prints the seed of the current wallpaper world (for /seed).
# Reads $OW_STATE_DIR/wallpaper-<mode> (path of the current wallpaper), looks the file up in assets/wallpapers/index.json
# (field seed / world.seed), and falls back to a stable number derived from the file name.
state="${OW_STATE_DIR:-$HOME/.config/overworld}"; repo="${OW_REPO:-$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")}"
mode="$(head -n1 "$state/mode" 2>/dev/null || echo dark)"
wp="$(head -n1 "$state/wallpaper-$mode" 2>/dev/null)"
[[ -n "$wp" ]] || { wp="$(ls -1 "$repo/assets/wallpapers/$mode" 2>/dev/null | head -n1)"; }
[[ -n "$wp" ]] || exit 1
base="$(basename "$wp")"; stem="${base%.*}"
idx="$repo/assets/wallpapers/index.json"
if [[ -r "$idx" ]] && command -v jq >/dev/null; then
    seed="$(jq -r --arg b "$base" --arg s "$stem" '
        [ (if type=="array" then .[] else (.worlds // .wallpapers // .items // [])[] end)
          | select((.file // .path // .name // .id // "" | tostring | split("/") | last) as $f | ($f == $b or ($f | sub("\\.[a-z0-9]+$";"")) == $s))
          | (.seed // .world.seed // empty) ][0] // empty' "$idx" 2>/dev/null)"
    [[ -n "$seed" ]] && { echo "$seed"; exit 0; }
fi
echo $(( $(printf %s "$stem" | cksum | cut -d' ' -f1) % 2147483647 ))
