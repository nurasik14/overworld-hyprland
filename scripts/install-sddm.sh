#!/usr/bin/env bash
# Overworld Hyprland — SDDM login theme installer.
#
#   scripts/install-sddm.sh prepare [auto|light|dark]    no sudo: fill sddm/overworld/ with the font, button sprites, panorama
#                                                        strips, wordmark, splashes.js, quotes.js and theme.conf. Needed before
#                                                        test mode: sddm-greeter-qt6 --test-mode --theme sddm/overworld
#   sudo scripts/install-sddm.sh [auto|light|dark]       the sudo steps: prepare (as the invoking user's files), copy the theme
#                                                        to /usr/share/sddm/themes/overworld, back up /etc/sddm.conf and set
#                                                        [Theme] Current=overworld. Prints how to revert.
#   sudo scripts/install-sddm.sh revert                  undo whichever of the two installs is in place: hyprthemes (below) first, else
#                                                        restore /etc/sddm.conf from the backup (theme dir is left in place).
#
#   scripts/install-sddm.sh prepare hyprthemes [dir]     no sudo: build the wrapper theme with the theme button (three looks + merged theme.conf)
#                                                        into a staging dir, default sddm/.staging/hyprthemes. See docs/LOGIN.md.
#   sudo scripts/install-sddm.sh hyprthemes              the sudo steps: build, copy to /usr/share/sddm/themes/hyprthemes, install the three
#                                                        "Hyprland · …" sessions and /usr/local/bin/hypr-theme-session, set Current=hyprthemes.
#
# Modes: auto = Day or Night panorama by the clock at the login screen (default); light / dark pin one.
# SDDM runs the greeter as its own user, so it cannot read ~/… — everything the theme needs is copied INTO the theme dir.
set -euo pipefail

REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd -P)"
THEME_SRC="$REPO/sddm/overworld"
THEME_DST="/usr/share/sddm/themes/overworld"
ROOT="${HYPRTHEMES_TEST_ROOT:-}"          # sddm/hyprthemes/test/test-install.sh runs the whole install and revert inside a scratch dir
SDDM_CONF="$ROOT/etc/sddm.conf"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
FONT_SRC="$REAL_HOME/.local/share/fonts/overworld"

WRAPPER_SRC="$REPO/sddm/hyprthemes"
WRAPPER_STAGE="$REPO/sddm/.staging/hyprthemes"
WRAPPER_DST="$ROOT/usr/share/sddm/themes/hyprthemes"
SILENT_SRC="/usr/share/sddm/themes/silent"
SESSION_DST="$ROOT/usr/share/wayland-sessions"
SESSION_FILES=(hyprland-overworld.desktop hyprland-apothecary.desktop hyprland-stock.desktop)
THEME_SESSION_DST="$ROOT/usr/local/bin/hypr-theme-session"
VK_ENV="QT_VIRTUALKEYBOARD_DESKTOP_DISABLE=1"
CONF_BACKUP="$SDDM_CONF.pre-hyprthemes"

say() { printf '  %s\n' "$*"; }

prepare() {
    local mode="${1:-auto}"
    [[ "$mode" == "auto" || "$mode" == "light" || "$mode" == "dark" ]] || { echo "mode must be auto|light|dark" >&2; exit 2; }
    echo "prepare sddm/overworld (mode=$mode)"
    mkdir -p "$THEME_SRC/fonts" "$THEME_SRC/backgrounds" "$THEME_SRC/gui"

    # the font the greeter cannot see otherwise
    local f
    for f in OverworldMojangles-Regular.ttf OverworldMojangles-Bold.ttf; do
        if [[ -r "$REPO/assets/fonts/$f" ]]; then cp -f "$REPO/assets/fonts/$f" "$THEME_SRC/fonts/$f"
        elif [[ -r "$FONT_SRC/$f" ]]; then cp -f "$FONT_SRC/$f" "$THEME_SRC/fonts/$f"
        else say "font missing: $f (Qt will fall back)"; fi
    done

    # button and text-field sprites: Mojang's if the assets are there, else asset-forge's original fallback art
    local sprite src
    for sprite in button button_highlighted button_disabled text_field text_field_highlighted; do
        src="$REPO/assets/mc/textures/gui/sprites/widget/$sprite.png"
        [[ -r "$src" ]] || src="$REPO/assets/gen/textures/gui/sprites/widget/$sprite.png"
        if [[ -r "$src" ]]; then cp -f "$src" "$THEME_SRC/gui/$sprite.png"; else say "sprite missing: $sprite"; fi
    done

    # wordmark: the real-texture render, else the committed original
    src="$REPO/assets/renders/wordmark.png"; [[ -r "$src" ]] || src="$REPO/assets/gen/wordmark/overworld.png"
    if [[ -r "$src" ]]; then cp -f "$src" "$THEME_SRC/wordmark.png"; else say "wordmark missing"; fi

    # the panorama strips, seamless at their left and right edges (assets/renders is gitignored; tools/worldgen makes it)
    local pair
    for pair in strip.png:strip-day.png strip-night.png:strip-night.png; do
        src="$REPO/assets/renders/panorama/${pair%%:*}"
        if [[ -r "$src" ]]; then cp -f "$src" "$THEME_SRC/backgrounds/${pair##*:}"
        else say "panorama missing: $src (plain sky colour instead; docs/WORLDGEN.md)"; fi
    done

    # splashes.js and quotes.js from quotes/ (text only)
    python3 - "$REPO" "$THEME_SRC" <<'PY'
import json, sys
repo, dst = sys.argv[1], sys.argv[2]
try:
    with open(f'{repo}/quotes/splashes.json') as fh: d = json.load(fh)
    items = [{'text': x['text'], **x.get('seasonal', {})} for x in d['splashes'] if x.get('text')]
except Exception:
    items = [{'text': 'Press Enter!'}]
open(f'{dst}/splashes.js', 'w').write('// generated by scripts/install-sddm.sh from quotes/splashes.json\n.pragma library\nvar splashes = '
    + json.dumps(items, ensure_ascii=False, indent=0) + ';\n')
print(f'  splashes.js written ({len(items)} lines)')
try:
    with open(f'{repo}/quotes/quotes.json') as fh: q = json.load(fh)
    items = [{'text': x.get('text', ''), 'by': x.get('attribution', '') or ''} for x in q if x.get('text')]
except Exception:
    items = [{'text': 'The world is still here when you get back.', 'by': ''}]
open(f'{dst}/quotes.js', 'w').write('// generated by scripts/install-sddm.sh from quotes/quotes.json\n.pragma library\nvar quotes = '
    + json.dumps(items, ensure_ascii=False, indent=0) + ';\n')
print(f'  quotes.js written ({len(items)} quotes)')
PY

    cat >"$THEME_SRC/theme.conf" <<EOF
# Overworld SDDM theme — rewritten by scripts/install-sddm.sh prepare <mode>
[General]
Mode=$mode
EOF
    say "theme.conf: Mode=$mode"
    [[ "$REAL_USER" != "$USER" ]] && chown -R "$REAL_USER" "$THEME_SRC" 2>/dev/null || true
}

install_root() {
    local mode="${1:-auto}"
    [[ $EUID -eq 0 ]] || { echo "install needs sudo: sudo $0 $mode   (or: $0 prepare $mode  for test mode only)"; exit 1; }
    prepare "$mode"
    echo "install → $THEME_DST"
    rm -rf "$THEME_DST"
    cp -r "$THEME_SRC" "$THEME_DST"
    chmod -R a+rX "$THEME_DST"
    say "copied ($(du -sh "$THEME_DST" | cut -f1))"
    if [[ -f "$SDDM_CONF" ]]; then
        [[ -e "$SDDM_CONF.pre-overworld" ]] || cp -p "$SDDM_CONF" "$SDDM_CONF.pre-overworld"
        if grep -qE '^\[Theme\]' "$SDDM_CONF"; then
            # set Current= inside EVERY [Theme] section (the file on this machine has two)
            awk 'BEGIN{s=0} /^\[/{s=($0=="[Theme]")} s && /^Current=/{print "Current=overworld"; next} {print}' "$SDDM_CONF" >"$SDDM_CONF.tmp"
            grep -qE '^Current=overworld' "$SDDM_CONF.tmp" || printf '\n[Theme]\nCurrent=overworld\n' >>"$SDDM_CONF.tmp"
            mv "$SDDM_CONF.tmp" "$SDDM_CONF"
        else
            printf '\n[Theme]\nCurrent=overworld\n' >>"$SDDM_CONF"
        fi
        say "$SDDM_CONF: [Theme] Current=overworld (backup: $SDDM_CONF.pre-overworld)"
    else
        printf '[Theme]\nCurrent=overworld\n' >"$SDDM_CONF"; say "created $SDDM_CONF"
    fi
    cat <<EOF

Done. The Overworld login screen appears at the next logout/reboot (mode: $mode).
Revert:   sudo $0 revert          (restores $SDDM_CONF.pre-overworld; silent theme comes back)
Preview:  sddm-greeter-qt6 --test-mode --theme $THEME_DST
EOF
}

# ---------------------------------------------------------------------------------------------- hyprthemes: the wrapper with the theme button
# The Apothecary theme's source: the repo its state dir points at, else the usual place.
apothecary_theme_src() {
    local r
    r="$(readlink -f "$REAL_HOME/.config/apothecary/repo" 2>/dev/null || true)"
    [[ -n "$r" && -r "$r/sddm/apothecary/Main.qml" ]] || r="$REAL_HOME/Projects/apothecary-hyprland"
    [[ -r "$r/sddm/apothecary/Main.qml" ]] && printf '%s\n' "$r/sddm/apothecary"
    return 0
}

# A look starts on the session the wrapper hands it, and that is the only change the looks' sources get. Fails loudly: a look that kept
# reading sessionModel.lastIndex would look fine and log into the wrong desktop.
patch_session_index() {         # patch_session_index <look dir>
    local n
    n="$(grep -rlF 'sessionModel.lastIndex' --include='*.qml' "$1" | wc -l)"
    (( n > 0 )) || { echo "no sessionModel.lastIndex in $1: this version of the theme is not supported (docs/LOGIN.md)" >&2; exit 1; }
    grep -rlF 'sessionModel.lastIndex' --include='*.qml' "$1" | xargs sed -i 's/sessionModel\.lastIndex/hyprthemesSessionIndex/g'
    if grep -rqF 'sessionModel.lastIndex' --include='*.qml' "$1"; then echo "patching $1 failed" >&2; exit 1; fi
}

# copy_silent <dst>: the look named Waguri, from the theme this machine logs in with today. Only the backgrounds its config uses: the other
# videos are tens of MB and nothing can reach them.
copy_silent() {
    local dst="$1" conf f
    mkdir -p "$dst/backgrounds"
    conf="$(awk -F= '/^ConfigFile=/{print $2; exit}' "$SILENT_SRC/metadata.desktop")"
    [[ -n "$conf" && -r "$SILENT_SRC/$conf" ]] || { echo "cannot read Silent's ConfigFile ($conf)" >&2; return 1; }
    for f in Main.qml qmldir metadata.desktop LICENSE; do [[ -e "$SILENT_SRC/$f" ]] && cp "$SILENT_SRC/$f" "$dst/"; done
    cp -r "$SILENT_SRC/components" "$SILENT_SRC/icons" "$SILENT_SRC/fonts" "$SILENT_SRC/configs" "$dst/"
    cp "$SILENT_SRC/backgrounds/default.jpg" "$dst/backgrounds/" 2>/dev/null || true
    while read -r f; do
        if [[ -r "$SILENT_SRC/backgrounds/$f" ]]; then cp "$SILENT_SRC/backgrounds/$f" "$dst/backgrounds/"
        else say "Silent background missing: $f"; fi
    done < <(sed -nE 's/^(background|animated-background-placeholder)[[:space:]]*=[[:space:]]*"?([^"]+)"?[[:space:]]*$/\2/p' "$SILENT_SRC/$conf" | sort -u)
    printf '%s\n' "$SILENT_SRC/$conf" >"$dst/.source-config"
}

# append_general <theme.conf of a look> <section> >>merged: its [General] keys under a section of their own (LookHost.qml reads them there)
append_general() {
    printf '\n[%s]\n' "$2"
    awk '/^\[/{s=($0=="[General]"); next} s && NF && !/^[;#]/' "$1"
}

default_look() {                # the desktop this user runs now, so the first boot after the install changes nothing but the button
    if [[ -e "$REAL_HOME/.config/overworld/enabled" ]]; then echo overworld
    elif [[ -e "$REAL_HOME/.config/apothecary/enabled" ]]; then echo apothecary
    else echo waguri; fi
}

# build_hyprthemes <dst> <state file the greeter remembers its pick in>
build_hyprthemes() {
    local dst="$1" state_file="$2" looks=() apo silent_conf="" f
    prepare auto
    echo "build hyprthemes → $dst"
    rm -rf "$dst"
    mkdir -p "$dst/looks"
    for f in Main.qml LookHost.qml Fallback.qml looks.js metadata.desktop; do cp "$WRAPPER_SRC/$f" "$dst/$f"; done

    if [[ -r "$SILENT_SRC/Main.qml" ]] && copy_silent "$dst/looks/silent"; then
        silent_conf="$(cat "$dst/looks/silent/.source-config")"; rm -f "$dst/looks/silent/.source-config"
        patch_session_index "$dst/looks/silent"
        looks+=(waguri)
    else
        say "Silent is not in $SILENT_SRC: no Waguri look"
    fi
    cp -r "$THEME_SRC" "$dst/looks/overworld"
    patch_session_index "$dst/looks/overworld"
    looks+=(overworld)
    apo="$(apothecary_theme_src)"
    if [[ -n "$apo" ]]; then
        cp -r "$apo" "$dst/looks/apothecary"
        patch_session_index "$dst/looks/apothecary"
        looks+=(apothecary)
    else
        say "Apothecary's sddm/apothecary was not found: no Apothecary look"
    fi

    # theme.conf: Silent's own config unchanged at the top level (its Config singleton reads SDDM's real `config`), then sections nothing else uses.
    if [[ -n "$silent_conf" ]] && grep -qE '^\[(HyprThemes|look\.)' "$silent_conf"; then
        echo "$silent_conf already has a [HyprThemes] or [look.*] section: refusing to merge" >&2; exit 1
    fi
    {
        if [[ -n "$silent_conf" ]]; then cat "$silent_conf"; fi
        printf '\n[HyprThemes]\nLooks=%s\nDefaultLook=%s\nStateFile=%s\n' "$(IFS=,; echo "${looks[*]}")" "$(default_look)" "$state_file"
        append_general "$dst/looks/overworld/theme.conf" look.overworld
        [[ -z "$apo" ]] || append_general "$dst/looks/apothecary/theme.conf" look.apothecary
    } >"$dst/theme.conf"
    find "$dst" -name .gitignore -delete
    chmod -R a+rX "$dst"
    say "looks: ${looks[*]}, default: $(default_look), size: $(du -sh "$dst" | cut -f1)"
    if [[ "$REAL_USER" != "$USER" ]]; then chown -R "$REAL_USER" "$REPO/sddm/.staging" 2>/dev/null || true; fi
}

# The two edits to /etc/sddm.conf. It has to be this file: it outranks /etc/sddm.conf.d/ (man sddm.conf), so a drop-in loses to its Current=silent.
#   Current=     every one in a [Theme] section (the file on this machine has two sections)
#   GreeterEnvironment gets $VK_ENV. The file sets QT_IM_MODULE=qtvirtualkeyboard for Silent, which has its own on-screen keyboard in the scene.
#                A look without one would get Qt's desktop keyboard instead: a separate window that opens and takes the focus on any text field.
sddm_conf_edited() {
    awk -v env="$VK_ENV" '
        BEGIN { s = 0; seen = 0 }
        /^\[/ { s = ($0 == "[Theme]") }
        s && /^Current=/ { print "Current=hyprthemes"; next }
        /^GreeterEnvironment=/ { seen = 1; if (index($0, env) == 0) $0 = $0 "," env }
        { print }
        END { if (!seen) printf "\n[General]\nGreeterEnvironment=%s\n", env }' "$1"
}

install_hyprthemes() {
    [[ $EUID -eq 0 || -n "$ROOT" ]] || { echo "install needs sudo: sudo $0 hyprthemes   (or: $0 prepare hyprthemes  to build without installing)"; exit 1; }
    [[ -f "$SDDM_CONF" ]] || { echo "$SDDM_CONF not found" >&2; exit 1; }
    local sddm_home; sddm_home="$(getent passwd sddm | cut -d: -f6)"; sddm_home="$ROOT${sddm_home:-/var/lib/sddm}"
    local state_dir="$sddm_home/.config/hyprthemes"

    build_hyprthemes "$WRAPPER_STAGE" "$state_dir/greeter.conf"

    echo "install → $WRAPPER_DST"
    [[ -z "$ROOT" ]] || mkdir -p "$(dirname "$WRAPPER_DST")"
    rm -rf "$WRAPPER_DST"
    cp -r "$WRAPPER_STAGE" "$WRAPPER_DST"
    chmod -R a+rX "$WRAPPER_DST"
    if [[ -n "$ROOT" ]]; then mkdir -p "$state_dir" "$SESSION_DST" "$(dirname "$THEME_SESSION_DST")"
    else install -d -m 0755 -o sddm -g sddm "$sddm_home/.config" "$state_dir"; fi
    local f
    for f in "${SESSION_FILES[@]}"; do install -m 0644 "$REPO/sessions/$f" "$SESSION_DST/$f"; done
    install -m 0755 "$REPO/scripts/theme-session" "$THEME_SESSION_DST"
    say "sessions: ${SESSION_FILES[*]}"
    say "session wrapper: $THEME_SESSION_DST"
    if [[ -z "$ROOT" ]] && command -v restorecon >/dev/null 2>&1; then
        restorecon -RF "$WRAPPER_DST" "$THEME_SESSION_DST" "$sddm_home/.config" >/dev/null 2>&1 || true
        for f in "${SESSION_FILES[@]}"; do restorecon -F "$SESSION_DST/$f" >/dev/null 2>&1 || true; done
    fi

    if [[ ! -e "$CONF_BACKUP" ]]; then cp -p "$SDDM_CONF" "$CONF_BACKUP"; fi
    sddm_conf_edited "$SDDM_CONF" >"$SDDM_CONF.tmp"
    grep -qE '^Current=hyprthemes' "$SDDM_CONF.tmp" || printf '\n[Theme]\nCurrent=hyprthemes\n' >>"$SDDM_CONF.tmp"
    chmod --reference="$SDDM_CONF" "$SDDM_CONF.tmp"
    [[ -n "$ROOT" ]] || chown --reference="$SDDM_CONF" "$SDDM_CONF.tmp"
    mv -f "$SDDM_CONF.tmp" "$SDDM_CONF"
    if [[ -z "$ROOT" ]] && command -v restorecon >/dev/null 2>&1; then restorecon -F "$SDDM_CONF" "$CONF_BACKUP" >/dev/null 2>&1 || true; fi
    say "$SDDM_CONF: [Theme] Current=hyprthemes (backup: $CONF_BACKUP)"
    cat <<EOF

Done. The new login screen appears at the next logout or reboot: Theme button top right, or Alt+T.
Revert (also from a text console, Ctrl+Alt+F3):  sudo $0 revert
EOF
}

revert_hyprthemes() {
    # What the install would make of the backup: if that is today's file, nothing else changed it and the backup goes back byte for byte.
    local expected; expected="$(mktemp)"
    sddm_conf_edited "$CONF_BACKUP" >"$expected"
    grep -qE '^Current=hyprthemes' "$expected" || printf '\n[Theme]\nCurrent=hyprthemes\n' >>"$expected"
    if cmp -s "$expected" "$SDDM_CONF"; then
        mv -f "$CONF_BACKUP" "$SDDM_CONF"
        say "restored $SDDM_CONF"
    else
        # changed since the install: keep those changes and take out only ours
        local old; old="$(awk 'BEGIN{s=0} /^\[/{s=($0=="[Theme]")} s && /^Current=/{v=$0} END{print v}' "$CONF_BACKUP")"; old="${old#Current=}"
        sed -i -e "s/^Current=hyprthemes\$/Current=${old:-silent}/" -e "s/,\?$VK_ENV//" "$SDDM_CONF"
        rm -f "$CONF_BACKUP"
        say "$SDDM_CONF was edited after the install: kept the edits, Current=${old:-silent}"
    fi
    rm -f "$expected"
    if [[ -z "$ROOT" ]] && command -v restorecon >/dev/null 2>&1; then restorecon -F "$SDDM_CONF" >/dev/null 2>&1 || true; fi
    local f sddm_home; sddm_home="$(getent passwd sddm | cut -d: -f6)"; sddm_home="$ROOT${sddm_home:-/var/lib/sddm}"
    rm -rf "$WRAPPER_DST" "$sddm_home/.config/hyprthemes"
    rmdir "$sddm_home/.config" 2>/dev/null || true
    for f in "${SESSION_FILES[@]}"; do rm -f "$SESSION_DST/$f"; done
    rm -f "$THEME_SESSION_DST"
    say "removed $WRAPPER_DST, the three sessions and $THEME_SESSION_DST"
    say "the desktop theme stays as it is now: overworld on|off / apothecary on|off still switch it"
}

revert_root() {
    [[ $EUID -eq 0 || -n "$ROOT" ]] || { echo "revert needs sudo: sudo $0 revert"; exit 1; }
    if [[ -e "$CONF_BACKUP" ]]; then revert_hyprthemes; return 0; fi
    if [[ -e "$SDDM_CONF.pre-overworld" ]]; then
        mv -f "$SDDM_CONF.pre-overworld" "$SDDM_CONF"; say "restored $SDDM_CONF"
    else
        sed -i 's/^Current=overworld/Current=silent/' "$SDDM_CONF"; say "no backup found; set Current=silent"
    fi
    say "theme dir left in place: $THEME_DST (rm -rf it if you want)"
}

case "${1:-}" in
    prepare)
        if [[ "${2:-}" == hyprthemes ]]; then
            stage="${3:-$WRAPPER_STAGE}"
            build_hyprthemes "$stage" "$(dirname "$stage")/greeter-state/greeter.conf"
        else
            prepare "${2:-auto}"
        fi ;;
    hyprthemes)   install_hyprthemes ;;
    revert)       revert_root ;;
    auto|light|dark|"") install_root "${1:-auto}" ;;
    *) echo "usage: $0 prepare [auto|light|dark|hyprthemes [dir]] | sudo $0 [auto|light|dark|hyprthemes] | sudo $0 revert"; exit 2 ;;
esac
