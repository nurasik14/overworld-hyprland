#!/usr/bin/env bash
# scripts/theme-session against a fake HOME and fake theme repos. Never touches the real state: the only real file used is a copy of scripts/overworld;
# apps/apply-mode.sh is a stub, the compositor is a stub, and hyprctl, pkill, gsettings & co. on PATH are traps that record any call.
set -u
HERE="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
T="$(mktemp -d /tmp/hyprthemes-session.XXXXXX)" || exit 1
trap 'rm -rf "${T:?}"' EXIT
fail=0; passed=0
ok()  { passed=$((passed + 1)); [[ -z "${VERBOSE:-}" ]] || printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

HOMEDIR="$T/home"; CFG="$HOMEDIR/.config"; OW="$T/repos/overworld-hyprland"; APO="$T/repos/apothecary-hyprland"
STOCK_LOCK="stock hyprlock config"

make_repo() {                   # make_repo <dir> <name>
    local d="$1" m f
    mkdir -p "$d/hypr" "$d/scripts" "$d/apps"
    printf '# on\n' >"$d/hypr/on.conf"; printf '# off\n' >"$d/hypr/off.conf"; printf '# %s lock\n' "$2" >"$d/hypr/hyprlock.conf"; printf '# entry\n' >"$d/hypr/$2.conf"
    for m in light dark; do
        mkdir -p "$d/tokens/out/$m"
        for f in hyprland-colors.conf hyprlock-vars.conf kitty.conf; do printf '# %s\n' "$m" >"$d/tokens/out/$m/$f"; done
    done
    cat >"$d/apps/apply-mode.sh" <<STUB
#!/usr/bin/env bash
echo "$2 \$*" >>"$T/apps.log"
[[ -z "\${APPS_DELAY:-}" ]] || sleep "\$APPS_DELAY"
echo "\$1" >"$CFG/$2/apps-mode"
STUB
    chmod +x "$d/apps/apply-mode.sh"
}
fresh() {
    rm -rf "${T:?}/home" "${T:?}/repos" "${T:?}/run" "${T:?}/apps.log" "${T:?}/started" "${T:?}/traps"
    mkdir -p "$CFG/hypr" "$CFG/overworld" "$CFG/apothecary" "$HOMEDIR/.local/bin" "$T/run" "$T/bin"
    make_repo "$OW" overworld; make_repo "$APO" apothecary
    cp "$REPO/scripts/overworld" "$OW/scripts/overworld"
    mkdir -p "$OW/assets/renders" "$APO/assets/art"
    : >"$OW/assets/renders/lock-day.png"; : >"$OW/assets/renders/lock-night.png"; : >"$APO/assets/art/lock-light.png"; : >"$APO/assets/art/lock-dark.png"
    ln -s "$OW/scripts/overworld" "$HOMEDIR/.local/bin/overworld"
    printf '#!/bin/sh\n' >"$APO/scripts/apothecary"; chmod +x "$APO/scripts/apothecary"
    ln -s "$APO/scripts/apothecary" "$HOMEDIR/.local/bin/apothecary"
    ln -s "$OW" "$CFG/overworld/repo"; ln -s "$APO" "$CFG/apothecary/repo"
    ln -s "$OW/hypr/off.conf" "$CFG/overworld/active.conf"; ln -s "$APO/hypr/off.conf" "$CFG/apothecary/active.conf"
    echo light >"$CFG/overworld/mode"; echo dark >"$CFG/apothecary/mode"
    echo off >"$CFG/overworld/apps-mode"; echo off >"$CFG/apothecary/apps-mode"
    echo "$STOCK_LOCK" >"$CFG/hypr/hyprlock.conf"
    ln -s "$OW/hypr/overworld.conf" "$CFG/hypr/overworld.conf"; ln -s "$APO/hypr/apothecary.conf" "$CFG/hypr/apothecary.conf"
    printf 'source = ~/.config/hypr/apothecary.conf # apothecary\nsource = ~/.config/hypr/overworld.conf # overworld\n' >"$CFG/hypr/hyprland.conf"
}
mkdir -p "$T/bin"
for trap_cmd in hyprctl pkill pgrep systemctl busctl awww awww-daemon qs gsettings kitty waybar mako hypridle spicetify pw-play; do
    printf '#!/bin/sh\necho "%s $*" >>"%s/traps"\nexit 1\n' "$trap_cmd" "$T" >"$T/bin/$trap_cmd"
    chmod +x "$T/bin/$trap_cmd"
done
cat >"$T/compositor" <<STUB
#!/bin/sh
echo "DESKTOP_SESSION=\$DESKTOP_SESSION XDG_SESSION_DESKTOP=\$XDG_SESSION_DESKTOP \$(date +%s)" >"$T/started"
STUB
chmod +x "$T/compositor"

session() {                     # session <theme>: as SDDM would, with a clean environment
    env -i HOME="$HOMEDIR" PATH="$T/bin:/usr/bin:/bin" XDG_RUNTIME_DIR="$T/run" HYPR_THEME_SESSION_EXEC="$T/compositor" ${APPS_DELAY:+APPS_DELAY=$APPS_DELAY} \
        "$REPO/scripts/theme-session" "$@"
}
tree_state() { (cd "$HOMEDIR/.config" && find . \( -type f -o -type l \) -printf '%p -> %l\n' | sort; find . -type f -exec cksum {} + | sort -k3); }
link_is() { [[ "$(readlink "$1")" == "$2" ]]; }

is_overworld() {                # is_overworld <tag>
    check "$1: overworld enabled"        '[[ -e $CFG/overworld/enabled ]]'
    check "$1: overworld active on"      'link_is "$CFG/overworld/active.conf" "$OW/hypr/on.conf"'
    check "$1: overworld colours"        'link_is "$CFG/overworld/colors.conf" "$OW/tokens/out/light/hyprland-colors.conf"'
    check "$1: overworld hyprlock vars"  'link_is "$CFG/overworld/hyprlock-vars.conf" "$OW/tokens/out/light/hyprlock-vars.conf"'
    check "$1: overworld kitty"          'link_is "$CFG/overworld/kitty-colors.conf" "$OW/tokens/out/light/kitty.conf"'
    check "$1: overworld lock art"       'link_is "$CFG/overworld/lock.png" "$OW/assets/renders/lock-day.png"'
    check "$1: hyprlock is overworld's"  'link_is "$CFG/hypr/hyprlock.conf" "$OW/hypr/hyprlock.conf"'
    check "$1: apothecary off"           '[[ ! -e $CFG/apothecary/enabled ]]'
    check "$1: apothecary active off"    'link_is "$CFG/apothecary/active.conf" "$APO/hypr/off.conf"'
    check "$1: compositor started"       '[[ -e $T/started ]]'
}
is_apothecary() {
    check "$1: apothecary enabled"       '[[ -e $CFG/apothecary/enabled ]]'
    check "$1: apothecary active on"     'link_is "$CFG/apothecary/active.conf" "$APO/hypr/on.conf"'
    check "$1: apothecary colours"       'link_is "$CFG/apothecary/colors.conf" "$APO/tokens/out/dark/hyprland-colors.conf"'
    check "$1: apothecary hyprlock vars" 'link_is "$CFG/apothecary/hyprlock-vars.conf" "$APO/tokens/out/dark/hyprlock-vars.conf"'
    check "$1: apothecary kitty"         'link_is "$CFG/apothecary/kitty-colors.conf" "$APO/tokens/out/dark/kitty.conf"'
    check "$1: apothecary lock art"      'link_is "$CFG/apothecary/lock.png" "$APO/assets/art/lock-dark.png"'
    check "$1: hyprlock is apothecary's" 'link_is "$CFG/hypr/hyprlock.conf" "$APO/hypr/hyprlock.conf"'
    check "$1: overworld off"            '[[ ! -e $CFG/overworld/enabled ]]'
    check "$1: overworld active off"     'link_is "$CFG/overworld/active.conf" "$OW/hypr/off.conf"'
    check "$1: no previous-theme"        '[[ ! -e $CFG/overworld/previous-theme ]]'
    check "$1: compositor started"       '[[ -e $T/started ]]'
}
is_stock() {
    check "$1: overworld off"            '[[ ! -e $CFG/overworld/enabled ]]'
    check "$1: apothecary off"           '[[ ! -e $CFG/apothecary/enabled ]]'
    check "$1: overworld active off"     'link_is "$CFG/overworld/active.conf" "$OW/hypr/off.conf"'
    check "$1: apothecary active off"    'link_is "$CFG/apothecary/active.conf" "$APO/hypr/off.conf"'
    check "$1: stock hyprlock is back"   '[[ ! -L $CFG/hypr/hyprlock.conf && "$(cat "$CFG/hypr/hyprlock.conf")" == "$STOCK_LOCK" ]]'
    check "$1: no hyprlock backups left" '[[ -z $(ls "$CFG/hypr" | grep "hyprlock.conf\.") ]]'
    check "$1: no previous-theme"        '[[ ! -e $CFG/overworld/previous-theme ]]'
    check "$1: compositor started"       '[[ -e $T/started ]]'
}
no_live_calls() { check "$1: touched nothing live" '[[ ! -s $T/traps ]]'; }
apps_are() { want="$2"; check "$1: apps [$2]" '[[ "$(paste -sd";" "$T/apps.log" 2>/dev/null)" == "$want" ]]'; rm -f "${T:?}/apps.log"; }

# ---- the transitions, one after the other on the same home --------------------------------------------------------------
fresh
session overworld;  is_overworld "stock→overworld"
check "stock→overworld: previous-theme" '[[ "$(cat "$CFG/overworld/previous-theme")" == stock ]]'
check "stock→overworld: stock lock kept" '[[ "$(cat "$CFG/hypr/hyprlock.conf.pre-overworld")" == "$STOCK_LOCK" ]]'
check "session env" 'grep -q "^DESKTOP_SESSION=hyprland XDG_SESSION_DESKTOP=Hyprland " "$T/started"'
apps_are "stock→overworld" "overworld light"

before="$(tree_state)"; rm -f "${T:?}/started"
session overworld;  is_overworld "overworld again"
check "overworld again: nothing changed" '[[ "$before" == "$(tree_state)" ]]'
apps_are "overworld again" ""

rm -f "${T:?}/started"
session apothecary; is_apothecary "overworld→apothecary"
apps_are "overworld→apothecary" "overworld off --no-handback;apothecary dark"
check "overworld→apothecary: stock lock under apothecary's" '[[ "$(cat "$CFG/hypr/hyprlock.conf.pre-apothecary")" == "$STOCK_LOCK" ]]'

before="$(tree_state)"; rm -f "${T:?}/started"
session apothecary; is_apothecary "apothecary again"
check "apothecary again: nothing changed" '[[ "$before" == "$(tree_state)" ]]'
apps_are "apothecary again" ""

rm -f "${T:?}/started"
session stock;      is_stock "apothecary→stock"
apps_are "apothecary→stock" "apothecary off"

before="$(tree_state)"; rm -f "${T:?}/started"
session stock;      is_stock "stock again"
check "stock again: nothing changed" '[[ "$before" == "$(tree_state)" ]]'
apps_are "stock again" ""

rm -f "${T:?}/started"
session apothecary; is_apothecary "stock→apothecary"
apps_are "stock→apothecary" "apothecary dark"

rm -f "${T:?}/started"
session overworld;  is_overworld "apothecary→overworld"
check "apothecary→overworld: previous-theme remembers" '[[ "$(cat "$CFG/overworld/previous-theme")" == "apothecary dark" ]]'
check "apothecary→overworld: its lock is kept as a link" 'link_is "$CFG/hypr/hyprlock.conf.pre-overworld" "$APO/hypr/hyprlock.conf"'
check "apothecary→overworld: stock lock still under it" '[[ "$(cat "$CFG/hypr/hyprlock.conf.pre-apothecary")" == "$STOCK_LOCK" ]]'
apps_are "apothecary→overworld" "apothecary off;overworld light"

rm -f "${T:?}/started"
session stock;      is_stock "overworld→stock, chain of both locks"
apps_are "overworld→stock" "overworld off --no-handback"
no_live_calls "all transitions"
check "log written" 'grep -q "session: overworld" "$HOMEDIR/.cache/hypr-theme-session.log"'

# ---- prev-wallpaper and game mode ---------------------------------------------------------------------------------------
fresh
echo /wall/stock.png >"$CFG/overworld/prev-wallpaper"; touch "$CFG/overworld/enabled"; ln -sfn "$OW/hypr/on.conf" "$CFG/overworld/active.conf"; echo stock >"$CFG/overworld/previous-theme"; echo spectator >"$CFG/overworld/gamemode"
session apothecary
check "overworld→apothecary: stock wallpaper handed over" '[[ "$(cat "$CFG/apothecary/prev-wallpaper")" == /wall/stock.png ]]'
check "overworld→apothecary: overworld's copy gone" '[[ ! -e $CFG/overworld/prev-wallpaper ]]'
check "overworld off: game mode back to survival" '[[ "$(cat "$CFG/overworld/gamemode")" == survival ]]'

# ---- a theme that is not there ------------------------------------------------------------------------------------------
fresh; session overworld; rm -f "${T:?}/started" "${T:?}/apps.log"
rm -rf "${OW:?}"
session overworld
check "overworld repo gone: compositor started" '[[ -e $T/started ]]'
check "overworld repo gone: disabled" '[[ ! -e $CFG/overworld/enabled ]]'
check "overworld repo gone: active.conf is an empty file" '[[ -f $CFG/overworld/active.conf && ! -L $CFG/overworld/active.conf && ! -s $CFG/overworld/active.conf ]]'
check "overworld repo gone: stock hyprlock healed" '[[ ! -L $CFG/hypr/hyprlock.conf && "$(cat "$CFG/hypr/hyprlock.conf")" == "$STOCK_LOCK" ]]'
check "overworld repo gone: logged" 'grep -q "overworld is not installed: falling back to stock" "$HOMEDIR/.cache/hypr-theme-session.log"'

fresh; session apothecary; rm -f "${T:?}/started" "${T:?}/apps.log"
rm -rf "${APO:?}"
session apothecary
check "apothecary repo gone: compositor started" '[[ -e $T/started ]]'
check "apothecary repo gone: disabled" '[[ ! -e $CFG/apothecary/enabled ]]'
check "apothecary repo gone: stock hyprlock healed" '[[ ! -L $CFG/hypr/hyprlock.conf && "$(cat "$CFG/hypr/hyprlock.conf")" == "$STOCK_LOCK" ]]'

fresh; rm -rf "${OW:?}" "${APO:?}" "${CFG:?}/overworld" "${CFG:?}/apothecary" "${HOMEDIR:?}/.local/bin"
session stock
check "no theme at all: compositor started" '[[ -e $T/started ]]'
check "no theme at all: no state invented" '[[ ! -e $CFG/overworld && ! -e $CFG/apothecary ]]'

fresh; sed -i '/overworld.conf/d' "$CFG/hypr/hyprland.conf"
session overworld
check "no Hyprland hook: not enabled" '[[ ! -e $CFG/overworld/enabled ]]'
check "no Hyprland hook: compositor started" '[[ -e $T/started ]]'

fresh; session bogus
is_stock "unknown theme name"

fresh; printf '#!/bin/sh\nexit 3\n' >"$OW/scripts/overworld"; session overworld
check "overworld CLI broken: compositor started" '[[ -e $T/started ]]'
check "overworld CLI broken: logged" 'grep -q "switch to overworld failed" "$HOMEDIR/.cache/hypr-theme-session.log"'

# ---- slow apps must not hold the login ------------------------------------------------------------------------------------
fresh
t0="$(date +%s)"; APPS_DELAY=12 session overworld; t1="$(date +%s)"
check "slow apps: login waits at most ~6 s (took $((t1 - t0)) s)" '(( t1 - t0 <= 8 ))'
check "slow apps: compositor started" '[[ -e $T/started ]]'
check "slow apps: logged" 'grep -q "still running, starting Hyprland anyway" "$HOMEDIR/.cache/hypr-theme-session.log"'

printf '%d checks passed\n' "$passed"
(( fail == 0 )) && echo "theme-session: ALL OK"
exit "$fail"
