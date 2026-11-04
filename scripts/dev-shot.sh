#!/usr/bin/env bash
# dev-shot.sh — the ONLY way build agents take screenshots (serialised; never shows the user's windows).
#
#   scripts/dev-shot.sh <out.png> [x,y wxh | layer:<namespace> | full] [--keep-ws]
#
# Takes a global flock, remembers the current workspace, switches to the dedicated EMPTY workspace 77,
# verifies it holds no windows, waits for animations, captures with grim, then switches back.
# `layer:<ns>` crops to that layer surface's rect from `hyprctl layers -j`. Default region: full eDP-1.
# Exit 3 = workspace 77 not empty (someone's window there) → nothing captured.
set -euo pipefail
source "$(dirname "$(realpath "$0")")/dev-env.sh" >/dev/null 2>&1 || true
out="${1:?usage: dev-shot.sh <out.png> [region|layer:<ns>|full]}"; region="${2:-full}"; keep="${3:-}"
mkdir -p "$(dirname "$out")"
lock="${XDG_RUNTIME_DIR:-/tmp}/overworld-devshot.lock"
exec 9>"$lock"; flock -w 120 9 || { echo "dev-shot: lock timeout" >&2; exit 4; }
WS=77
prev="$(hyprctl activeworkspace -j | jq -r .id)"
[[ "$prev" == "$WS" ]] || hyprctl dispatch workspace "$WS" >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ "$(hyprctl activeworkspace -j | jq -r .id)" == "$WS" ]] && break; sleep 0.1
done
sleep "${DEVSHOT_SETTLE:-0.6}"
nwin="$(hyprctl activeworkspace -j | jq -r .windows)"
if [[ "$nwin" != 0 ]]; then
    [[ "$prev" == "$WS" ]] || hyprctl dispatch workspace "$prev" >/dev/null
    echo "dev-shot: workspace $WS has $nwin window(s); not capturing" >&2; exit 3
fi
case "$region" in
    full) grim -o eDP-1 "$out" ;;
    layer:*) ns="${region#layer:}"
        geo="$(hyprctl layers -j | jq -r --arg ns "$ns" '[.[].levels[][] | select(.namespace==$ns)][0] | "\(.x),\(.y) \(.w)x\(.h)"')"
        [[ "$geo" != "null,null nullxnull" && -n "$geo" ]] || { echo "dev-shot: no layer $ns" >&2; hyprctl dispatch workspace "$prev" >/dev/null; exit 5; }
        grim -g "$geo" "$out" ;;
    *) grim -g "$region" "$out" ;;
esac
[[ "$keep" == --keep-ws || "$prev" == "$WS" ]] || hyprctl dispatch workspace "$prev" >/dev/null
echo "$out"
