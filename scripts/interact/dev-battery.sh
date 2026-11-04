#!/usr/bin/env bash
# dev-battery.sh "<label>" '<OW_FAKE_STATS json>' [VAR=value …]  — one throw-away preview run of the death/hurt logic; prints what it decided.
#   rm -f /tmp/ow-fxi/overworld/battery-cycle.json first for a clean cycle (the flag file is the "once per discharge" memory).
#   Example: dev-battery.sh "4% discharging" '{"battery":4,"charging":false,"uptime":3.5}'
repo="$(realpath "$(dirname "$(realpath "$0")")/../..")"; d="${OW_FXI_DIR:-/tmp/ow-fxi}"; mkdir -p "$d/overworld"
source "$repo/scripts/dev-env.sh" >/dev/null 2>&1; cd "$repo"
label="$1"; stats="$2"; shift 2
export OW_PREVIEW=1 OW_CONFIG="${OW_CONFIG:-$d/config.json}" OW_EVENTS_DIR="$d/overworld" OW_SOUND_DRYRUN=1 OW_INTERACT_DRYRUN=1 OW_INTERACT_DEBUG=1 OW_FAKE_STATS="$stats"
for kv in "$@"; do export "$kv"; done
setsid qs -p quickshell/Interact/preview > "$d/bat.log" 2>&1 &
pid=$!; sleep 4
echo "== $label  ($stats $*)"
sed 's/\x1b\[[0-9;]*m//g' "$d/bat.log" | grep -a "interact \|WARN\|ERROR" | tail -6
echo "  status: $(qs -p quickshell/Interact/preview ipc call interact status 2>&1)"
echo "  flag file: $(cat "$d/overworld/battery-cycle.json" 2>/dev/null || echo none)"
kill $pid 2>/dev/null; sleep 0.7
