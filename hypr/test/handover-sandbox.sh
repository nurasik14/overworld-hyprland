#!/usr/bin/env bash
# handover-sandbox.sh — exercises scripts/install.sh, `overworld on/off` and scripts/uninstall.sh in a throw-away $HOME, with every
# command that could reach the live session replaced by a stub that only logs (hyprctl, qs, hypridle, waybar, mako, systemctl,
# pkill, pgrep, awww, notify-send). It runs a copy of the repo WITHOUT apps/: apps/apply-mode.sh talks to live kitty sockets and
# gsettings, and has its own tests (docs/agent-reports/app-theming.md). Nothing here can touch the real desktop.
# Prints PASS/FAIL per check; exit 1 on any FAIL.
set -u
SRC="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd -P)"
SB="$(mktemp -d /tmp/ow-sandbox.XXXXXX)"
trap 'rm -rf "$SB"' EXIT
REPO="$SB/repo"
mkdir -p "$REPO/scripts" "$REPO/tokens" "$REPO/quickshell" "$REPO/assets/wallpapers/light" "$REPO/assets/wallpapers/dark"
cp -r "$SRC/hypr" "$REPO/hypr"
cp -r "$SRC/quotes" "$REPO/quotes"
cp -r "$SRC/tokens/out" "$REPO/tokens/out"
cp -r "$SRC/scripts/game" "$SRC/scripts/interact" "$REPO/scripts/"
cp "$SRC/scripts/overworld" "$SRC/scripts/install.sh" "$SRC/scripts/uninstall.sh" "$SRC/scripts/ow-sound" "$SRC/scripts/backlight-dev.sh" "$REPO/scripts/"
cp "$SRC/tokens/sounds.json" "$REPO/tokens/" 2>/dev/null
touch "$REPO/assets/wallpapers/light/01-day.png" "$REPO/assets/wallpapers/dark/01-night.png"
export HOME="$SB/home" XDG_CONFIG_HOME="$SB/home/.config" XDG_CACHE_HOME="$SB/home/.cache" XDG_RUNTIME_DIR="$SB/run"
mkdir -p "$HOME/.config/hypr" "$HOME/.local/bin" "$XDG_RUNTIME_DIR" "$SB/bin" "$SB/running"
LOG="$SB/calls.log"; RUN="$SB/running"
pass=0; fail=0
ok()  { if eval "$2"; then pass=$((pass+1)); echo "PASS  $1"; else fail=$((fail+1)); echo "FAIL  $1   [$2]"; fi; }

# ---- a fake Apothecary: same files its CLI keeps, nothing else
APO="$SB/apothecary-hyprland"; mkdir -p "$APO/hypr" "$APO/apps" "$APO/assets/wallpapers/dark"
touch "$APO/hypr/on.conf" "$APO/hypr/off.conf" "$APO/hypr/hyprlock.conf" "$APO/hypr/hypridle.conf" "$APO/assets/wallpapers/dark/w.png"
printf '#!/bin/bash\necho "apo-apply $*" >>"%s"\n' "$LOG" >"$APO/apps/apply-mode.sh"; chmod +x "$APO/apps/apply-mode.sh"

# ---- stubs. "running" processes are marker files, so pgrep/pkill answer consistently
stub() { printf '#!/bin/bash\necho "%s $*" >>"%s"\n%s\n' "$1" "$LOG" "${2:-exit 0}" >"$SB/bin/$1"; chmod +x "$SB/bin/$1"; }
stub hyprctl 'case "$1" in reload) echo ok ;; esac; exit 0'
stub notify-send; stub fc-cache; stub gsettings
stub awww '[[ "$1" == img ]] && echo "$2" >"'"$RUN"'/awww"; [[ "$1" == query ]] && echo ": eDP-1: 1920x1080, currently displaying: image: $(cat "'"$RUN"'/awww")"; exit 0'
stub setsid 'shift 0; [[ "$1" == -f ]] && shift; "$@"; exit 0'
stub qs 'if [[ "$1 $2 $3" == "-c overworld ipc" ]]; then [[ -e "'"$RUN"'/qs-overworld" ]]; exit $?; fi; if [[ "$1" == -c ]]; then touch "'"$RUN"'/qs-$2"; fi; exit 0'
stub hypridle 'if [[ "${1:-}" == -c ]]; then echo "$2" >"'"$RUN"'/hypridle"; else echo stock >"'"$RUN"'/hypridle"; fi; exit 0'
stub waybar 'touch "'"$RUN"'/waybar"'
stub mako 'touch "'"$RUN"'/mako"'
stub systemctl 'case "$*" in *"is-active --quiet mako"*) [[ -e "'"$RUN"'/mako" ]]; exit $? ;; *"stop mako"*) rm -f "'"$RUN"'/mako" ;; *"start mako"*) touch "'"$RUN"'/mako" ;; *"show waybar"*) echo not-found ;; esac; exit 0'
# mako holds the notification name if it runs (D-Bus activated, say), else whichever shell runs
cat >"$SB/bin/busctl" <<BC
#!/bin/bash
if [[ -e "$RUN/mako" ]]; then echo "org.freedesktop.Notifications 1 mako me :1.1 user@1000.service - -"
elif [[ -e "$RUN/qs-overworld" || -e "$RUN/qs-apothecary" ]]; then echo "org.freedesktop.Notifications 2 qs me :1.2 user@1000.service - -"; fi
BC
chmod +x "$SB/bin/busctl"
cat >"$SB/bin/pgrep" <<PG
#!/bin/bash
args="\$*"
case "\$args" in
  *"-x waybar"*)  [[ -e "$RUN/waybar" ]] ;;
  *"-x mako"*)    [[ -e "$RUN/mako" ]] ;;
  *"-x swaync"*)  exit 1 ;;
  *"qs -c overworld"*)  [[ -e "$RUN/qs-overworld" ]] ;;
  *"qs -c apothecary"*) [[ -e "$RUN/qs-apothecary" ]] ;;
  *"qs -c overview"*)   exit 0 ;;
  *"-a -x hypridle"*)   [[ -e "$RUN/hypridle" ]] && echo "1 hypridle \$(cat "$RUN/hypridle")" ;;
  *"awww-daemon"*) exit 0 ;;
  *) exit 1 ;;
esac
PG
cat >"$SB/bin/pkill" <<PK
#!/bin/bash
args="\$*"; echo "pkill \$args" >>"$LOG"
case "\$args" in
  *"-x waybar"*)  rm -f "$RUN/waybar" ;;
  *"-x mako"*)    rm -f "$RUN/mako" ;;
  *"qs -c overworld"*)  rm -f "$RUN/qs-overworld" ;;
  *"qs -c apothecary"*) rm -f "$RUN/qs-apothecary" ;;
  *"-x hypridle"*) rm -f "$RUN/hypridle" ;;
esac
exit 0
PK
chmod +x "$SB/bin/pgrep" "$SB/bin/pkill"
for n in pw-play; do stub "$n"; done
export PATH="$SB/bin:$PATH"

# ---- the desktop: JaKooLit + Apothecary ON (dark), exactly the machine's layout
H="$XDG_CONFIG_HOME/hypr"; A="$XDG_CONFIG_HOME/apothecary"; O="$XDG_CONFIG_HOME/overworld"; CLI="$REPO/scripts/overworld"
apo_on() {
    mkdir -p "$A"; ln -sfn "$APO" "$A/repo"; touch "$A/enabled" "$A/mako-was-active"; echo dark >"$A/mode"
    ln -sfn "$APO/hypr/on.conf" "$A/active.conf"; echo "$APO/assets/wallpapers/dark/w.png" >"$A/wallpaper-dark"
    echo "/old/stock-wallpaper.jpg" >"$A/prev-wallpaper"
    echo 'stock lock config' >"$H/hyprlock.conf.pre-apothecary"; ln -sfn "$APO/hypr/hyprlock.conf" "$H/hyprlock.conf"
    touch "$RUN/qs-apothecary"; echo "$APO/hypr/hypridle.conf" >"$RUN/hypridle"; echo "$APO/assets/wallpapers/dark/w.png" >"$RUN/awww"
}
printf '# jakoolit\nsource = ~/.config/hypr/apothecary.conf # apothecary\n# after\n' >"$H/hyprland.conf"
ln -s "$APO/hypr/hyprlock.conf" "$H/apothecary.conf"
apo_on
echo 'custom user config' >/dev/null; mkdir -p "$O"; echo '{"sounds": false, "keep": 1}' >"$O/config.json"

echo "== install (twice) =="
"$REPO/scripts/install.sh" >"$SB/install1.out" 2>&1; rc1=$?
cp "$H/hyprland.conf" "$SB/hc.1"
"$REPO/scripts/install.sh" >"$SB/install2.out" 2>&1; rc2=$?
ok "install exits 0 twice"                "[[ $rc1 == 0 && $rc2 == 0 ]]"
ok "hook is right after Apothecary's line" "[[ \"\$(sed -n 3p '$H/hyprland.conf')\" == 'source = ~/.config/hypr/overworld.conf # overworld' ]]"
ok "exactly one hook line"                "[[ \$(grep -c 'overworld.conf' '$H/hyprland.conf') == 1 ]]"
ok "second install changes nothing"       "cmp -s '$SB/hc.1' '$H/hyprland.conf'"
ok "config.json not clobbered"            "grep -q '\"keep\": 1' '$O/config.json'"
ok "links exist"                          "[[ -L '$H/overworld.conf' && -L '$XDG_CONFIG_HOME/quickshell/overworld' && -L '$HOME/.local/bin/overworld' ]]"
ok "active.conf -> off.conf"              "[[ \$(readlink '$O/active.conf') == '$REPO/hypr/off.conf' ]]"
ok "Apothecary still on, untouched"       "[[ -e '$A/enabled' && \$(readlink '$A/active.conf') == '$APO/hypr/on.conf' ]]"
ok "overworld.conf has no exec-once"      "! grep -q '^exec' '$REPO/hypr/overworld.conf'"

echo "== on, from a running Apothecary =="
: >"$LOG"; SECONDS=0; "$CLI" on >"$SB/on.out" 2>&1; rc=$?; on_secs=$SECONDS
ok "on exits 0"                           "[[ $rc == 0 ]]"
ok "previous-theme = apothecary dark"     "[[ \$(cat '$O/previous-theme') == 'apothecary dark' ]]"
ok "Apothecary flagged off"               "[[ ! -e '$A/enabled' && \$(readlink '$A/active.conf') == '$APO/hypr/off.conf' ]]"
ok "qs -c apothecary stopped"             "[[ ! -e '$RUN/qs-apothecary' ]]"
ok "qs -c overworld started"              "[[ -e '$RUN/qs-overworld' ]]"
ok "no waybar in between"                 "! grep -qE '^waybar|start waybar' '$LOG'"
ok "no mako in between"                   "! grep -qE '^mako|start mako' '$LOG'"
ok "Apothecary's mako flag kept"          "[[ -e '$A/mako-was-active' ]]"
ok "Apothecary's apps restored by its script" "grep -q 'apo-apply off' '$LOG'"
ok "hyprlock = ours, Apothecary's link saved" "[[ \$(readlink '$H/hyprlock.conf') == '$REPO/hypr/hyprlock.conf' && \$(readlink '$H/hyprlock.conf.pre-overworld') == '$APO/hypr/hyprlock.conf' ]]"
ok "stock lock file untouched"            "grep -q 'stock lock' '$H/hyprlock.conf.pre-apothecary'"
ok "hypridle = ours"                      "[[ \$(cat '$RUN/hypridle') == '$REPO/hypr/hypridle.conf' ]]"
ok "exactly one reload"                   "[[ \$(grep -c '^hyprctl reload' '$LOG') == 1 ]]"
ok "no 10 s waybar wait (took ${on_secs}s)" "(( on_secs < 5 ))"

echo "== mako D-Bus activated in the gap between the shells =="
touch "$RUN/mako"; SECONDS=0; "$CLI" repair >/dev/null 2>&1
ok "repair stops it and the shell owns the name" "[[ ! -e '$RUN/mako' ]] && (( SECONDS < 3 ))"

echo "== on again keeps the memory =="
"$CLI" on >/dev/null 2>&1
ok "previous-theme unchanged"             "[[ \$(cat '$O/previous-theme') == 'apothecary dark' ]]"
ok "hyprlock backup still Apothecary's"   "[[ \$(readlink '$H/hyprlock.conf.pre-overworld') == '$APO/hypr/hyprlock.conf' ]]"

echo "== status =="
"$CLI" status >"$SB/status.out" 2>&1
ok "status shows previous, gamemode, daycycle" "grep -q 'previous:  apothecary dark' '$SB/status.out' && grep -q 'gamemode:  survival' '$SB/status.out' && grep -q '^daycycle:' '$SB/status.out'"

echo "== off, back to Apothecary =="
: >"$LOG"; "$CLI" off >"$SB/off.out" 2>&1; rc=$?
ok "off exits 0"                          "[[ $rc == 0 ]]"
ok "Apothecary enabled, on.conf"          "[[ -e '$A/enabled' && \$(readlink '$A/active.conf') == '$APO/hypr/on.conf' ]]"
ok "Apothecary mode dark"                 "[[ \$(cat '$A/mode') == dark ]]"
ok "qs -c apothecary running, ours gone"  "[[ -e '$RUN/qs-apothecary' && ! -e '$RUN/qs-overworld' ]]"
ok "hyprlock = Apothecary's link again"   "[[ \$(readlink '$H/hyprlock.conf') == '$APO/hypr/hyprlock.conf' && ! -L '$H/hyprlock.conf.pre-overworld' ]]"
ok "hypridle = Apothecary's"              "[[ \$(cat '$RUN/hypridle') == '$APO/hypr/hypridle.conf' ]]"
ok "wallpaper = Apothecary's"             "[[ \$(cat '$RUN/awww') == '$APO/assets/wallpapers/dark/w.png' ]]"
ok "no waybar, no mako on the way back"   "[[ ! -e '$RUN/waybar' && ! -e '$RUN/mako' ]]"
ok "no sound played"                      "! grep -q '^pw-play' '$LOG'"
ok "Apothecary's apps come back in its mode" "grep -q 'apo-apply dark' '$LOG'"
ok "previous-theme removed"               "[[ ! -e '$O/previous-theme' ]]"
ok "off twice is harmless"                "'$CLI' off 2>&1 | grep -q 'already off'"

echo "== stock path =="
rm -f "$A/enabled"; ln -sfn "$APO/hypr/off.conf" "$A/active.conf"; rm -f "$RUN/qs-apothecary"
rm -f "$H/hyprlock.conf"; echo 'stock lock config' >"$H/hyprlock.conf"
touch "$RUN/waybar" "$RUN/mako"; echo stock >"$RUN/hypridle"; echo /old/stock-wallpaper.jpg >"$RUN/awww"
: >"$LOG"; "$CLI" on >/dev/null 2>&1
ok "previous-theme = stock"               "[[ \$(cat '$O/previous-theme') == stock ]]"
ok "waybar and mako stopped"              "[[ ! -e '$RUN/waybar' && ! -e '$RUN/mako' ]]"
ok "stock wallpaper remembered"           "[[ \$(cat '$O/prev-wallpaper') == /old/stock-wallpaper.jpg ]]"
ok "stock lock saved as a file"           "[[ -f '$H/hyprlock.conf.pre-overworld' && ! -L '$H/hyprlock.conf.pre-overworld' ]]"
: >"$LOG"; "$CLI" off >/dev/null 2>&1
ok "waybar and mako back"                 "[[ -e '$RUN/waybar' && -e '$RUN/mako' ]]"
ok "stock hypridle back"                  "[[ \$(cat '$RUN/hypridle') == stock ]]"
ok "stock lock file back"                 "[[ -f '$H/hyprlock.conf' && ! -L '$H/hyprlock.conf' ]] && grep -q 'stock lock' '$H/hyprlock.conf'"
ok "Apothecary left off"                  "[[ ! -e '$A/enabled' ]]"

echo "== Apothecary gone =="
apo_on; rm -f "$RUN/mako" "$RUN/waybar"
"$CLI" on >/dev/null 2>&1
rm -f "$A/repo"
"$CLI" off >/dev/null 2>&1; rc=$?
ok "off falls back to stock, exit 0"      "[[ $rc == 0 && -e '$RUN/waybar' && -e '$RUN/mako' ]]"
ok "still leaves a hyprlock.conf"         "[[ -e '$H/hyprlock.conf' || -L '$H/hyprlock.conf' ]]"
ln -sfn "$APO" "$A/repo"

echo "== verbs without a shell =="
"$CLI" gamemode adventure >/dev/null 2>&1; 
ok "gamemode file written"                "[[ \$(cat '$O/gamemode') == adventure ]]"
ok "gamemode on|off aliases"              "'$CLI' gamemode off >/dev/null 2>&1 && [[ \$(cat '$O/gamemode') == survival ]] && '$CLI' gamemode on >/dev/null 2>&1 && [[ \$(cat '$O/gamemode') == adventure ]] && '$CLI' gamemode toggle >/dev/null 2>&1 && [[ \$(cat '$O/gamemode') == survival ]]"
ok "gamemode rejects nonsense"            "! '$CLI' gamemode nonsense >/dev/null 2>&1"
ok "legacy flag reads as adventure"       "echo hidden >'$O/gamemode'; [[ \$('$CLI' gamemode status) == adventure ]]; rc=\$?; echo survival >'$O/gamemode'; (( rc == 0 ))"
for v in on off status light dark toggle wallpaper world gamemode weather daycycle f3 kill chat advancements stats options sound screenshot ws brew event reload repair session-start; do
    "$CLI" help "$v" >/dev/null 2>&1 || { fail=$((fail+1)); echo "FAIL  help $v"; }
done
pass=$((pass+1)); echo "PASS  every verb has a help page (see above for failures)"
ok "unknown verb exits 2"                 "'$CLI' nonsense >/dev/null 2>&1; [[ \$? == 2 ]]"
ok "weather rejects nonsense"             "'$CLI' weather nonsense >/dev/null 2>&1; [[ \$? == 2 ]]"
ok "chat without a shell says so"         "'$CLI' chat 2>&1 | grep -q 'not running'"
OW_SOUND_DRYRUN=1 "$CLI" sound ui.click >"$SB/sound.out" 2>&1
ok "sound goes through ow-sound, silent"  "! grep -q '^pw-play' '$LOG'"

echo "== uninstall =="
apo_on; "$CLI" on >/dev/null 2>&1
"$REPO/scripts/uninstall.sh" >"$SB/uninstall.out" 2>&1; rc=$?
ok "uninstall exits 0"                    "[[ $rc == 0 ]]"
ok "hook gone, Apothecary's line kept"    "! grep -q overworld.conf '$H/hyprland.conf' && grep -q apothecary.conf '$H/hyprland.conf'"
ok "hyprland.conf is back to the original" "printf '# jakoolit\nsource = ~/.config/hypr/apothecary.conf # apothecary\n# after\n' | cmp -s - '$H/hyprland.conf'"
ok "links gone"                           "[[ ! -e '$H/overworld.conf' && ! -e '$XDG_CONFIG_HOME/quickshell/overworld' && ! -e '$HOME/.local/bin/overworld' ]]"
ok "Apothecary back on"                   "[[ -e '$A/enabled' && \$(readlink '$H/hyprlock.conf') == '$APO/hypr/hyprlock.conf' ]]"
ok "config.json kept without --purge"     "grep -q '\"keep\": 1' '$O/config.json'"

echo; echo "passed $pass, failed $fail"
(( fail == 0 ))
