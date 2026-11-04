#!/usr/bin/env bash
# preview/shot.sh <name> [light|dark] [region]
#   Starts the widget-layer preview (`qs -p quickshell/Widgets/preview`, pinned to Day/Night with OW_MODE), waits for it,
#   takes qa/screenshots/qs-widgets-<name>.png with scripts/dev-shot.sh (the only allowed capture path), then stops
#   ONLY the preview process it started.  Retries while another agent's test window occupies workspace 77.
#   Env: OW_WIDGETS_OPACITY (default unset = config value 0.72) · OW_WIDGETS_DEMO=1 mocked track when no player runs ·
#        OW_WIDGETS_LAYER=top (default here: other agents' test windows would cover a bottom layer; the live layer is `bottom`)
#        WAIT=<s> startup wait (default 6)
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
NAME="${1:-wip}"; MODE="${2:-light}"; REGION="${3:-full}"
source "$REPO/scripts/dev-env.sh"
LOG="${TMPDIR:-/tmp}/qs-widgets-preview.log"
( cd "$REPO" && exec env OW_MODE="$MODE" OW_WIDGETS_LAYER="${OW_WIDGETS_LAYER:-top}" qs -p "$REPO/quickshell/Widgets/preview" > "$LOG" 2>&1 ) &
PID=$!                       # the subshell execs into qs, so this is qs's own PID
trap 'kill "$PID" 2>/dev/null' EXIT
sleep "${WAIT:-6}"
for _ in $(seq 1 30); do
    if out="$("$REPO/scripts/dev-shot.sh" "$REPO/qa/screenshots/qs-widgets-$NAME.png" "$REGION" 2>&1)"; then echo "$out" | tail -1; break; fi
    sleep 8
done
echo "--- qs log (non-INFO lines):"
grep -v "^\s*INFO" "$LOG" | grep -v "playerctld" || echo "(clean)"
