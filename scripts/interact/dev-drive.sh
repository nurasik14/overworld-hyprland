#!/usr/bin/env bash
# dev-drive.sh <settle-seconds> <out.png> <region|full> <kill|place|killclass|none>
#   Reproducible capture of a timed effect: opens ONE test window (class overworld-test, kitty, on the empty workspace 77, silent), starts
#   scripts/dev-shot.sh in the background (it takes the screenshot lock, switches to 77, waits <settle>, shoots, switches back), fires the
#   Interact IPC the moment 77 is on screen, then closes the test window by PID. Needs dev-preview.sh start first.
#   Slow it down for a mid-sequence shot: interact.break_ms in $OW_FXI_DIR/config.json (e.g. 3000) or OW_INTERACT_SLOWMO for particles.
#   KARGS="-o background=#2a8f3a"  extra kitty options so the sampled colours are recognisable.   AFTER=<s>  wait before cleanup.
set -u
repo="$(realpath "$(dirname "$(realpath "$0")")/../..")"
source "$repo/scripts/dev-env.sh" >/dev/null 2>&1; cd "$repo"
settle="${1:?settle}"; out="${2:?out.png}"; region="${3:-full}"; action="${4:-none}"
ipc() { "$repo/scripts/interact/dev-preview.sh" ipc "$@"; }
find_test() { hyprctl clients -j | jq -r '[.[]|select(.class=="overworld-test")][0] | "\(.address // "") \(.pid // "")"'; }
hyprctl dispatch exec "[workspace 77 silent] kitty --class overworld-test ${KARGS:-} -e sleep 600" >/dev/null
addr="" pid=""
for _ in $(seq 1 50); do read -r addr pid < <(find_test); [[ -n "$addr" ]] && break; sleep 0.1; done
[[ -n "$addr" ]] || { echo "no test window appeared" >&2; exit 1; }
sleep 0.4
DEVSHOT_SETTLE="$settle" scripts/dev-shot.sh "$out" "$region" >"${OW_FXI_DIR:-/tmp/ow-fxi}/devshot.log" 2>&1 &
shot=$!
for _ in $(seq 1 100); do [[ "$(hyprctl activeworkspace -j | jq -r .id)" == 77 ]] && break; sleep 0.02; done
case "$action" in
    kill) ipc killAddress "$addr" ;;
    killclass) ipc killClass overworld-test ;;
    place) ipc placeAddress "$addr" ;;
esac
wait $shot; cat "${OW_FXI_DIR:-/tmp/ow-fxi}/devshot.log"
sleep "${AFTER:-1.0}"
ipc status
read -r _ pid2 < <(find_test)
[[ -n "$pid2" ]] && kill "$pid2" 2>/dev/null && echo "closed leftover test window (pid $pid2)"
exit 0
