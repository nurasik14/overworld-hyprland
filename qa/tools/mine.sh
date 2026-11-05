#!/usr/bin/env bash
# qa/tools/mine.sh <mode> : real block-break on one overworld-test kitty on ws 77, through the installed shell.
cd "$(dirname "$(realpath "$0")")/../.." || exit 1
source scripts/dev-env.sh; m="${1:-day}"
find_test() { hyprctl clients -j | jq -r '[.[]|select(.class=="overworld-test")][0] | "\(.address // "") \(.pid // "")"'; }
hyprctl dispatch exec "[workspace 77 silent] kitty --class overworld-test -o background=#2a8f3a -e sleep 120" >/dev/null
addr=""; for _ in $(seq 1 50); do read -r addr pid < <(find_test); [[ -n "$addr" ]] && break; sleep 0.1; done
[[ -n "$addr" ]] || { echo "no test window"; exit 1; }
sleep 0.8; hyprctl clients -j | jq -c '.[]|select(.class=="overworld-test")|{at,size,floating,workspace:.workspace.id}'
timeout 3 qs -c overworld ipc call interact status
DEVSHOT_SETTLE=0.32 scripts/dev-shot.sh "qa/screenshots/qa-28-mining-$m.png" & shot=$!
for _ in $(seq 1 200); do [[ "$(hyprctl activeworkspace -j | jq -r .id)" == 77 ]] && break; sleep 0.01; done
overworld kill "$addr"; wait $shot
sleep 0.3; timeout 3 qs -c overworld ipc call interact status; hyprctl clients -j | jq -r '[.[]|select(.class=="overworld-test")]|length'
timeout 3 qs -c overworld ipc call chat log 3
