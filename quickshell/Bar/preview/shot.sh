#!/usr/bin/env bash
# shot.sh <surface> <light|dark> [region] [name-suffix]   start the preview with one surface, screenshot it through dev-shot.sh, stop it.
# Env passes through (OW_FAKE_STATS, OW_GUI …). Log in /tmp/qs-core-<surface>-<mode>.log. Only kills the PID it started.
set -u
repo="$(cd "$(dirname "$(realpath "$0")")/../../.." && pwd)"
surface="$1"; mode="$2"; region="${3:-full}"; suffix="${4:-}"
source "$repo/scripts/dev-env.sh"
log="/tmp/qs-core-$surface-$mode$suffix.log"
OW_STATE_DIR=/tmp/qs-core-state OW_EVENTS_DIR=/tmp/qs-core-bus/overworld OW_PREVIEW=1 OW_SOUND_DRYRUN=1 OW_MODE="$mode" OW_SURFACE="$surface" qs -p "$repo/quickshell/Bar/preview" >"$log" 2>&1 &
pid=$!
sleep "${SHOT_WAIT:-2.2}"
DEVSHOT_SETTLE="${DEVSHOT_SETTLE:-0.35}" "$repo/scripts/dev-shot.sh" "$repo/qa/screenshots/qs-core-$surface-$mode$suffix.png" "$region"
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
grep -E "WARN|ERROR" "$log" | grep -v -E "notification|Registration will|swappy|yourusername|buffer size|qt.svg" | head -"${SHOT_LOGLINES:-14}"
exit 0
