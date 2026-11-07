#!/usr/bin/env bash
# Does typing survive the shell going away?  Private offscreen instance + temp file, nothing live is touched.
#   bash tests/notes-quit.test.sh
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home/.config/overworld"; echo '{"sounds":false}' >"$T/home/.config/overworld/config.json"
fail=0
run() {                         # run clean|reload|wait
    local how="$1" f="$T/$1.json" log="$T/$1.log" pid
    HYPR_NOTES_QUIET=1 HOME="$T/home" HYPR_NOTES_FILE="$f" OW_NOTES_QUIT="$how" OW_EVENTS_DIR="$T/ev" OW_STATE_DIR="$T/home/.config/overworld" QT_QPA_PLATFORM=offscreen \
        qs -p "$R/quickshell/Widgets/preview/notes-quit-test.qml" >"$log" 2>&1 &
    pid=$!
    for _ in $(seq 1 40); do grep -q typed "$log" && break; sleep 0.1; done
    if [[ "$how" == wait ]]; then
        HOME="$T/home" qs ipc --pid "$pid" call notes flush >/dev/null 2>&1
        kill -TERM "$pid" 2>/dev/null
    elif [[ "$how" == reload ]]; then
        sleep 1.5; kill -TERM "$pid" 2>/dev/null
    fi
    wait "$pid" 2>/dev/null
    for _ in $(seq 1 30); do [[ "$(jq -r '.sheets | length' "$f" 2>/dev/null)" == 2 ]] && break; sleep 0.1; done
    local texts; texts="$(jq -r '.sheets | map(.text) | join("|")' "$f" 2>/dev/null)"
    case "$texts" in
        *"typed $how"*"queued too"*|*"queued too"*"typed $how"*) echo "PASS $how: draft and queue both on disk [$texts]" ;;
        *) echo "FAIL $how: [$texts]"; fail=1 ;;
    esac
}
run clean
run reload
run wait
exit $fail
