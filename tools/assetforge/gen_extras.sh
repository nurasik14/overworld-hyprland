#!/usr/bin/env bash
# gen_extras.sh — original flat pixel-art fallbacks (ImageMagick only, no Mojang pixels) for sprites the shell asks for
# that gen_icons.py / gen_textures.py do not cover, so a machine without assets/mc shows a recognisable shape instead
# of the magenta missing texture. Re-run any time: it overwrites assets/gen/{icons,textures}/<name>.png.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"; gen="$(cd "$here/../../assets/gen" && pwd)"
mk() { local out="$1" size="$2"; shift 2; mkdir -p "$(dirname "$out")"
       magick -size "$size" xc:none -filter point "$@" -define png:exclude-chunk=all "$out"; }
ic() { local n="$1"; shift; mk "$gen/icons/$n.png" 16x16 "$@"; }
tx() { local n="$1" size="$2"; shift 2; mk "$gen/textures/$n.png" "$size" "$@"; }

# ---- icons (16x16)
ic potion      -fill '#9aa7b8' -draw 'rectangle 6,1 9,2' -fill '#6b4f2a' -draw 'rectangle 6,0 9,0' -fill '#9aa7b8' -draw 'rectangle 7,3 8,5' -fill '#9aa7b8' -draw 'rectangle 4,6 11,14' -fill '#d8363c' -draw 'rectangle 5,8 10,13' -fill '#f26a6e' -draw 'rectangle 5,8 6,11' -fill '#9aa7b8' -draw 'rectangle 5,14 10,14'
ic blaze_powder -fill '#f7c223' -draw 'rectangle 4,8 11,12' -fill '#e8870f' -draw 'rectangle 5,6 10,7' -fill '#fff3a0' -draw 'rectangle 6,9 8,10' -fill '#c85a0a' -draw 'rectangle 3,12 12,13' -fill '#f7c223' -draw 'rectangle 7,4 8,5'
ic brewing_stand -fill '#7d7d7d' -draw 'rectangle 2,12 13,14' -fill '#555555' -draw 'rectangle 2,14 13,14' -fill '#e0c040' -draw 'rectangle 7,2 8,11' -fill '#9aa7b8' -draw 'rectangle 2,8 4,12' -fill '#9aa7b8' -draw 'rectangle 11,8 13,12' -fill '#6fa8dc' -draw 'rectangle 3,9 3,11' -fill '#6fa8dc' -draw 'rectangle 12,9 12,11' -fill '#f7c223' -draw 'rectangle 6,1 9,2'
ic ender_chest -fill '#0e2a2c' -draw 'rectangle 1,5 14,14' -fill '#164447' -draw 'rectangle 1,5 14,7' -fill '#0a1c1e' -draw 'rectangle 1,8 14,8' -fill '#2f8f86' -draw 'rectangle 7,7 8,10' -fill '#164447' -draw 'rectangle 1,3 14,5' -fill '#0a1c1e' -draw 'rectangle 1,14 14,14'
ic golden_apple -fill '#f7c223' -draw 'rectangle 4,5 11,13' -fill '#fff3a0' -draw 'rectangle 5,6 6,8' -fill '#e8a30f' -draw 'rectangle 5,12 10,13' -fill '#f7c223' -draw 'rectangle 3,7 12,11' -fill '#6b4f2a' -draw 'rectangle 7,2 8,4' -fill '#3f9a36' -draw 'rectangle 9,2 12,3'
ic nether_star -fill '#ffffff' -draw 'rectangle 7,1 8,14' -fill '#ffffff' -draw 'rectangle 1,7 14,8' -fill '#f2f2c0' -draw 'rectangle 5,5 10,10' -fill '#ffffff' -draw 'rectangle 6,6 9,9' -fill '#d8d8a0' -draw 'rectangle 3,3 4,4' -fill '#d8d8a0' -draw 'rectangle 11,3 12,4' -fill '#d8d8a0' -draw 'rectangle 3,11 4,12' -fill '#d8d8a0' -draw 'rectangle 11,11 12,12'

# ---- block textures (16x16 flat + a few specks)
tx block/dirt 16x16 -fill '#866043' -draw 'rectangle 0,0 15,15' -fill '#6b4a30' -draw 'point 2,3' -draw 'point 9,1' -draw 'point 13,6' -draw 'point 5,10' -draw 'point 11,12' -draw 'point 1,14' -draw 'point 7,6' -fill '#9a7552' -draw 'point 4,5' -draw 'point 12,2' -draw 'point 8,13' -draw 'point 14,10'
tx block/oak_planks 16x16 -fill '#a8854f' -draw 'rectangle 0,0 15,15' -fill '#8c6c3c' -draw 'rectangle 0,3 15,3' -fill '#8c6c3c' -draw 'rectangle 0,7 15,7' -fill '#8c6c3c' -draw 'rectangle 0,11 15,11' -fill '#8c6c3c' -draw 'rectangle 0,15 15,15' -fill '#b99660' -draw 'rectangle 3,1 6,1' -fill '#b99660' -draw 'rectangle 9,5 13,5' -fill '#b99660' -draw 'rectangle 2,9 5,9' -fill '#b99660' -draw 'rectangle 8,13 12,13'
tx block/birch_planks 16x16 -fill '#c8b77a' -draw 'rectangle 0,0 15,15' -fill '#a99a63' -draw 'rectangle 0,3 15,3' -fill '#a99a63' -draw 'rectangle 0,7 15,7' -fill '#a99a63' -draw 'rectangle 0,11 15,11' -fill '#a99a63' -draw 'rectangle 0,15 15,15' -fill '#d8c98c' -draw 'rectangle 3,1 6,1' -fill '#d8c98c' -draw 'rectangle 9,5 13,5' -fill '#d8c98c' -draw 'rectangle 2,9 5,9' -fill '#d8c98c' -draw 'rectangle 8,13 12,13'
tx block/item_frame 16x16 -fill '#8a5a2b' -draw 'rectangle 0,0 15,15' -fill '#c9a066' -draw 'rectangle 2,2 13,13' -fill '#a8854f' -draw 'rectangle 3,3 12,12' -fill '#5c3a1a' -draw 'point 0,0' -draw 'point 15,0' -draw 'point 0,15' -draw 'point 15,15'
tx painting/kebab 16x16 -fill '#8a5a2b' -draw 'rectangle 0,0 15,15' -fill '#6fa8dc' -draw 'rectangle 1,1 14,8' -fill '#3f9a36' -draw 'rectangle 1,9 14,14' -fill '#f7c223' -draw 'rectangle 10,2 12,4'
tx entity/signs/oak 64x32 -fill '#a8854f' -draw 'rectangle 2,2 25,13' -fill '#8c6c3c' -draw 'rectangle 2,2 25,2' -fill '#8c6c3c' -draw 'rectangle 2,13 25,13' -fill '#6b4f2a' -draw 'rectangle 0,14 1,30' -fill '#6b4f2a' -draw 'rectangle 26,0 27,0' -fill '#8a6a3a' -draw 'rectangle 2,14 5,29'

# ---- particle: enchant glitter 8 frames (8x8 four-point sparkles growing and shrinking)
for i in 0 1 2 3 4 5 6 7; do
  case $i in 0|7) a=0;; 1|6) a=1;; 2|5) a=2;; *) a=3;; esac
  tx particle/glitter_$i 8x8 -fill '#c38bff' -draw "rectangle $((3-a/2)),$((3)) $((4+a/2)),$((4))" -draw "rectangle 3,$((3-a/2)) 4,$((4+a/2))" -fill '#ffffff' -draw 'point 3,3'
done

# ---- brewing stand GUI pieces
tx gui/sprites/container/brewing_stand/brew_progress 9x28 -fill '#8a8a8a' -draw 'rectangle 3,0 5,27' -fill '#6fa8dc' -draw 'rectangle 3,0 5,19'
tx gui/sprites/container/brewing_stand/bubbles 12x29 -fill '#bfe3ff' -draw 'point 3,26' -draw 'point 7,20' -draw 'point 4,14' -draw 'point 8,9' -draw 'point 5,3' -draw 'point 9,25'
tx gui/sprites/container/brewing_stand/fuel_length 18x4 -fill '#f7c223' -draw 'rectangle 0,0 17,3' -fill '#e8870f' -draw 'rectangle 0,3 17,3'
tx gui/container/brewing_stand 256x256 -fill '#c6c6c6' -draw 'rectangle 0,0 175,165' -fill '#ffffff' -draw 'rectangle 0,0 175,0' -draw 'rectangle 0,0 0,165' -fill '#555555' -draw 'rectangle 175,0 175,165' -draw 'rectangle 0,165 175,165'
echo "gen_extras: wrote fallbacks into $gen"
