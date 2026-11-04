#!/usr/bin/env bash
# Overworld Hyprland — reproducible texture + seal generator (ImageMagick 7 `magick`).
# Output: assets/pd/textures/*.png, assets/pd/seals/*.{png,svg}. Everything is procedurally generated
# (noise + blur + text); nothing is derived from external imagery. Credited as "generated" in assets/CREDITS.md.
#
# Usage: tokens/make-textures.sh [--seed N]      (default seed 20261029; same seed ⇒ identical pixels)
#        SKIP_BIG=1 tokens/make-textures.sh       (skip the 1920x1080 sheets, ~10 s each)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEX="$ROOT/assets/pd/textures"
SEALS="$ROOT/assets/pd/seals"
SEED=20261029
if [[ "${1:-}" == "--seed" ]]; then SEED="$2"; fi
mkdir -p "$TEX" "$SEALS"
export MAGICK_OCL_DEVICE=OFF

PAPER="#f3ecdc"    # tokens light.surface
LACQUER="#1c1714"  # tokens dark.bg1
VERMILION="#b02f2a"
FONT_SC="Ma-Shan-Zheng-Regular"   # Simplified-Chinese brush: 猫 印 药 …  (NO 薬 / kana)
FONT_JP="Yuji-Syuku-Regular"      # Japanese brush: 薬 屋 の …
# (grep -q would SIGPIPE magick under pipefail; capture instead)
FONTS="$(magick -list font 2>/dev/null || true)"
for f in "$FONT_SC" "$FONT_JP"; do
  grep -q "Font: $f$" <<<"$FONTS" || { echo "font $f not found (magick -list font)"; exit 1; }
done

# ---------------------------------------------------------------- paper
# Rice paper (xuan): smooth cream + soft mottling + sparse fibres at three angles + fine grain.
# Two outputs: a neutral grain (mean gray50, sd ≈ 16/255 — for Multiply/Overlay at 15–30 % by other consumers)
# and the tinted sheet (mean = paper tone, sd ≈ 8/255 — QML draws this one; opacity only scales the grain).
paper() { # paper <WxH> <seed> <out> <neutral-grain-out>
  local sz="$1" s="$2" out="$3" grain="$4"
  magick -size "$sz" xc:gray50 -virtual-pixel tile \
    \( +clone -seed "$s" +noise Gaussian -colorspace gray -blur 0x14 -auto-level -evaluate multiply 0.12 -evaluate add 44% \) -compose Blend -define compose:args=100 -composite \
    \( -size "$sz" xc:black -colorspace gray -virtual-pixel tile -seed "$((s+1))" +noise Random -threshold 99.65% -motion-blur 0x22+25 -auto-level -evaluate multiply 0.5 -blur 0x0.3 \) -compose Screen -composite \
    \( -size "$sz" xc:black -colorspace gray -virtual-pixel tile -seed "$((s+2))" +noise Random -threshold 99.7% -motion-blur 0x16-48 -auto-level -evaluate multiply 0.42 -blur 0x0.3 -negate \) -compose Multiply -composite \
    \( -size "$sz" xc:black -colorspace gray -virtual-pixel tile -seed "$((s+3))" +noise Random -threshold 99.75% -motion-blur 0x30+80 -auto-level -evaluate multiply 0.42 -blur 0x0.3 \) -compose Screen -composite \
    \( -size "$sz" xc:black -colorspace gray -virtual-pixel tile -seed "$((s+4))" +noise Random -threshold 99.8% -motion-blur 0x12+5 -auto-level -evaluate multiply 0.35 -blur 0x0.3 -negate \) -compose Multiply -composite \
    \( -size "$sz" xc:gray50 -seed "$((s+5))" -attenuate 0.35 +noise Gaussian -colorspace gray -blur 0x0.5 \) -compose Blend -define compose:args=30 -composite \
    -level 5%,95% -colorspace sRGB -depth 8 -strip "$grain"
  # tinted sheet: HardLight keeps the mean at the paper tone (gray50 is neutral) and carries the grain as ±sd
  magick -size "$sz" xc:"$PAPER" "$grain" -compose HardLight -composite -depth 8 -strip "$out"
}
# Lacquered wood: long horizontal grain + slow tonal drift + fine grain, tinted lacquer brown.
lacquer() { # lacquer <WxH> <seed> <out> <neutral-grain-out>
  local sz="$1" s="$2" out="$3" grain="$4"
  magick -size "$sz" xc:gray50 -virtual-pixel tile \
    \( +clone -seed "$s" +noise Gaussian -colorspace gray -motion-blur 0x60+0 -auto-level -evaluate multiply 0.5 -evaluate add 25% \) -compose Blend -define compose:args=100 -composite \
    \( -size "$sz" xc:gray50 -virtual-pixel tile -seed "$((s+1))" +noise Gaussian -colorspace gray -blur 0x18 -auto-level -evaluate multiply 0.3 -evaluate add 35% \) -compose Blend -define compose:args=50 -composite \
    \( -size "$sz" xc:gray50 -virtual-pixel tile -seed "$((s+2))" +noise Gaussian -colorspace gray -motion-blur 0x14+0 -auto-level -evaluate multiply 0.5 -evaluate add 25% \) -compose Blend -define compose:args=40 -composite \
    \( -size "$sz" xc:black -colorspace gray -virtual-pixel tile -seed "$((s+3))" +noise Random -threshold 99.5% -motion-blur 0x40+0 -auto-level -evaluate multiply 0.35 -blur 0x0.4 \) -compose Screen -composite \
    \( -size "$sz" xc:gray50 -seed "$((s+4))" -attenuate 0.4 +noise Gaussian -colorspace gray -blur 0x0.4 \) -compose Blend -define compose:args=30 -composite \
    -level 15%,85% -colorspace sRGB -depth 8 -strip "$grain"
  magick -size "$sz" xc:"$LACQUER" "$grain" -compose HardLight -composite -depth 8 -strip "$out"
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [[ -z "${SKIP_BIG:-}" ]]; then
  echo "» paper.png 1920x1080";   paper   1920x1080 "$SEED"       "$TEX/paper.png"   "$TMP/g1.png"
  echo "» lacquer.png 1920x1080"; lacquer 1920x1080 "$((SEED+20))" "$TEX/lacquer.png" "$TMP/g2.png"
fi
echo "» paper-tile.png + paper-grain.png 512 (seamless: every blur runs with -virtual-pixel tile)"
paper   512x512 "$((SEED+40))" "$TEX/paper-tile.png"   "$TEX/paper-grain.png"
echo "» lacquer-tile.png + lacquer-grain.png 512"
lacquer 512x512 "$((SEED+60))" "$TEX/lacquer-tile.png" "$TEX/lacquer-grain.png"

# ---------------------------------------------------------------- masks and ink
echo "» ink-edge-mask.png 1024x1024 (alpha mask: white = opaque; torn, slightly bled edge)"
magick -size 1024x1024 xc:black -fill white -draw "rectangle 48,48 975,975" \
  \( -size 1024x1024 xc:gray50 -seed "$((SEED+80))" +noise Gaussian -colorspace gray -blur 0x6 -auto-level \) \
  -compose Displace -define compose:args=28x28 -composite \
  -seed "$((SEED+81))" -spread 3 -blur 0x1.6 -level 20%,80% -colorspace gray -depth 8 -strip "$TEX/ink-edge-mask.png"

echo "» ink-divider.png 1200x48 (transparent, black brush stroke, dry-brush streaks)"
magick -size 1200x48 xc:none -fill black \
  -draw "path 'M 18,27 C 180,15 420,31 600,21 C 800,13 1010,31 1184,23 C 1010,33 800,19 600,30 C 420,39 180,19 18,27 Z'" \
  -seed "$((SEED+90))" -spread 2 -blur 0x0.7 \
  \( +clone -alpha extract \
     \( -size 1200x48 xc:gray50 -seed "$((SEED+91))" -attenuate 2.2 +noise Gaussian -colorspace gray -motion-blur 0x40+0 -auto-level -level 15%,85% \) \
     -compose Multiply -composite -level 0%,80% \) \
  -compose CopyOpacity -composite -depth 8 -strip "$TEX/ink-divider.png"

echo "» enso.png 512x512 (transparent, black; brush ring with open gap, built in polar space)"
# Strip: x = angle, y = radius (top = centre, bottom = Rmax 250). The brush is a near-constant 50 px band
# (rows 310–360 ⇒ r ≈ 151–176) with a round entry blob and a long dry tail; streaks run along the stroke.
# The angle range -125..235 puts the gap at the upper-left (no -rotate needed; -rotate mis-centred the crop).
magick -size 1440x512 xc:none -fill black \
  -draw "path 'M 70,336 C 80,306 140,308 260,310 L 1100,312 C 1250,316 1330,326 1380,336 C 1330,346 1250,356 1100,360 L 260,360 C 140,362 80,366 70,336 Z'" \
  -seed "$((SEED+100))" -spread 3 -blur 0x1.2 \
  \( +clone -alpha extract \
     \( -size 1440x512 xc:gray50 -seed "$((SEED+101))" -attenuate 2 +noise Gaussian -colorspace gray -motion-blur 0x50+0 -auto-level -level 20%,80% \) \
     -compose Multiply -composite -level 0%,85% \) \
  -compose CopyOpacity -composite \
  -virtual-pixel transparent -distort Polar "250 0 256,256 -125,235" -crop 512x512+0+0 +repage -depth 8 -strip "$TEX/enso.png"

echo "» cream variants for dark mode (same alpha, paper-cream ink)"
magick "$TEX/ink-divider.png" -alpha set -channel RGB -fill '#eadfc7' -colorize 100% +channel -depth 8 -strip "$TEX/ink-divider-light.png"
magick "$TEX/enso.png"        -alpha set -channel RGB -fill '#eadfc7' -colorize 100% +channel -depth 8 -strip "$TEX/enso-light.png"

# ---------------------------------------------------------------- seals
seal() {   # seal <glyph> <file-stem> <magick-font>
  local glyph="$1" stem="$2" font="$3"
  echo "» seal $glyph ($font)"
  magick -size 256x256 xc:none -fill "$VERMILION" -draw "roundrectangle 14,14 241,241 6,6" \
    -seed "$((SEED+110))" -spread 3 -blur 0x0.8 -channel A -level 30%,70% +channel \
    \( -size 256x256 xc:none -font "$font" -pointsize 176 -fill white -gravity center -annotate +0+6 "$glyph" \
       -seed "$((SEED+111))" -spread 1 -blur 0x0.5 \) \
    -compose Over -composite \
    \( +clone -alpha extract -seed "$((SEED+112))" -attenuate 1.4 +noise Gaussian -blur 0x0.6 -level 15%,85% \) \
    -compose CopyOpacity -composite -depth 8 -strip "$SEALS/seal-$stem.png"
  local family; family="$(grep -A1 "Font: $font$" <<<"$FONTS" | sed -n 's/^ *family: //p')"
  cat > "$SEALS/seal-$stem.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <!-- Overworld seal: generated by tokens/make-textures.sh -->
  <rect x="14" y="14" width="228" height="228" rx="6" fill="$VERMILION"/>
  <text x="128" y="134" text-anchor="middle" dominant-baseline="central" font-family="$family" font-size="176" fill="#ffffff">$glyph</text>
</svg>
SVG
}
seal "薬" "薬" "$FONT_JP"   # Japanese 薬 only exists in Yuji Syuku / Shippori / LXGW; Ma Shan Zheng lacks it
seal "药" "药" "$FONT_SC"   # Simplified twin, same brush as the other seals
seal "猫" "猫" "$FONT_SC"
seal "印" "印" "$FONT_SC"
echo "done:"; ls -la "$TEX" "$SEALS"
