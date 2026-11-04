#!/usr/bin/env bash
# capture-palette.sh X Y W H [COLS ROWS]
#   Grabs the screen rectangle (grim, in memory only — nothing is written to disk) and prints COLS*ROWS point-sampled
#   colours, one "rrggbb" per line, row by row. The block-break close uses them as the colours of the break particles
#   ("fragments of the window's own pixels"). Exit 1 and no output when grim/magick are missing or the capture fails.
set -u
x="${1:?usage: capture-palette.sh X Y W H [COLS ROWS]}"; y="${2:?}"; w="${3:?}"; h="${4:?}"
cols="${5:-12}"; rows="${6:-8}"
command -v grim >/dev/null && command -v magick >/dev/null || exit 1
[[ -n "${WAYLAND_DISPLAY:-}" ]] || source "$(dirname "$(realpath "$0")")/../dev-env.sh" >/dev/null 2>&1 || true
(( w >= 2 && h >= 2 )) || exit 1
grim -g "${x},${y} ${w}x${h}" -t ppm - 2>/dev/null \
  | magick ppm:- -sample "${cols}x${rows}!" -depth 8 txt:- 2>/dev/null \
  | awk 'NR > 1 && match($0, /#[0-9A-Fa-f]{6}/) { print tolower(substr($0, RSTART + 1, 6)) }'
exit 0
