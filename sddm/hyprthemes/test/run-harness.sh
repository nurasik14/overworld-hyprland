#!/usr/bin/env bash
# run-harness.sh <scenario> <out dir> [Key=Value …] — the staged wrapper in the real sddm-greeter-qt6, offscreen and silent.
#   Nothing appears on any display: the offscreen platform never maps a window, and DISPLAY/WAYLAND_DISPLAY are cleared unless asked otherwise.
#   No audio server is reachable, HOME is throw-away (like the sddm user the greeter sees system fonts only).
#   Keys become [HyprTest] entries for Harness.qml (LastIndex, FakeSessions=full|stock, Shot); a key containing "." is written to [HyprThemes] (Looks.x).
#   KEEP_STATE=<file>: the greeter's state file to use, so a second run sees what the first one remembered.
#   BASELINE=1: run the untouched $SILENT theme instead of the wrapper (Baseline.qml), for comparing the Waguri look.
#   BACKEND=rhi RHI=opengl KEEP_DISPLAY=1: render with the GPU instead of the software renderer, which cannot draw MultiEffect or video.
set -u
HERE="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
STAGE="${STAGE:-$REPO/sddm/.staging/hyprthemes}"
SCENARIO="$1"; OUT="$2"; shift 2
WORK="$(mktemp -d /tmp/hyprthemes-harness.XXXXXX)"
THEME="$WORK/theme"
mkdir -p "$OUT" "$WORK/home"
if [[ -n "${BASELINE:-}" ]]; then
    cp -r /usr/share/sddm/themes/silent "$THEME"; chmod -R u+w "$THEME"; rm -rf "$THEME/.git"
    sed "s|@OUT@|$OUT|" "$HERE/Baseline.qml" >"$THEME/Harness.qml"
else
    cp -r "$STAGE" "$THEME"
    cp "$HERE/Harness.qml" "$THEME/"
fi
sed -i 's/^MainScript=.*/MainScript=Harness.qml/' "$THEME/metadata.desktop"
STATE="${KEEP_STATE:-$WORK/state/greeter.conf}"
[[ -n "${BASELINE:-}" ]] || sed -i "s|^StateFile=.*|StateFile=$STATE|" "$THEME/theme.conf"
[[ -n "${BASELINE:-}" ]] || { printf '\n[HyprTest]\nScenario=%s\nOutDir=%s\n' "$SCENARIO" "$OUT"; for kv in "$@"; do [[ "$kv" == Looks=* ]] || printf '%s\n' "$kv"; done; } >>"$THEME/theme.conf"
[[ -n "${BASELINE:-}" ]] || for kv in "$@"; do [[ "$kv" == Looks=* ]] && sed -i "s|^Looks=.*|$kv|" "$THEME/theme.conf"; done
[[ -n "${PATCH_THEME:-}" ]] && bash -c "$PATCH_THEME" _ "$THEME"
cd "$WORK" || exit 1
SINCE="$(date +%s)"
cat >"$WORK/screens.json" <<'JSON'
{ "screens": [ { "name": "test", "x": 0, "y": 0, "width": 1920, "height": 1080, "logicalDpi": 96, "logicalBaseDpi": 96, "dpr": 1 } ] }
JSON
[[ -n "${KEEP_DISPLAY:-}" ]] || unset DISPLAY     # the offscreen platform needs an X server for OpenGL, through an unmapped window; it shows nothing
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" XDG_CACHE_HOME="$WORK/home/.cache" \
    QT_QPA_PLATFORM="offscreen:configfile=$WORK/screens.json" QT_QUICK_BACKEND="${BACKEND:-software}" ${RHI:+QSG_RHI_BACKEND=$RHI} \
    QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/ QT_IM_MODULE=qtvirtualkeyboard QT_VIRTUALKEYBOARD_DESKTOP_DISABLE="${VK_DESKTOP_DISABLE-1}" \
    PULSE_SERVER=/nonexistent PIPEWIRE_REMOTE=/nonexistent ALSA_CONFIG_PATH=/dev/null \
    nice -n 10 sddm-greeter-qt6 --test-mode --theme "$THEME" >"$WORK/stderr" 2>&1 &
PID=$!
# The greeter logs to journald, and Qt.quit() does not end it (nothing connected to quit): watch for the harness' last line.
journal() { journalctl --no-pager -o cat -t sddm-greeter-qt6 _PID="$PID" --since "@$SINCE" 2>/dev/null; }
for ((i = 0; i < ${HARNESS_TIMEOUT:-120}; i++)); do
    sleep 1
    kill -0 "$PID" 2>/dev/null || break
    journal | grep -q 'TEST DONE' && break
done
sleep 0.5
if kill -0 "$PID" 2>/dev/null; then kill "$PID"; wait "$PID" 2>/dev/null; echo "(greeter stopped by the harness)"; else wait "$PID"; echo "greeter exited on its own, status $?"; fi
journal
cat "$WORK/stderr"
[[ -f "$STATE" ]] && { echo "--- state file"; cat "$STATE"; }
rm -rf "$WORK"
