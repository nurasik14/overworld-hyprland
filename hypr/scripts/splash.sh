#!/usr/bin/env bash
# splash.sh — the yellow title-screen line for hyprlock: one entry of quotes/splashes.json, seasonal ones only in season.
# The line is picked from the current 10-minute window, not at random: the text and its hard shadow are two labels, each
# running this script, and they must agree. Long lines get a smaller Pango size, as the game scales its splash to fit.
set -eu
REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd -P)"
S="$REPO/quotes/splashes.json"

line=""
if [[ -r "$S" ]] && command -v jq >/dev/null 2>&1; then
    line="$(jq -r --arg d "$(date +%m-%d)" --argjson w "$(( $(date +%s) / 600 ))" '
        [ .splashes[]
          | select((.seasonal // null) as $s
                   | $s == null
                     or (if $s.from <= $s.to then ($d >= $s.from and $d <= $s.to)
                         else ($d >= $s.from or $d <= $s.to) end))
          | .text ]
        | .[($w * 2654435761) % length]' "$S" 2>/dev/null || true)"
fi
[[ -n "$line" ]] || line="Press Enter!"
esc="$(printf '%s' "$line" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
n="${#line}"
if   (( n <= 16 )); then printf '%s\n' "$esc"
elif (( n <= 30 )); then printf '<span size="75%%">%s</span>\n' "$esc"
else                     printf '<span size="60%%">%s</span>\n' "$esc"; fi
