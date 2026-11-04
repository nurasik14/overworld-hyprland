#!/usr/bin/env bash
# apps/kvantum/build.sh — build apps/kvantum/Overworld{Light,Dark}/ by recolouring Kvantum's flat built-ins.
#   OverworldLight ← /usr/share/Kvantum/KvFlatLight   OverworldDark ← /usr/share/Kvantum/KvFlat
# Every hex in the source .kvconfig/.svg is replaced through the mapping table below (documented in docs/APPS.md).
# Deterministic; re-run after a tokens change. Output is committed so install.sh does not need /usr/share/Kvantum.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="${KVANTUM_SRC:-/usr/share/Kvantum}"

recolour() {   # recolour <SrcTheme> <DstTheme> <map...>  (map = "#old=#new", case-insensitive match)
  local s="$1" d="$2"; shift 2
  [[ -d "$src/$s" ]] || { echo "missing $src/$s" >&2; return 1; }
  rm -rf "$here/$d"; mkdir -p "$here/$d"
  cp "$src/$s/$s.svg" "$here/$d/$d.svg"
  cp "$src/$s/$s.kvconfig" "$here/$d/$d.kvconfig"
  local m old new
  local sedargs=()
  for m in "$@"; do old="${m%%=*}"; new="${m##*=}"; sedargs+=(-e "s/${old}/${new}/Ig"); done
  sed -i "${sedargs[@]}" "$here/$d/$d.svg" "$here/$d/$d.kvconfig"
  sed -i -E "s/^comment=.*/comment=Overworld Hyprland — ${d/Overworld/} (recoloured $s)/" "$here/$d/$d.kvconfig"
  echo "built $d ($(grep -oE '#[0-9a-fA-F]{6}' "$here/$d/$d.svg" | sort -u | wc -l) distinct colours in svg)"
}

# ---- LIGHT (Overworld 薬屋): KvFlatLight blue → celadon, greys → paper/ink -----------------------------
recolour KvFlatLight OverworldLight \
  '#2d82ad=#376a4e' '#3daee9=#7eba8f' '#39ace9=#7eba8f' '#2f8ab7=#376a4e' '#2c80aa=#376a4e' '#215f7f=#2f6a5e' \
  '#1ea1e6=#7eba8f' '#58acff=#7eba8f' '#77a8c9=#9fc7a9' '#41c3ff=#7eba8f' '#7deaff=#f6f0e2' '#2b7ea8=#376a4e' \
  '#194b64=#2a2622' '#0057ae=#3a6480' '#452886=#8e4a5c' '#b74aff=#8e4a5c' '#838c95=#857b6e' \
  '#fcfcfc=#f3ecdc' '#f3f3f3=#f7f2e6' '#f0f0f0=#efe6d2' '#ececec=#e9dfc9' '#ebebeb=#e9dfc9' '#eaeaeb=#efe6d2' \
  '#e1dcd7=#e6dcc6' '#d9d9d9=#d9cdb2' '#d2d2d2=#d9cdb2' '#bebebe=#b8ab92' '#b4b4b4=#b0a48f' '#a0a0a0=#9a8f7b' \
  '#969696=#857b6e' '#7b7b7b=#6b635a' '#6e6e6e=#5c554b' '#5a5a5a=#3d3832' '#4b4b4b=#3d3832' '#323232=#2a2622' '#2b2b2b=#2a2622'

# ---- DARK (Inner Palace 后宫): KvFlat blue → celadon-lit, greys → lacquer/cream ---------------------------
recolour KvFlat OverworldDark \
  '#3daee9=#7fc19a' '#1689c6=#4a7a51' '#1376ab=#4a7a51' '#147cb4=#4a7a51' '#5abff4=#9fd3b3' '#395e97=#2f6a5e' \
  '#3f67a5=#7fc19a' '#2e4c7a=#4a7a51' '#7ddcff=#15110e' '#2eb8e6=#7aa3c2' '#ff6666=#b57a8c' \
  '#282828=#1e1915' '#2e2e2e=#1c1714' '#1e1e1e=#15110e' '#171717=#0f0c0a' '#2b2b2b=#1e1915' '#383838=#262019' \
  '#3c3c3c=#2a231c' '#3d3d3e=#1c1714' '#464646=#33291f' '#4b4b4b=#33291f' '#555555=#2a231c' '#5a5a5a=#4a3f33' \
  '#5f5f5f=#4a3f33' '#626262=#4a3f33' '#646464=#4a3f33' '#6e6e6e=#7d7262' '#737373=#7d7262' '#787878=#7d7262' \
  '#7d7d7d=#7d7262' '#828282=#a89c86' '#a0a0a0=#a89c86' '#e6e6e6=#eadfc7'

# text colours in the dark kvconfig are named (white/black) in KvFlat; make sure the highlight text is lacquer
sed -i -E 's/^text\.focus\.color=.*/text.focus.color=#15110e/; s/=white$/=#eadfc7/' "$here/OverworldDark/OverworldDark.kvconfig"
sed -i -E 's/=black$/=#2a2622/' "$here/OverworldLight/OverworldLight.kvconfig"
echo "done"
