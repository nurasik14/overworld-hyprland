#!/usr/bin/env bash
# quote.sh — one random line from quotes/quotes.json, Pango-escaped and word-wrapped for hyprlock.
#   quote.sh [width]   width in characters (default 58). Output: “text” (wrapped) + a smaller attribution line.
# Never fabricates: if the file is missing or jq is absent it prints the user's own line.
set -eu
REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd -P)"
Q="$REPO/quotes/quotes.json"
W="${1:-58}"

esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

text=""; attr=""
if [[ -r "$Q" ]] && command -v jq >/dev/null 2>&1; then
    line="$(jq -r '.[] | "\(.text)\t\(.attribution // "")"' "$Q" 2>/dev/null | shuf -n1 || true)"
    text="${line%%$'\t'*}"; attr="${line#*$'\t'}"
    [[ "$attr" == "$line" ]] && attr=""
fi
[[ -n "$text" ]] || { text="Do things out of love, not for love."; attr=""; }

printf '“%s”\n' "$text" | fold -s -w "$W" | sed 's/ *$//' | esc
if [[ -n "$attr" ]]; then
    printf '<span size="small" alpha="70%%">— %s</span>\n' "$(printf '%s' "$attr" | esc)"
fi
