#!/usr/bin/env bash
# The install and its revert, for real but inside a scratch root (HYPRTHEMES_TEST_ROOT), starting from a copy of this machine's /etc/sddm.conf. No sudo.
set -u
HERE="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
T="$(mktemp -d /tmp/hyprthemes-install.XXXXXX)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

mkdir -p "$T/root/etc"
cp /etc/sddm.conf "$T/root/etc/sddm.conf"; chmod u+w "$T/root/etc/sddm.conf"
cp "$T/root/etc/sddm.conf" "$T/original"
R="$T/root"
run() { HYPRTHEMES_TEST_ROOT="$R" "$REPO/scripts/install-sddm.sh" "$@" >>"$T/log" 2>&1; }

run hyprthemes || bad "install ran"
check "theme installed"            '[[ -r $R/usr/share/sddm/themes/hyprthemes/Main.qml && -r $R/usr/share/sddm/themes/hyprthemes/theme.conf ]]'
check "three looks"                '[[ -r $R/usr/share/sddm/themes/hyprthemes/looks/silent/Main.qml && -r $R/usr/share/sddm/themes/hyprthemes/looks/overworld/Main.qml && -r $R/usr/share/sddm/themes/hyprthemes/looks/apothecary/Main.qml ]]'
check "three sessions"             '[[ -r $R/usr/share/wayland-sessions/hyprland-overworld.desktop && -r $R/usr/share/wayland-sessions/hyprland-apothecary.desktop && -r $R/usr/share/wayland-sessions/hyprland-stock.desktop ]]'
check "session wrapper executable" '[[ -x $R/usr/local/bin/hypr-theme-session ]]'
check "state dir"                  '[[ -d $R/var/lib/sddm/.config/hyprthemes ]]'
check "backup is the original"     'cmp -s "$T/original" "$R/etc/sddm.conf.pre-hyprthemes"'
check "no Current=silent left"     '! grep -q "^Current=silent" "$R/etc/sddm.conf"'
check "both Current= lines moved"  '[[ $(grep -c "^Current=hyprthemes" "$R/etc/sddm.conf") == $(grep -c "^Current=" "$T/original") ]]'
check "commented Current untouched" '[[ $(grep -c "^#Current=" "$R/etc/sddm.conf") == $(grep -c "^#Current=" "$T/original") ]]'
check "keyboard env added once"    '[[ $(grep -c "QT_VIRTUALKEYBOARD_DESKTOP_DISABLE=1" "$R/etc/sddm.conf") == 1 ]]'
check "Silent env kept"            'grep -q "^GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard,QT_VIRTUALKEYBOARD" "$R/etc/sddm.conf"'
check "no other line changed"      '[[ $(diff "$T/original" "$R/etc/sddm.conf" | grep -c "^>") == $(( $(grep -c "^Current=" "$T/original") + 1 )) ]]'
check "state file points at sddm home" 'grep -q "^StateFile=$R/var/lib/sddm/.config/hyprthemes/greeter.conf" "$R/usr/share/sddm/themes/hyprthemes/theme.conf"'
cp "$R/etc/sddm.conf" "$T/installed"

run hyprthemes || bad "second install ran"
check "install twice: same conf"   'cmp -s "$T/installed" "$R/etc/sddm.conf"'
check "install twice: same backup" 'cmp -s "$T/original" "$R/etc/sddm.conf.pre-hyprthemes"'

run revert || bad "revert ran"
check "revert: conf byte for byte" 'cmp -s "$T/original" "$R/etc/sddm.conf"'
check "revert: backup gone"        '[[ ! -e $R/etc/sddm.conf.pre-hyprthemes ]]'
check "revert: theme gone"         '[[ ! -e $R/usr/share/sddm/themes/hyprthemes ]]'
check "revert: sessions gone"      '[[ -z $(ls -A "$R/usr/share/wayland-sessions") ]]'
check "revert: wrapper gone"       '[[ ! -e $R/usr/local/bin/hypr-theme-session ]]'
check "revert: state gone"         '[[ ! -e $R/var/lib/sddm/.config/hyprthemes ]]'

run hyprthemes || bad "third install ran"
sed -i 's/^#Numlock=none/Numlock=on/' "$R/etc/sddm.conf"
run revert || bad "revert after an edit ran"
check "edited file: edit kept"     'grep -q "^Numlock=on" "$R/etc/sddm.conf"'
check "edited file: theme back"    '[[ $(grep -c "^Current=silent" "$R/etc/sddm.conf") == $(grep -c "^Current=" "$T/original") ]]'
check "edited file: env back"      '! grep -q QT_VIRTUALKEYBOARD "$R/etc/sddm.conf"'
check "edited file: only the edit differs" '[[ $(diff "$T/original" "$R/etc/sddm.conf" | grep -c "^>") == 1 ]]'

sed -i '/^GreeterEnvironment=/d' "$T/original"; cp "$T/original" "$R/etc/sddm.conf"
run hyprthemes || bad "install without GreeterEnvironment ran"
check "no env line: one is added"  'grep -q "^GreeterEnvironment=QT_VIRTUALKEYBOARD_DESKTOP_DISABLE=1$" "$R/etc/sddm.conf"'
run revert
check "no env line: revert exact"  'cmp -s "$T/original" "$R/etc/sddm.conf"'

(( fail == 0 )) || { echo "--- log"; tail -20 "$T/log"; }
exit "$fail"
