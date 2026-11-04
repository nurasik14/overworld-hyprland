#!/usr/bin/env bash
# apps/kvantum/build.sh — (re)generate apps/kvantum/OverworldDay/ and OverworldNight/ (Minecraft-GUI Kvantum themes).
# Colours come from tokens/out/light/palette.json (Day) and tokens/out/dark/palette.json (Night); the SVG + kvconfig
# are drawn by build.py (python3 stdlib only). Idempotent; output is committed so install.sh needs nothing at install time.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rm -rf "$here/OverworldLight" "$here/OverworldDark"   # Apothecary-era leftovers
exec python3 "$here/build.py" "$@"
