#!/usr/bin/env bash
# Dev helper for the widget layer:  preview/shot.sh <name> [VAR=val ...]
#   (re)starts `qs -p quickshell/Widgets/preview` in the background (killing only the previous preview),
#   waits, switches to an empty workspace so the `bottom` layer is uncovered, VERIFIES the active
#   workspace really has 0 windows (never capture the user's windows), takes
#   qa/screenshots/qs-widgets-<name>.png with grim, switches back, and prints the QML log (warnings/errors).
#   NORESTART=1 keeps the running preview.  WAIT=<s> startup wait (default 5).
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
NAME="${1:-wip}"; shift || true
LOG="${TMPDIR:-/tmp}/qs-widgets.log"
# shellcheck disable=SC1091
source "$REPO/scripts/dev-env.sh"
if [ -z "${NORESTART:-}" ]; then
    pkill -f "qs -p $REPO/quickshell/Widgets/preview" 2>/dev/null; pkill -f "qs -p quickshell/Widgets/preview" 2>/dev/null
    sleep 0.5
    mkdir -p "$HOME/.config/overworld"; printf 'true\n' > "$HOME/.config/overworld/widgets-visible"   # start visible
    ( cd "$REPO" && env "$@" qs -p "$REPO/quickshell/Widgets/preview" > "$LOG" 2>&1 & )
    sleep "${WAIT:-5}"
fi
ws_json() { hyprctl activeworkspace -j; }
WS=$(ws_json | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
# Pick an explicit empty workspace id (hyprctl's `workspace empty` jumps to a populated one when the
# current workspace is itself empty).  Prefer staying where we are if it has no windows.
TARGET=$(hyprctl workspaces -j | python3 -c '
import json,sys
ws={w["id"]:w for w in json.load(sys.stdin)}
cur='"$WS"'
if cur in ws and ws[cur]["windows"]==0: print(cur); sys.exit()
for i in range(1,11):
    if i not in ws or ws[i]["windows"]==0: print(i); sys.exit()
print(cur)')
[ "$TARGET" != "$WS" ] && hyprctl dispatch workspace "$TARGET" >/dev/null
ok=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.3
    if [ "$(ws_json | python3 -c 'import json,sys;print(json.load(sys.stdin)["windows"])')" = "0" ]; then ok=1; break; fi
done
if [ "$ok" = "1" ]; then
    sleep 1.0
    # qs-core's `qs -c overworld` (if running) also instantiates DesktopWidgets; hide its copy during the capture
    OTHER=0; qs -c overworld ipc call widgets hide >/dev/null 2>&1 && OTHER=1 && sleep 1.5
    # re-check right before the capture (the user may have switched back)
    if [ "$(ws_json | python3 -c 'import json,sys;print(json.load(sys.stdin)["windows"])')" = "0" ]; then
        mkdir -p "$REPO/qa/screenshots"
        grim -o eDP-1 "$REPO/qa/screenshots/qs-widgets-$NAME.png"
        echo "screenshot: qa/screenshots/qs-widgets-$NAME.png"
    else
        echo "SKIPPED capture: workspace not empty at capture time"
    fi
    [ "$OTHER" = "1" ] && qs -c overworld ipc call widgets reveal >/dev/null 2>&1
    printf 'true\n' > "$HOME/.config/overworld/widgets-visible"   # never leave the persisted state hidden
else
    echo "SKIPPED capture: could not reach an empty workspace"
fi
hyprctl dispatch workspace "$WS" >/dev/null
echo "--- qs log (non-INFO lines):"
grep -v "^\s*INFO" "$LOG" | grep -v "playerctld" || echo "(clean)"
