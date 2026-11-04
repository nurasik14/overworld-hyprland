#!/usr/bin/env bash
# fetch-minecraft-sounds.sh — download the Minecraft brewing sounds used by the 煎 Brew timer.
#
#   brew finished  → block/brewing_stand/brew1.ogg, brew2.ogg   (the brewing stand's "potion ready" bubble)
#   rest finished  → random/drink.ogg                            (drinking the potion)
#
# The sounds are © Mojang Studios and are NOT part of this repository: they are fetched from Mojang's own
# asset servers (the same files the game launcher downloads) into assets/sounds/minecraft/, which is gitignored.
# Without them the timer falls back to the theme's own assets/sounds/brew-done.wav.
# Choose with config.json → "brew": {"sound": "minecraft" | "classic"}  (default: minecraft when present).
#
# Usage: scripts/fetch-minecraft-sounds.sh [--force]
set -euo pipefail

REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd -P)"
OUT="$REPO/assets/sounds/minecraft"
MANIFEST="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
OBJECTS="https://resources.download.minecraft.net"
WANT=(
    "minecraft/sounds/block/brewing_stand/brew1.ogg"
    "minecraft/sounds/block/brewing_stand/brew2.ogg"
    "minecraft/sounds/random/drink.ogg"
)

for c in curl jq sha1sum; do command -v "$c" >/dev/null || { echo "fetch-minecraft-sounds: $c is required" >&2; exit 1; }; done

if [[ "${1:-}" != --force ]]; then
    have_all=1
    for k in "${WANT[@]}"; do [[ -s "$OUT/$(basename "$k")" ]] || have_all=0; done
    (( have_all )) && { echo "fetch-minecraft-sounds: already present in $OUT (--force to re-download)"; exit 0; }
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsS -m 30 "$MANIFEST" -o "$tmp/manifest.json"
version="$(jq -r '.latest.release' "$tmp/manifest.json")"
curl -fsS -m 30 "$(jq -r --arg v "$version" '.versions[] | select(.id == $v) | .url' "$tmp/manifest.json")" -o "$tmp/version.json"
curl -fsS -m 60 "$(jq -r '.assetIndex.url' "$tmp/version.json")" -o "$tmp/index.json"

mkdir -p "$OUT"
for k in "${WANT[@]}"; do
    hash="$(jq -r --arg k "$k" '.objects[$k].hash // empty' "$tmp/index.json")"
    [[ -n "$hash" ]] || { echo "fetch-minecraft-sounds: $k not in the $version asset index" >&2; exit 1; }
    curl -fsS -m 60 "$OBJECTS/${hash:0:2}/$hash" -o "$tmp/obj"
    [[ "$(sha1sum "$tmp/obj" | cut -d' ' -f1)" == "$hash" ]] || { echo "fetch-minecraft-sounds: checksum mismatch for $k" >&2; exit 1; }
    mv "$tmp/obj" "$OUT/$(basename "$k")"
    echo "  $(basename "$k")  ($k, Minecraft $version)"
done
echo "fetch-minecraft-sounds: saved to $OUT"
