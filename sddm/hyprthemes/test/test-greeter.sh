#!/usr/bin/env bash
# The staged wrapper in the real sddm-greeter-qt6, offscreen: logins, memory across reboots, missing sessions, broken looks. No sudo, nothing on screen.
#   test-greeter.sh [screenshot dir]     default qa/screenshots/sddm-switcher
set -u
HERE="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-$REPO/qa/screenshots/sddm-switcher}"
T="$(mktemp -d /tmp/hyprthemes-greeter.XXXXXX)" || exit 1
[[ -z "${KEEP_LOGS:-}" ]] && trap 'rm -rf "${T:?}"' EXIT
RUN="$HERE/run-harness.sh"
fail=0; passed=0
expect() {                      # expect <name> <log> <grep -E pattern>
    if grep -qE -- "$3" "$2"; then passed=$((passed + 1)); else printf 'FAIL  %s (no match: %s)\n' "$1" "$3"; fail=1; fi
}
absent() {                      # absent <name> <log> <grep -E pattern>
    if grep -qE -- "$3" "$2"; then printf 'FAIL  %s (found: %s)\n' "$1" "$3"; grep -E -- "$3" "$2" | head -3; fail=1; else passed=$((passed + 1)); fi
}
state() { mkdir -p "$T/state"; printf '[General]\n' >"$T/state/greeter.conf"; for kv in "$@"; do printf '%s\n' "$kv" >>"$T/state/greeter.conf"; done; }
go() {                          # go <log name> <scenario> [Key=Value …]
    local log="$T/$1.log" scenario="$2"; shift 2
    KEEP_STATE="$T/state/greeter.conf" HARNESS_TIMEOUT=70 "$RUN" "$scenario" "$OUT" "$@" >"$log" 2>&1
    grep -q 'TEST DONE' "$log" || { printf 'FAIL  %s never finished\n' "$log"; fail=1; }
}
# Sessions in the fake list: 0 Hyprland, 1 uwsm, 2 Apothecary, 3 Overworld, 4 Stock, 5 Plasma
OURS='^file://.*/theme/(Main|LookHost|Fallback|Harness)\.qml:|/theme/looks\.js:'

rm -rf "${T:?}/state"
go walk walk LastIndex=0; L="$T/walk.log"
expect "first boot: the running desktop's look, its session" "$L" 'STATE start look=overworld session=3 '
expect "F10 opens the menu"                  "$L" 'STATE esc-before .*menu=true'
expect "Esc closes, focus back on password"  "$L" 'STATE esc-closed .*menu=false focus=QQuickTextInput'
expect "a click outside closes the menu"     "$L" 'STATE click-outside-closed .*menu=false focus=QQuickTextInput'
expect "keyboard pick: look and session"     "$L" 'STATE after-keyboard-pick look=apothecary session=2 .*focus=TextField'
expect "Apothecary login uses its session"   "$L" 'LOGIN user=.* password=secret session=2 file=hyprland-apothecary.desktop'
expect "key 1 picks Waguri + stock session"  "$L" 'STATE waguri-lock look=waguri session=4 file=hyprland-stock.desktop'
expect "menu on the lock screen gives focus back" "$L" 'STATE waguri-lock-after-menu .*menu=false focus=LockScreen'
expect "Waguri login uses the stock session" "$L" 'LOGIN user=.* password=pw session=4 file=hyprland-stock.desktop'
expect "mouse pick: Overworld"               "$L" 'STATE after-mouse-pick look=overworld session=3 '
expect "a session picked by hand wins, look stays" "$L" 'LOGIN user=.* password=x session=4 file=hyprland-stock.desktop'
expect "look still Overworld after that"     "$L" 'STATE logged-in look=overworld '
expect "state: look remembered"              "$L" '^look=overworld'
expect "state: session left to SDDM after a login" "$L" '^sessionChoice=$'
expect "the video background was opened"     "$L" 'looks/silent/backgrounds/waguri.mp4'
absent "no QML errors from the wrapper"      "$L" "$OURS"
absent "no QSettings trouble"                "$L" 'Failed to initialize QSettings'

state look=overworld sessionChoice=
go manual snapshot LastIndex=5 Shot=reboot-manual
expect "reboot after a hand-picked session: Plasma, same look" "$T/manual.log" 'STATE snapshot look=overworld session=5 file=plasma.desktop'

state look=apothecary sessionChoice=hyprland-apothecary.desktop
go picked snapshot LastIndex=3 Shot=reboot-picked
expect "reboot after a pick without a login: the pick stands" "$T/picked.log" 'STATE snapshot look=apothecary session=2 file=hyprland-apothecary.desktop'

rm -rf "${T:?}/state"
go plasma snapshot LastIndex=5 Shot=first-plasma
expect "first boot after Plasma: Plasma stays selected" "$T/plasma.log" 'STATE snapshot look=overworld session=5 file=plasma.desktop'

rm -rf "${T:?}/state"
go nosessions snapshot LastIndex=0 FakeSessions=stock Shot=no-sessions
expect "theme sessions missing: look loads, session untouched" "$T/nosessions.log" 'STATE snapshot look=overworld session=0 file=hyprland.desktop'
absent "theme sessions missing: no QML errors" "$T/nosessions.log" "$OURS"

rm -rf "${T:?}/state"
PATCH_THEME='echo "this is not QML" >"$1/looks/overworld/Main.qml"' go broken snapshot LastIndex=0 Shot=broken-one
expect "a look that does not load: the next one takes over" "$T/broken.log" 'STATE snapshot look=waguri '
expect "a look that does not load: it says so" "$T/broken.log" 'hyprthemes: look overworld failed to load'

rm -rf "${T:?}/state"
PATCH_THEME='for d in silent overworld apothecary; do echo "this is not QML" >"$1/looks/$d/Main.qml"; done' go allbroken snapshot LastIndex=0 Shot=all-broken
expect "no look loads: the plain form is there" "$T/allbroken.log" 'STATE snapshot look=none .*focus=QQuickTextInput'

rm -rf "${T:?}/state"
go subset snapshot LastIndex=0 Looks=waguri,apothecary DefaultLook=overworld Shot=subset
expect "a look left out of the build is not offered" "$T/subset.log" 'STATE snapshot look=waguri '

rm -rf "${T:?}/state"
PATCH_THEME='sed -i "s/^MainScript=.*/MainScript=RealModel.qml/" "$1/metadata.desktop"; cp "'"$HERE"'/RealModel.qml" "$1/"' go real snapshot
expect "SDDM's model: File role ends in the file name" "$T/real.log" 'SESSION [0-9]+ file=(.*/)?hyprland\.desktop name=Hyprland$'
expect "SDDM's model: Plasma is listed"                "$T/real.log" 'SESSION [0-9]+ file=(.*/)?plasma\.desktop name=Plasma$'

printf '%d checks passed\n' "$passed"
(( fail == 0 )) && echo "greeter: ALL OK"
exit "$fail"
