#!/usr/bin/env bash
# live-roundtrip.sh [--no-install] — the real thing, on the live desktop: install, on (Day), dark, off, and compares what came back with what
# was there. For hyprland-engineer's and qa-reviewer's final checks. Screens go through dev-shot.sh, on the empty workspace 77. Takes about a minute.
# Whatever happens, an EXIT trap turns Overworld off again. Silence: refuses to run unless config.json has "sounds": false.
# While the shells change hands it keeps asking org.freedesktop.Notifications for its server info (no notification, no sound): that is what
# D-Bus-activates mako in the gap, the race notif_claim in scripts/overworld is there for.
set -u
REPO="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd -P)"
source "$REPO/scripts/dev-env.sh"
OW="$REPO/scripts/overworld"; S="$REPO/scripts/dev-shot.sh"; OUT="$REPO/qa/screenshots"; A="$HOME/.config/apothecary"
T="$(mktemp -d /tmp/ow-live.XXXXXX)"; mkdir -p "$OUT"
fail=0; ok() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1   [$2]"; fail=1; fi; }
errs() { local e; e="$(hyprctl configerrors 2>&1)"; [[ -z "${e//[[:space:]]/}" || "$e" == "no errors" ]] || { echo "CONFIG ERRORS: $e"; return 1; }; }
envof() { local f="$T/env.$$.$RANDOM"; hyprctl dispatch exec "sh -c 'printenv $1 > $f'" >/dev/null; sleep 0.4; cat "$f" 2>/dev/null; rm -f "$f"; }
snapshot() {       # everything `off` must bring back
    apothecary status | grep -vE '^(awww|hypridle):'
    echo "awww=$(awww query | sed -n 's/.*currently displaying: image: //p' | head -n1)"
    echo "hypridle=$(pgrep -a -x hypridle | cut -d' ' -f2-)"
    echo "hyprlock=$(readlink "$HOME/.config/hypr/hyprlock.conf")"
    echo "stocklock=$(md5sum <"$HOME/.config/hypr/hyprlock.conf.pre-apothecary")"
    for f in enabled mode apps-mode; do echo "apo-$f=$(cat "$A/$f" 2>/dev/null)"; done
    for f in active.conf colors.conf hyprlock-vars.conf kitty-colors.conf lock.png; do echo "apo-$f=$(readlink "$A/$f")"; done
    for k in gtk-theme icon-theme cursor-theme color-scheme font-name; do echo "gsettings-$k=$(gsettings get org.gnome.desktop.interface $k)"; done
    echo "rounding=$(hyprctl -j getoption decoration:rounding | jq .int)"
    echo "border=$(hyprctl -j getoption general:border_size | jq .int)"
    echo "SUPER+Q=$(hyprctl -j binds | jq -r '.[] | select(.modmask==64 and .key=="Q") | .dispatcher' | sort -u | tr '\n' ' ')"
    echo "layers=$(hyprctl -j layers | jq -r '.. | .namespace? // empty' | sort -u | grep -v '^$' | tr '\n' ' ')"
    echo "mako=$(pgrep -x mako >/dev/null && echo running || echo stopped) waybar=$(pgrep -x waybar >/dev/null && echo running || echo stopped)"
}
dups() { hyprctl -j binds | jq -r '.[] | select(.key != "" and .mouse == false) | "\(.modmask) \(.key|ascii_downcase) \(.submap) \(.release)"' | sort | uniq -d; }
poke_start() { ( while :; do busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications GetServerInformation >/dev/null 2>&1; sleep 0.05; done ) & pokepid=$!; }
poke_stop() { [[ -n "${pokepid:-}" ]] && kill "$pokepid" 2>/dev/null; pokepid=""; wait 2>/dev/null; }
appswait() { for _ in $(seq 1 80); do pgrep -f 'apps/apply-mode\.sh' >/dev/null || return 0; sleep 0.5; done; echo "apps still applying after 40 s"; }

[[ "$(jq -r '.sounds' "$HOME/.config/overworld/config.json" 2>/dev/null)" == false ]] || { echo "refusing: config.json sounds must be false"; exit 2; }
[[ "$(apothecary status | sed -n 's/^enabled: *//p')" == yes ]] || { echo "refusing: expected Apothecary ON"; exit 2; }
snapshot >"$T/before.txt"
dups >"$T/dups-before.txt"
env_before="$(envof XCURSOR_THEME)"
[[ "${1:-}" == --no-install ]] || { echo "== install"; "$REPO/scripts/install.sh" | tail -n 12; errs; ok "no config errors after install" 'errs'; "$REPO/scripts/install.sh" >/dev/null; ok "second install ok" 'errs'; }
snapshot >"$T/installed.txt"
ok "install changed nothing visible" "diff '$T/before.txt' '$T/installed.txt'"
cleanup() {
    poke_stop
    [[ -n "${testpid:-}" ]] && kill "$testpid" 2>/dev/null
    if [[ -e "$HOME/.config/overworld/enabled" ]]; then echo "cleanup: overworld off"; "$OW" off; fi
}
trap cleanup EXIT

echo "== on (Day)"
started=$SECONDS
"$OW" light >/dev/null 2>&1 || true        # theme still off: just sets the mode file and links
poke_start; t0=$(date +%s.%N); "$OW" on; t1=$(date +%s.%N); poke_stop; printf 'on took %.1f s\n' "$(echo "$t1 - $t0" | bc)"
appswait    # apply-mode.sh sends kitty SIGUSR1 to reload: a kitty still starting up has no handler yet and dies of it
hyprctl dispatch exec "[workspace 77 silent] sh -c 'exec kitty --class overworld-test -e sh -c \"ls -la --color=always $REPO; sleep 170\" >$T/kitty.log 2>&1'" >/dev/null
sleep 3
ok "no config errors (on)"          'errs'
ok "qs -c overworld running"        "pgrep -f -x 'qs -c overworld' >/dev/null"
ok "the shell owns the notification name" "[[ \$(busctl --user --no-legend list | awk '\$1 == \"org.freedesktop.Notifications\" {print \$3}') == qs ]]"
ok "qs -c apothecary stopped"       "! pgrep -f -x 'qs -c apothecary' >/dev/null"
ok "waybar and mako not started"    "! pgrep -x waybar >/dev/null && ! pgrep -x mako >/dev/null"
ok "previous-theme remembered"      "[[ \"\$(cat $HOME/.config/overworld/previous-theme)\" == 'apothecary dark' ]]"
ok "rounding 0, border 3"           "[[ \$(hyprctl -j getoption decoration:rounding | jq .int) == 0 && \$(hyprctl -j getoption general:border_size | jq .int) == 3 ]]"
ok "SUPER+Q mines"                  "hyprctl -j binds | jq -r '.[] | select(.modmask==64 and .key==\"Q\") | .arg' | grep -q 'overworld kill'"
dups >"$T/dups-on.txt"
ok "we bind no key twice (the OSD keys fire both handlers on purpose)" "[[ -z \$(comm -13 '$T/dups-before.txt' '$T/dups-on.txt' | grep -vi xf86) ]]"
ok "cursor env for new apps"        "[[ \$(envof XCURSOR_THEME) == Overworld ]]"
"$OW" status
echo "binds: $(hyprctl -j binds | jq length)  layers: $(hyprctl -j layers | jq -r '.. | .namespace? // empty' | sort -u | tr '\n' ' ')"
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do testaddr="$(hyprctl -j clients | jq -r '[.[] | select(.class=="overworld-test")][0].address // empty')"; [[ -n "$testaddr" ]] && break; sleep 0.25; done
testpid="$(hyprctl -j clients | jq -r '[.[] | select(.class=="overworld-test")][0].pid // empty')"
hyprctl -j clients | jq -c '.[] | select(.class=="overworld-test") | {floating, size, workspace: .workspace.id}'
ok "the test window opened and floats" "[[ \$(hyprctl -j clients | jq '[.[] | select(.class==\"overworld-test\" and .floating)] | length') == 1 ]]"
ok "the rules size it to 60 %"      "[[ \$(hyprctl -j clients | jq -c '[.[] | select(.class==\"overworld-test\")][0].size') == '[1152,648]' ]]"
echo "reserved: $(hyprctl -j monitors | jq -c '.[0].reserved')"
[[ -s "$T/kitty.log" ]] && { echo "--- kitty's output:"; head -n 12 "$T/kitty.log"; }
"$S" "$OUT/hypr-on-day.png" full

echo "== dark"
"$OW" dark
sleep 2.5
ok "no config errors (dark)"        'errs'
ok "colours follow the mode"        "[[ \$(readlink $HOME/.config/overworld/colors.conf) == *dark* ]]"
"$S" "$OUT/hypr-on-night.png" full

echo "== verbs against the real shell"
ok "ipc: game mode"   "[[ \$(timeout 2 qs -c overworld ipc call gamemode get) == survival ]]"
ok "ipc: world"       "timeout 2 qs -c overworld ipc call world status | grep -q weather="
"$OW" gamemode adventure; sleep 1
ok "adventure: animations off"      "[[ \$(hyprctl -j getoption animations:enabled | jq .int) == 0 ]]"
ok "gamemode status"                "[[ \$($OW gamemode status) == adventure ]]"
"$OW" gamemode survival; sleep 1
ok "survival: animations back"      "[[ \$(hyprctl -j getoption animations:enabled | jq .int) == 1 ]]"
ok "no config errors (gamemode)"    'errs'
"$OW" f3 on; sleep 1; "$S" "$OUT/hypr-on-f3.png" full; "$OW" f3 off
[[ -n "${testaddr:-}" ]] && { "$OW" kill "$testaddr"; for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do [[ "$(hyprctl -j clients | jq --arg a "$testaddr" '[.[] | select(.address==$a)] | length')" == 0 ]] && break; sleep 0.25; done
    ok "overworld kill closed the test window" "[[ \$(hyprctl -j clients | jq --arg a '$testaddr' '[.[] | select(.address==\$a)] | length') == 0 ]]"; timeout 2 qs -c overworld ipc call interact status; testpid=""; }
grep -nE 'ERROR|error:|qml.*[Ww]arn|WARN' "$HOME/.cache/overworld/qs.log" | tail -n 8

echo "== off"
poke_start; t0=$(date +%s.%N); "$OW" off; t1=$(date +%s.%N); poke_stop; printf 'off took %.1f s, Overworld was on for %d s\n' "$(echo "$t1 - $t0" | bc)" $((SECONDS - started))
appswait; sleep 1.5
ok "no config errors (off)"         'errs'
ok "Apothecary owns the notification name" "[[ \$(busctl --user --no-legend list | awk '\$1 == \"org.freedesktop.Notifications\" {print \$3}') == qs ]]"
snapshot >"$T/after.txt"
ok "Apothecary exactly as before"   "diff '$T/before.txt' '$T/after.txt'"
ok "cursor env back"                "[[ \$(envof XCURSOR_THEME) == '$env_before' ]]"
apothecary status
"$S" "$OUT/hypr-after-off.png" full
trap - EXIT
rm -rf "$T"
(( fail == 0 )) && echo "ROUND TRIP OK" || echo "ROUND TRIP HAS FAILURES"
exit $fail
