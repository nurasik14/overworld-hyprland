#!/usr/bin/env bash
# apps/apply-mode.sh <light|dark|off> [--link-only] [--no-handback] — flip every application theme live.
#
#   light / dark : (light = Day, dark = Night) point every ~/.config/overworld/<app>/current* link at that mode, set
#                  gsettings (color-scheme, gtk-theme, icon-theme, cursor-theme = Overworld, font), sed the few keys of
#                  qt6ct / Kvantum / superfile / btop, add the Zen @imports, reload kitty.
#                  On every off -> on transition the values the apps hold at that moment are recorded as "pre-theme" and
#                  the previous theme (Apothecary or stock) is detected — see detect_previous in lib.sh.
#   off          : put the pre-theme values back (recorded in apps-state.json): links point at the `.pre-overworld`
#                  backups, sed'd keys + gsettings are restored; then, if Apothecary was the previous theme, hand the apps
#                  back to ITS apps/apply-mode.sh <its mode> (so `overworld off` returns the Apothecary look, not stock).
#   --link-only  : only (re)create links/links targets for the mode, touch no gsettings/keys/processes (apps/install.sh)
#   --no-handback: off without calling Apothecary (apps/uninstall.sh, install.sh)
# Idempotent. Needs apps/install.sh to have run. Restarts nothing except a kitty config reload (SIGUSR1).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MODE="${1:-}"; shift || true
LINK_ONLY=0; HANDBACK=1
for a in "$@"; do case "$a" in --link-only) LINK_ONLY=1 ;; --no-handback) HANDBACK=0 ;; *) die "unknown flag $a" ;; esac; done
case "$MODE" in light|dark|off) ;; *) die "usage: apply-mode.sh <light|dark|off> [--link-only] [--no-handback]" ;; esac
[[ -f "$APPS_STATE" ]] || die "not installed — run apps/install.sh first"

# one apply at a time (the shell may fire several during a mode cross-fade)
exec 9>"$STATE_DIR/.apps.lock"; flock -w 60 9 || die "another apply-mode is running"

PREV="$(current_mode)"
N=""; [[ "$MODE" != off ]] && N="$(dn "$MODE")"
EMPTY="$STATE_DIR/empty"; : > "$EMPTY"

if [[ "$MODE" != off && "$PREV" == off && $LINK_ONLY == 0 ]]; then
  apo_apps_wait          # a just-run `apothecary off` may still be restoring its files/keys
  capture_pre
fi

# `off` target for a user file we replaced: its backup, else a fallback
off_target() {   # off_target <userfile> <fallback>
  if [[ -e "$1.pre-$MARK" || -L "$1.pre-$MARK" ]]; then echo "$1.pre-$MARK"; else echo "$2"; fi
}
live() { [[ $LINK_ONLY == 0 ]]; }

# ---------------------------------------------------------------- kitty
if [[ "$MODE" == off ]]; then link "$APPS/kitty/off.conf" "$STATE_DIR/kitty/current.conf"
else link "$STATE_DIR/kitty/overworld-$MODE.conf" "$STATE_DIR/kitty/current.conf"; fi
kitty_reload() {
  # live switch: remote control on every socket if listen_on is configured, else a config reload signal
  local s
  for s in /tmp/kitty* "${XDG_RUNTIME_DIR:-/run/user/$UID}"/kitty*; do
    [[ -S "$s" ]] || continue
    if [[ "$MODE" == off ]]; then kitty @ --to "unix:$s" set-colors --all --configured --reset >/dev/null 2>&1 || true
    else kitty @ --to "unix:$s" set-colors --all --configured "$TOKENS/$MODE/kitty.conf" >/dev/null 2>&1 || true; fi
  done
  pkill -USR1 -x kitty 2>/dev/null || true     # reload kitty.conf (picks up the flipped include)
}
live && [[ "$PREV" != "$MODE" || $LINK_ONLY == 0 ]] && kitty_reload || true

# ---------------------------------------------------------------- fastfetch
if [[ "$MODE" == off ]]; then
  link "$(off_target "$CFG/fastfetch/config.jsonc" "$STATE_DIR/fastfetch/overworld-ascii-dark.jsonc")" "$STATE_DIR/fastfetch/current.jsonc"
elif [[ -f "$STATE_DIR/fastfetch/logo.png" ]]; then
  link "$STATE_DIR/fastfetch/overworld-$MODE.jsonc" "$STATE_DIR/fastfetch/current.jsonc"
else
  link "$STATE_DIR/fastfetch/overworld-ascii-$MODE.jsonc" "$STATE_DIR/fastfetch/current.jsonc"
fi

# ---------------------------------------------------------------- rofi
if [[ "$MODE" == off ]]; then
  orig="$(state_get '.keys["rofi.original_theme"]')"
  if [[ -n "$orig" && "$orig" != "__absent__" ]]; then link "${orig/#\~/$HOME}" "$STATE_DIR/rofi/current.rasi"
  else link "$EMPTY" "$STATE_DIR/rofi/current.rasi"; fi
else
  link "$STATE_DIR/rofi/colors-$MODE.rasi" "$STATE_DIR/rofi/colors.rasi"
  link "$APPS/rofi/overworld.rasi" "$STATE_DIR/rofi/current.rasi"
fi

# ---------------------------------------------------------------- GTK + xsettingsd
if [[ "$MODE" == off ]]; then
  link "$(off_target "$CFG/gtk-3.0/gtk.css" "$EMPTY")" "$STATE_DIR/gtk/current-gtk3.css"
  link "$(off_target "$CFG/gtk-4.0/gtk.css" "$EMPTY")" "$STATE_DIR/gtk/current-gtk4.css"
  link "$(off_target "$CFG/xsettingsd/xsettingsd.conf" "$EMPTY")" "$STATE_DIR/gtk/current-xsettingsd.conf"
else
  link "$STATE_DIR/gtk/gtk3-$MODE.css" "$STATE_DIR/gtk/current-gtk3.css"
  link "$STATE_DIR/gtk/gtk4-$MODE.css" "$STATE_DIR/gtk/current-gtk4.css"
  link "$APPS/gtk/xsettingsd-$MODE.conf" "$STATE_DIR/gtk/current-xsettingsd.conf"
fi
if live; then
  cur=""
  if [[ "$MODE" == off ]]; then
    for k in "${GS_KEYS[@]}"; do v="$(state_get ".gsettings[\"$k\"]")"; [[ -n "$v" ]] && gset "$k" "$v"; done
    cur="$(state_get '.gsettings["cursor-theme"]' | tr -d "'")"
  else
    if [[ "$MODE" == dark ]]; then
      gtk_theme="Flat-Remix-GTK-Blue-Dark"; [[ -d "$HOME/.themes/$gtk_theme" || -d /usr/share/themes/$gtk_theme ]] || gtk_theme="Adwaita-dark"
      icons="Papirus-Dark"; scheme="prefer-dark"
    else
      gtk_theme="Flat-Remix-GTK-Blue-Light"; [[ -d "$HOME/.themes/$gtk_theme" || -d /usr/share/themes/$gtk_theme ]] || gtk_theme="Adwaita"
      icons="Papirus-Light"; scheme="prefer-light"
    fi
    cur="Overworld"; [[ -d "$HOME/.local/share/icons/Overworld/cursors" || -d "$HOME/.icons/Overworld/cursors" ]] || cur="$(state_get '.gsettings["cursor-theme"]' | tr -d "'")"
    gset color-scheme "$scheme"; gset gtk-theme "$gtk_theme"; gset icon-theme "$icons"
    [[ -n "$cur" ]] && gset cursor-theme "$cur"
    gset font-name "'Overworld Mojangles 12'"
  fi
  pgrep -x xsettingsd >/dev/null 2>&1 && pkill -HUP -x xsettingsd || true
  if have hyprctl && [[ -n "$cur" ]]; then hyprctl setcursor "$cur" 24 >/dev/null 2>&1 || true; fi
fi

# ---------------------------------------------------------------- Qt: qt6ct + Kvantum
qt="$CFG/qt6ct/qt6ct.conf"; kv="$CFG/Kvantum/kvantum.kvconfig"
if [[ "$MODE" != off ]]; then link "$CFG/qt6ct/colors/overworld-$N.conf" "$STATE_DIR/qt6ct/current.conf"; fi
if live; then
  if [[ "$MODE" == off ]]; then
    for k in color_scheme_path style icon_theme general fixed; do restore_kv "$qt" "$k" ini; done
    restore_kv "$kv" theme ini
  else
    set_kv "$qt" color_scheme_path "$STATE_DIR/qt6ct/current.conf" ini
    set_kv "$qt" style kvantum ini
    set_kv "$qt" icon_theme "$([[ $MODE == dark ]] && echo Papirus-Dark || echo Papirus-Light)" ini
    set_kv "$qt" general '"Overworld Mojangles,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular"' ini
    set_kv "$qt" fixed   '"Monocraft,13.5,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular"' ini
    set_kv "$kv" theme "Overworld${N^}" ini
  fi
fi

# ---------------------------------------------------------------- superfile / btop (single-key sed)
spf="$CFG/superfile/config.toml"; bt="$CFG/btop/btop.conf"
if live; then
  if [[ "$MODE" == off ]]; then
    for k in theme transparent_background default_open_file_preview nerdfont editor zoxide_support; do
      style=toml; [[ $k == theme || $k == editor ]] || style=toml-raw; restore_kv "$spf" "$k" "$style"
    done
    restore_kv "$bt" color_theme toml; restore_kv "$bt" theme_background toml-raw
    restore_kv "$bt" rounded_corners toml-raw; restore_kv "$bt" graph_symbol toml
  else
    if [[ -f "$spf" ]]; then
      set_kv "$spf" theme "overworld-$N" toml
      set_kv "$spf" transparent_background true toml-raw
      set_kv "$spf" default_open_file_preview true toml-raw
      set_kv "$spf" nerdfont true toml-raw
      grep -qE '^editor\s*=\s*""' "$spf" && set_kv "$spf" editor nvim toml || true
      have zoxide && set_kv "$spf" zoxide_support true toml-raw || true
    fi
    if [[ -f "$bt" ]]; then
      set_kv "$bt" color_theme "overworld-$N" toml
      set_kv "$bt" theme_background false toml-raw
      set_kv "$bt" rounded_corners false toml-raw     # square corners
      set_kv "$bt" graph_symbol block toml            # chunky blocks instead of braille
    fi
  fi
fi

# ---------------------------------------------------------------- cava / wlogout / swappy (symlinked whole files)
if [[ "$MODE" == off ]]; then
  link "$(off_target "$CFG/cava/config" "$STATE_DIR/cava/config-light")" "$STATE_DIR/cava/current"
  link "$(off_target "$CFG/wlogout/style.css" "$STATE_DIR/wlogout/style-light.css")" "$STATE_DIR/wlogout/current.css"
  link "$(off_target "$CFG/wlogout/layout" "$APPS/wlogout/layout")" "$STATE_DIR/wlogout/current-layout"
  link "$(off_target "$CFG/swappy/config" "$STATE_DIR/swappy/config-light")" "$STATE_DIR/swappy/current"
else
  link "$STATE_DIR/cava/config-$MODE" "$STATE_DIR/cava/current"
  link "$STATE_DIR/wlogout/style-$MODE.css" "$STATE_DIR/wlogout/current.css"
  link "$APPS/wlogout/layout" "$STATE_DIR/wlogout/current-layout"
  link "$STATE_DIR/swappy/config-$MODE" "$STATE_DIR/swappy/current"
fi

# ---------------------------------------------------------------- starship (palette line in the generated file)
st="$STATE_DIR/starship/overworld.toml"
if [[ -f "$st" ]]; then
  if [[ "$MODE" == off ]]; then
    link "$(off_target "$CFG/starship.toml" "$EMPTY")" "$STATE_DIR/starship/current.toml"
  else
    sed -i -E "s|^palette = .*|palette = \"overworld_$MODE\"|" "$st"
    link "$st" "$STATE_DIR/starship/current.toml"
  fi
fi

# ---------------------------------------------------------------- Zen: add/remove the @imports (read at Zen's next start)
# While Overworld is on, Apothecary's @import lines are neutralised (`@import` -> `@ow-off-import`, an unknown at-rule CSS
# skips) so the two themes never stack; `off` puts them back verbatim.
zen_hook() {   # zen_hook on|off
  local prof chrome f imp
  prof="$(state_get '.keys["zen.profile"]')"; [[ -d "$prof" ]] || return 0
  chrome="$prof/chrome"
  for f in userChrome:overworld userContent:overworld-content; do
    local uf="$chrome/${f%%:*}.css" css="${f##*:}.css"
    [[ -f "$uf" ]] || { [[ "$1" == on ]] || continue; : > "$uf"; state_add created "$uf"; }
    if [[ "$1" == on ]]; then
      sed -i -E 's|^@import (url\("apothecary[^"]*"\))|@ow-off-import \1|' "$uf"
      grep -qE -- "$MARK_RE" "$uf" || append_marker "$uf" "@import url(\"$css\"); /* $MARK */"
    else
      sed -i -E "\\@$MARK_RE@d" "$uf"
      sed -i -E 's|^@ow-off-import |@import |' "$uf"
    fi
  done
}
if live; then
  if [[ "$MODE" == off ]]; then zen_hook off; else zen_hook on; fi
fi
# Zen follows gsettings color-scheme through the portal (one CSS file, @media prefers-color-scheme).

# ---------------------------------------------------------------- spicetify (only if the CLI works)
if live && have spicetify; then
  if [[ "$MODE" == off ]]; then
    t="$(state_get '.keys["spicetify.current_theme"]')"; c="$(state_get '.keys["spicetify.color_scheme"]')"
    [[ -n "$t" ]] && spicetify config current_theme "$t" color_scheme "$c" >/dev/null 2>&1 && spicetify apply >/dev/null 2>&1 || true
  else
    state_set_once '.keys["spicetify.current_theme"]' "$(spicetify config current_theme 2>/dev/null || true)"
    state_set_once '.keys["spicetify.color_scheme"]'  "$(spicetify config color_scheme 2>/dev/null || true)"
    spicetify config current_theme Overworld color_scheme "$N" >/dev/null 2>&1 && spicetify apply >/dev/null 2>&1 || warn "spicetify apply failed"
  fi
fi

if live; then
  echo "$MODE" > "$STATE_DIR/apps-mode"
  log "apps -> $MODE"
fi

# ---------------------------------------------------------------- hand the apps back to Apothecary
if [[ "$MODE" == off && $HANDBACK == 1 && $LINK_ONLY == 0 ]]; then
  if [[ "$(state_get '.keys["previous.theme"]')" == apothecary ]]; then
    apo="$(apo_repo)"; am="$(state_get '.keys["previous.apothecary_mode"]')"; [[ "$am" =~ ^(light|dark)$ ]] || am=dark
    if [[ -n "$apo" ]]; then
      log "handing the apps back to Apothecary ($am)"
      flock -u 9      # not our lock any more
      "$apo/apps/apply-mode.sh" "$am" || warn "Apothecary's apply-mode $am failed"
    else warn "previous theme was Apothecary but its repo/apps/apply-mode.sh was not found"; fi
  fi
  state_put '.keys["previous.theme"]' ""
fi
