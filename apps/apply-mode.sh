#!/usr/bin/env bash
# apps/apply-mode.sh <light|dark|off> — flip every application theme live.
#
#   light / dark : point every ~/.config/overworld/<app>/current* symlink at that mode, set gsettings
#                  (color-scheme, gtk-theme, icon-theme, cursor-theme), reload kitty, re-apply spicetify.
#   off          : put the user's pre-theme values back (recorded by apps/install.sh in apps-state.json):
#                  symlinks point at the `.pre-overworld` backups, sed'd keys are restored, gsettings restored.
# Idempotent. Needs apps/install.sh to have run. Restarts nothing except a kitty config reload (SIGUSR1).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MODE="${1:-}"
case "$MODE" in light|dark|off) ;; *) die "usage: apply-mode.sh <light|dark|off>" ;; esac
[[ -f "$APPS_STATE" ]] || die "not installed — run apps/install.sh first"

# `off` target for a user file we replaced: its backup, else an empty file
off_target() {   # off_target <userfile> <fallback>
  if [[ -e "$1.pre-$MARK" ]]; then echo "$1.pre-$MARK"; else echo "$2"; fi
}
EMPTY="$STATE_DIR/empty"; : > "$EMPTY"

# ---------------------------------------------------------------- kitty
if [[ "$MODE" == off ]]; then link "$APPS/kitty/off.conf" "$STATE_DIR/kitty/current.conf"
else link "$APPS/kitty/overworld-$MODE.conf" "$STATE_DIR/kitty/current.conf"; fi
kitty_reload() {
  # live switch: remote control on every socket if listen_on is configured, else a config reload signal
  local s found=0
  for s in /tmp/kitty* "${XDG_RUNTIME_DIR:-/run/user/$UID}"/kitty*; do
    [[ -S "$s" ]] || continue; found=1
    if [[ "$MODE" == off ]]; then kitty @ --to "unix:$s" set-colors --all --configured --reset >/dev/null 2>&1 || true
    else kitty @ --to "unix:$s" set-colors --all --configured "$TOKENS/$MODE/kitty.conf" >/dev/null 2>&1 || true; fi
  done
  pkill -USR1 -x kitty 2>/dev/null || true     # reload kitty.conf (picks up the flipped include)
  [[ $found == 1 ]] || true
}
kitty_reload

# ---------------------------------------------------------------- fastfetch
if [[ "$MODE" == off ]]; then
  link "$(off_target "$CFG/fastfetch/config.jsonc" "$APPS/fastfetch/overworld-ascii.jsonc")" "$STATE_DIR/fastfetch/current.jsonc"
else
  link "$APPS/fastfetch/overworld-$MODE.jsonc" "$STATE_DIR/fastfetch/current.jsonc"
  # square logo (shown at 40x18 cells = 360x360 px, no stretch); tall 420x500 art as fallback
  logo=""
  for cand in fastfetch-maomao-square fastfetch-maomao; do
    [[ "$MODE" == dark && -f "$REPO/assets/art/$cand-dark.png" ]] && { logo="$REPO/assets/art/$cand-dark.png"; break; }
    [[ -f "$REPO/assets/art/$cand.png" ]] && { logo="$REPO/assets/art/$cand.png"; break; }
  done
  if [[ -f "$logo" ]]; then link "$logo" "$STATE_DIR/fastfetch/logo.png"
  else link "$APPS/fastfetch/overworld-ascii.jsonc" "$STATE_DIR/fastfetch/current.jsonc"; fi
fi

# ---------------------------------------------------------------- rofi
if [[ "$MODE" == off ]]; then
  orig="$(state_get '.keys["rofi.original_theme"]')"
  if [[ -n "$orig" && "$orig" != "__absent__" ]]; then link "${orig/#\~/$HOME}" "$STATE_DIR/rofi/current.rasi"
  else link "$EMPTY" "$STATE_DIR/rofi/current.rasi"; fi
else
  link "$TOKENS/$MODE/rofi-colors.rasi" "$STATE_DIR/rofi/colors.rasi"
  link "$APPS/rofi/overworld.rasi" "$STATE_DIR/rofi/current.rasi"
fi

# ---------------------------------------------------------------- GTK + gsettings + xsettingsd + cursor
if [[ "$MODE" == off ]]; then
  link "$(off_target "$CFG/gtk-3.0/gtk.css" "$EMPTY")" "$STATE_DIR/gtk/current-gtk3.css"
  link "$(off_target "$CFG/gtk-4.0/gtk.css" "$EMPTY")" "$STATE_DIR/gtk/current-gtk4.css"
  link "$(off_target "$CFG/xsettingsd/xsettingsd.conf" "$EMPTY")" "$STATE_DIR/gtk/current-xsettingsd.conf"
  for k in "${GS_KEYS[@]}"; do
    v="$(state_get ".gsettings[\"$k\"]")"; [[ -n "$v" ]] && gset "$k" "$v"
  done
  cur="$(state_get '.gsettings["cursor-theme"]' | tr -d "'")"
else
  link "$STATE_DIR/gtk/gtk3-$MODE.css" "$STATE_DIR/gtk/current-gtk3.css"
  link "$STATE_DIR/gtk/gtk4-$MODE.css" "$STATE_DIR/gtk/current-gtk4.css"
  link "$APPS/gtk/xsettingsd-$MODE.conf" "$STATE_DIR/gtk/current-xsettingsd.conf"
  if [[ "$MODE" == dark ]]; then
    gtk_theme="Flat-Remix-GTK-Blue-Dark"; [[ -d "$HOME/.themes/$gtk_theme" || -d /usr/share/themes/$gtk_theme ]] || gtk_theme="Adwaita-dark"
    icons="Papirus-Dark"; cur="Bibata-Modern-Classic"; [[ -d "$HOME/.icons/$cur" || -d /usr/share/icons/$cur ]] || cur="Bibata-Modern-Ice"
    scheme="prefer-dark"
  else
    gtk_theme="Flat-Remix-GTK-Blue-Light"; [[ -d "$HOME/.themes/$gtk_theme" || -d /usr/share/themes/$gtk_theme ]] || gtk_theme="Adwaita"
    icons="Papirus-Light"; cur="Bibata-Modern-Ice"; scheme="prefer-light"
  fi
  gset color-scheme "$scheme"; gset gtk-theme "$gtk_theme"; gset icon-theme "$icons"; gset cursor-theme "$cur"; gset font-name "'Noto Sans 10'"
fi
pgrep -x xsettingsd >/dev/null 2>&1 && pkill -HUP -x xsettingsd || true
if have hyprctl && [[ -n "${cur:-}" ]]; then hyprctl setcursor "$cur" 24 >/dev/null 2>&1 || true; fi

# ---------------------------------------------------------------- Qt: qt6ct + Kvantum
qt="$CFG/qt6ct/qt6ct.conf"; kv="$CFG/Kvantum/kvantum.kvconfig"
if [[ "$MODE" == off ]]; then
  restore_kv "$qt" color_scheme_path ini; restore_kv "$qt" style ini; restore_kv "$qt" icon_theme ini
  restore_kv "$qt" general ini; restore_kv "$qt" fixed ini
  restore_kv "$kv" theme ini
else
  link "$CFG/qt6ct/colors/overworld-$MODE.conf" "$STATE_DIR/qt6ct/current.conf"
  set_kv "$qt" color_scheme_path "$STATE_DIR/qt6ct/current.conf" ini
  set_kv "$qt" style kvantum ini
  set_kv "$qt" icon_theme "$([[ $MODE == dark ]] && echo Papirus-Dark || echo Papirus-Light)" ini
  set_kv "$qt" general '"Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular"' ini
  set_kv "$qt" fixed   '"JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular"' ini
  set_kv "$kv" theme "$([[ $MODE == dark ]] && echo OverworldDark || echo OverworldLight)" ini
fi

# ---------------------------------------------------------------- superfile / btop (single-key sed)
spf="$CFG/superfile/config.toml"; bt="$CFG/btop/btop.conf"
if [[ "$MODE" == off ]]; then
  for k in theme transparent_background default_open_file_preview nerdfont editor zoxide_support; do
    style=toml; [[ $k == theme || $k == editor ]] || style=toml-raw; restore_kv "$spf" "$k" "$style"
  done
  restore_kv "$bt" color_theme toml; restore_kv "$bt" theme_background toml-raw
else
  [[ -f "$spf" ]] && set_kv "$spf" theme "overworld-$MODE" toml
  [[ -f "$bt" ]]  && set_kv "$bt" color_theme "overworld-$MODE" toml
fi

# ---------------------------------------------------------------- cava / wlogout / swappy (symlinked whole files)
if [[ "$MODE" == off ]]; then
  link "$(off_target "$CFG/cava/config" "$APPS/cava/config-light")" "$STATE_DIR/cava/current"
  link "$(off_target "$CFG/wlogout/style.css" "$STATE_DIR/wlogout/style-light.css")" "$STATE_DIR/wlogout/current.css"
  link "$(off_target "$CFG/wlogout/layout" "$APPS/wlogout/layout")" "$STATE_DIR/wlogout/current-layout"
  link "$(off_target "$CFG/swappy/config" "$APPS/swappy/config-light")" "$STATE_DIR/swappy/current"
else
  link "$APPS/cava/config-$MODE" "$STATE_DIR/cava/current"
  link "$STATE_DIR/wlogout/style-$MODE.css" "$STATE_DIR/wlogout/current.css"
  link "$APPS/wlogout/layout" "$STATE_DIR/wlogout/current-layout"
  link "$APPS/swappy/config-$MODE" "$STATE_DIR/swappy/current"
fi

# ---------------------------------------------------------------- starship (palette line in the generated file)
st="$STATE_DIR/starship/overworld.toml"
if [[ -f "$st" ]]; then
  if [[ "$MODE" == off ]]; then
    # ~/.config/starship.toml goes back to the user's preset (or disappears if they had none)
    if [[ -e "$CFG/starship.toml.pre-$MARK" ]]; then rm -f "$CFG/starship.toml"; cp -a "$CFG/starship.toml.pre-$MARK" "$CFG/starship.toml"
    elif [[ -L "$CFG/starship.toml" && "$(readlink -f "$CFG/starship.toml")" == "$STATE_DIR"/* ]]; then rm -f "$CFG/starship.toml"; fi
  else
    sed -i -E "s|^palette = .*|palette = \"overworld_$MODE\"|" "$st"
    ln -sfn "$CFG/starship/overworld.toml" "$CFG/starship.toml"
  fi
fi

# ---------------------------------------------------------------- spicetify (only if the CLI works)
if have spicetify; then
  if [[ "$MODE" == off ]]; then
    t="$(state_get '.keys["spicetify.current_theme"]')"; c="$(state_get '.keys["spicetify.color_scheme"]')"
    [[ -n "$t" ]] && spicetify config current_theme "$t" color_scheme "$c" >/dev/null 2>&1 && spicetify apply >/dev/null 2>&1 || true
  else
    spicetify config current_theme Overworld color_scheme "$MODE" >/dev/null 2>&1 && spicetify apply >/dev/null 2>&1 || warn "spicetify apply failed"
  fi
fi
# Zen follows gsettings color-scheme through the portal (one CSS file, @media prefers-color-scheme) — nothing to flip.

echo "$MODE" > "$STATE_DIR/apps-mode"
log "apps → $MODE"
