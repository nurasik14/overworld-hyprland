#!/usr/bin/env bash
# dev-preview.sh start|stop|status|ipc <fn> [args]   — the Interact preview harness, safe to run on top of the live desktop.
#   start   qs -p quickshell/Interact/preview with a private event bus, dry-run sounds/lock, config from $OW_FXI_DIR/config.json
#   Env passthrough for tests: OW_FAKE_STATS='{"battery":4,"charging":false,"uptime":3.5}'  OW_GAMEMODE=creative|adventure
#                              OW_INTERACT_SLOWMO=3 (particles 3× slower)  OW_INTERACT_DEBUG=1 (log every sound id / decision)
#   Everything lives in $OW_FXI_DIR (default /tmp/ow-fxi): config.json, overworld/ (event bus), preview.log, preview.pid
set -u
repo="$(realpath "$(dirname "$(realpath "$0")")/../..")"
d="${OW_FXI_DIR:-/tmp/ow-fxi}"; mkdir -p "$d/overworld"
source "$repo/scripts/dev-env.sh" >/dev/null 2>&1
[[ -f "$d/config.json" ]] || echo '{"sounds": false, "interact": {"break_ms": 450}}' > "$d/config.json"
case "${1:-status}" in
    start)
        [[ -f "$d/preview.pid" ]] && kill "$(cat "$d/preview.pid")" 2>/dev/null && sleep 0.8
        cd "$repo"
        OW_PREVIEW=1 OW_CONFIG="${OW_CONFIG:-$d/config.json}" OW_EVENTS_DIR="$d/overworld" OW_SOUND_DRYRUN=1 OW_INTERACT_DRYRUN=1 \
            setsid qs -p quickshell/Interact/preview > "$d/preview.log" 2>&1 &
        echo $! > "$d/preview.pid"; sleep 3; sed 's/\x1b\[[0-9;]*m//g' "$d/preview.log" | tail -3 ;;
    stop)   [[ -f "$d/preview.pid" ]] && kill "$(cat "$d/preview.pid")" 2>/dev/null; rm -f "$d/preview.pid" ;;
    ipc)    shift; cd "$repo" && qs -p quickshell/Interact/preview ipc call interact "$@" ;;
    status) cd "$repo" && qs -p quickshell/Interact/preview ipc call interact status ;;
    *) echo "usage: dev-preview.sh start|stop|status|ipc <fn> [args]" >&2; exit 2 ;;
esac
