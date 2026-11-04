#!/usr/bin/env bash
# Report which installed fonts cover every character of a string.
# Usage: tokens/check-glyphs.sh "薬屋" ["Font Family" ...]
# Without font args, checks the theme's CJK fonts. Exit 1 if a requested font misses a glyph.
set -euo pipefail
str="$1"; shift || true
fonts=("$@"); [[ ${#fonts[@]} -eq 0 ]] && fonts=("Ma Shan Zheng" "ZCOOL XiaoWei" "LXGW WenKai" "Yuji Syuku" "Shippori Mincho B1" "Long Cang" "Noto Serif CJK SC")
rc=0
for f in "${fonts[@]}"; do
  missing=""
  while IFS= read -r -n1 ch; do
    [[ -z "$ch" ]] && continue
    cp=$(printf '%x' "'$ch")
    if ! fc-list ":family=$f:charset=$cp" family | grep -q .; then missing+="$ch"; fi
  done <<<"$str"
  if [[ -z "$missing" ]]; then echo "OK      $f"; else echo "MISSING $f: $missing"; rc=1; fi
done
exit $rc
