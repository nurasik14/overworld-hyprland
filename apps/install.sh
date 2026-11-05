#!/usr/bin/env bash
# apps/install.sh — install the Overworld application themes.
#
# Visually a NO-OP: it only adds theme files, `.pre-overworld` backups, marker lines / hooks and the
# ~/.config/overworld/<app>/current* symlinks, then leaves every link in the *off* state (or in whatever mode
# apps/apply-mode.sh last applied, when re-run). It never changes gsettings, sed'd keys or running apps — that is
# apps/apply-mode.sh <light|dark>, so installing on top of a live Apothecary desktop changes nothing you can see.
# Reverse everything with apps/uninstall.sh. Idempotent: run it again after pulling the repo or rebuilding tokens.
set -euo pipefail
case "${1:-}" in -h|--help) sed -n "2,/^[^#]/{/^#/s/^# \{0,1\}//p}" "$0"; exit 0 ;; esac
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

have jq || die "jq is required"
[[ -d "$TOKENS/light" && -d "$TOKENS/dark" ]] || die "tokens not built: run python3 tokens/build.py"

state_init
[[ -e "$STATE_DIR/repo" ]] || ln -sfn "$REPO" "$STATE_DIR/repo"
mkdir -p "$STATE_DIR"/{kitty,fastfetch,rofi,gtk,qt6ct,superfile,cava,btop,starship,wlogout,swappy,zen,nvim}
: > "$STATE_DIR/empty"

# hook_file <userfile> <state-link> [off-fallback]: make <userfile> a symlink to <state-link>, after backing it up
# and pointing <state-link> at the backup (the *off* state) so the swap is invisible.
hook_file() {
  local f="$1" cur="$2" fb="${3:-$STATE_DIR/empty}"
  backup_file "$f"
  if [[ -e "$f.pre-$MARK" || -L "$f.pre-$MARK" ]]; then link "$f.pre-$MARK" "$cur"; else link "$fb" "$cur"; fi
  replace_with_symlink "$f" "$cur"
}
rgbs() { local h; h="$(palette "$1" "$2")"; printf '38;2;%d;%d;%d' "0x${h:1:2}" "0x${h:3:2}" "0x${h:5:2}"; }

# ---------------------------------------------------------------- kitty
install_kitty() {
  local m
  for m in light dark; do
    link "$TOKENS/$m/kitty.conf" "$STATE_DIR/kitty/colors-$m.conf"
    {
      sed "s|@MODE@|$m|g" "$APPS/kitty/overworld.conf"
      # hotbar slots: inactive = recessed slot, active = dark slot + white selection frame (tab_bar.py)
      echo
      echo "# tab slots (from tokens/out/$m/palette.json)"
      echo "tab_bar_background        $(palette $m bg0)"
      echo "tab_bar_margin_color      $(palette $m bg0)"
      echo "inactive_tab_background   $(palette $m surfaceAlt)"
      echo "inactive_tab_foreground   $(palette $m text)"
      echo "active_tab_background     $(palette $m $([[ $m == dark ]] && echo slot || echo slotDark))"
      echo "active_tab_foreground     #ffffff"
    } > "$STATE_DIR/kitty/overworld-$m.conf"
  done
  link "$APPS/kitty/off.conf" "$STATE_DIR/kitty/current.conf"
  [[ -e "$CFG/kitty/tab_bar.py" || -L "$CFG/kitty/tab_bar.py" ]] \
    && { [[ "$(readlink "$CFG/kitty/tab_bar.py" 2>/dev/null)" == "$APPS/kitty/tab_bar.py" ]] || warn "~/.config/kitty/tab_bar.py is yours — hotbar tabs skipped"; } \
    || { link "$APPS/kitty/tab_bar.py" "$CFG/kitty/tab_bar.py"; state_add created "$CFG/kitty/tab_bar.py"; }
  append_marker "$CFG/kitty/kitty.conf" "include ~/.config/overworld/kitty/current.conf"   # the path is the marker (kitty forbids trailing comments on include)
}

# ---------------------------------------------------------------- fastfetch (F3 style + grass-block logo)
install_fastfetch() {
  local m d src
  for m in light dark; do
    for d in overworld overworld-ascii; do
      sed -e "s|@KEYS@|$(rgbs $m accent)|g" -e "s|@TITLE@|$(rgbs $m accent2)|g" -e "s|@OUTPUT@|$(rgbs $m text)|g" \
          -e "s|@SEP@|$(rgbs $m textMuted)|g" -e "s|@GOLD@|$(rgbs $m accent2)|g" -e "s|@GREEN@|$(rgbs $m grassSide)|g" \
          -e "s|@BLACK@|$(rgbs $m $([[ $m == dark ]] && echo deepslate || echo panelOutline))|g" \
          "$APPS/fastfetch/$d.jsonc" > "$STATE_DIR/fastfetch/$d-$m.jsonc"
    done
  done
  # the logo: isometric grass block, 3x nearest-neighbour from the 64 px icon, centred on a 216x216 canvas
  # (= 18 x 8 cells of 12 x 27 px, see the kitty font) so kitty-direct keeps it square
  for src in "$REPO/assets/icons/mc/64/grass_block.png" "$REPO/assets/gen/icons/64/grass_block.png"; do [[ -f "$src" ]] && break; done
  if [[ -f "$src" ]] && have magick; then
    magick "$src" -filter point -resize 192x192 -background none -gravity center -extent 216x216 "$STATE_DIR/fastfetch/logo.png"
  else
    rm -f "$STATE_DIR/fastfetch/logo.png"; warn "grass-block icon (assets/icons/mc/64/) or magick missing — ascii creeper logo will be used"
  fi
  hook_file "$CFG/fastfetch/config.jsonc" "$STATE_DIR/fastfetch/current.jsonc" "$STATE_DIR/fastfetch/overworld-ascii-dark.jsonc"
}

# ---------------------------------------------------------------- rofi
install_rofi() {
  local conf="$CFG/rofi/config.rasi" orig
  # remember the theme the user has active (last @theme line wins in rofi) — Apothecary's link, when it is installed
  if ! grep -qE -- "$MARK_RE" "$conf" 2>/dev/null; then
    orig="$(grep -oP '^\s*@theme\s*"\K[^"]+' "$conf" 2>/dev/null | tail -n1 || true)"
    state_put '.keys["rofi.original_theme"]' "${orig:-__absent__}"
  fi
  link "$TOKENS/light/rofi-colors.rasi" "$STATE_DIR/rofi/colors-light.rasi"
  link "$TOKENS/dark/rofi-colors.rasi"  "$STATE_DIR/rofi/colors-dark.rasi"
  link "$STATE_DIR/empty" "$STATE_DIR/rofi/current.rasi"
  link "$TOKENS/light/rofi-colors.rasi" "$STATE_DIR/rofi/colors.rasi"
  append_marker "$conf" "@theme \"~/.config/overworld/rofi/current.rasi\" /* $MARK */"
}

# ---------------------------------------------------------------- GTK 3/4 + xsettingsd
build_gtk_css() {   # concatenate tokens + our tweaks into real files (GTK @import paths are brittle through symlinks)
  local m
  for m in light dark; do
    { echo "/* overworld gtk3 — $m (generated by apps/install.sh: tokens gtk-colors.css + apps/gtk/gtk3-tweaks.css) */"
      cat "$TOKENS/$m/gtk-colors.css" "$APPS/gtk/gtk3-tweaks.css"; } > "$STATE_DIR/gtk/gtk3-$m.css"
    { echo "/* overworld gtk4 — $m (generated: gtk-colors.css + gtk4-vars.css + apps/gtk/gtk4-tweaks.css) */"
      cat "$TOKENS/$m/gtk-colors.css" "$TOKENS/$m/gtk4-vars.css" "$APPS/gtk/gtk4-tweaks.css"; } > "$STATE_DIR/gtk/gtk4-$m.css"
  done
}
install_gtk() {
  build_gtk_css
  hook_file "$CFG/gtk-3.0/gtk.css"              "$STATE_DIR/gtk/current-gtk3.css"
  hook_file "$CFG/gtk-4.0/gtk.css"              "$STATE_DIR/gtk/current-gtk4.css"
  hook_file "$CFG/xsettingsd/xsettingsd.conf"   "$STATE_DIR/gtk/current-xsettingsd.conf"
  # cursor theme (asset-forge's Xcursor + hyprcursor build); only built here if it is missing
  if [[ ! -d "$HOME/.local/share/icons/Overworld/cursors" ]]; then
    bash "$APPS/cursor/build.sh" --install >/dev/null 2>&1 \
      && state_add files "$HOME/.local/share/icons/Overworld" \
      || warn "cursor: could not build the Overworld cursor theme (apps/cursor/build.sh --install) — cursor theme left alone"
  fi
}

# ---------------------------------------------------------------- Qt: qt6ct + Kvantum
install_qt() {
  local m n
  mkdir -p "$CFG/qt6ct/colors" "$CFG/Kvantum"
  for m in light dark; do
    n="$(dn $m)"
    link "$TOKENS/$m/qt6ct-colors.conf" "$CFG/qt6ct/colors/overworld-$n.conf"; state_add files "$CFG/qt6ct/colors/overworld-$n.conf"
  done
  link "$CFG/qt6ct/colors/overworld-day.conf" "$STATE_DIR/qt6ct/current.conf"
  [[ -d "$APPS/kvantum/OverworldDay" && -d "$APPS/kvantum/OverworldNight" ]] || bash "$APPS/kvantum/build.sh"
  for n in Day Night; do link "$APPS/kvantum/Overworld$n" "$CFG/Kvantum/Overworld$n"; state_add files "$CFG/Kvantum/Overworld$n"; done
  # make sure the files apply-mode edits exist and are backed up
  [[ -f "$CFG/qt6ct/qt6ct.conf" ]] || { mkdir -p "$CFG/qt6ct"; printf '[Appearance]\n' > "$CFG/qt6ct/qt6ct.conf"; state_add created "$CFG/qt6ct/qt6ct.conf"; }
  [[ -f "$CFG/Kvantum/kvantum.kvconfig" ]] || { printf '[General]\n' > "$CFG/Kvantum/kvantum.kvconfig"; state_add created "$CFG/Kvantum/kvantum.kvconfig"; }
  backup_file "$CFG/qt6ct/qt6ct.conf"; backup_file "$CFG/Kvantum/kvantum.kvconfig"
}

# ---------------------------------------------------------------- superfile
install_superfile() {
  local m n
  mkdir -p "$CFG/superfile/theme"
  for m in light dark; do
    n="$(dn $m)"
    # the token theme with a syntax-highlight style that fits the mode (chroma styles)
    sed -E "s|^code_syntax_highlight = .*|code_syntax_highlight = \"$([[ $m == dark ]] && echo monokai || echo github)\"|" \
      "$TOKENS/$m/superfile-theme.toml" > "$STATE_DIR/superfile/overworld-$n.toml"
    link "$STATE_DIR/superfile/overworld-$n.toml" "$CFG/superfile/theme/overworld-$n.toml"; state_add files "$CFG/superfile/theme/overworld-$n.toml"
  done
  [[ -f "$CFG/superfile/config.toml" ]] || warn "superfile config.toml missing — run spf once, then re-run apps/install.sh"
  backup_file "$CFG/superfile/config.toml"
}

# ---------------------------------------------------------------- cava
install_cava() {
  local m
  for m in light dark; do
    { cat "$APPS/cava/config.base"; cat "$TOKENS/$m/cava.conf"; cat "$APPS/cava/config.tail"; } > "$STATE_DIR/cava/config-$m"
  done
  hook_file "$CFG/cava/config" "$STATE_DIR/cava/current" "$STATE_DIR/cava/config-light"
}

# ---------------------------------------------------------------- btop
install_btop() {
  local m n
  mkdir -p "$CFG/btop/themes"
  for m in light dark; do
    n="$(dn $m)"; link "$TOKENS/$m/btop.theme" "$CFG/btop/themes/overworld-$n.theme"; state_add files "$CFG/btop/themes/overworld-$n.theme"
  done
  [[ -f "$CFG/btop/btop.conf" ]] || { mkdir -p "$CFG/btop"; : > "$CFG/btop/btop.conf"; state_add created "$CFG/btop/btop.conf"; }
  backup_file "$CFG/btop/btop.conf"
}

# ---------------------------------------------------------------- starship
build_starship() {   # preset + both palettes -> one real file whose `palette =` line apply-mode flips
  { cat "$APPS/starship/overworld.toml"; echo; cat "$TOKENS/light/starship-palette.toml"; echo; cat "$TOKENS/dark/starship-palette.toml"; } \
    > "$STATE_DIR/starship/overworld.toml"
}
install_starship() {
  build_starship
  mkdir -p "$CFG/starship"
  link "$STATE_DIR/starship/overworld.toml" "$CFG/starship/overworld.toml"; state_add files "$CFG/starship/overworld.toml"
  # ~/.config/starship.toml is the active preset (the way JaKooLit's ChangeStarshipPrompt.sh selects one).
  # Off state = whatever it was before (Apothecary's link, a stock preset, or nothing).
  backup_file "$CFG/starship.toml"
  if [[ -e "$CFG/starship.toml.pre-$MARK" || -L "$CFG/starship.toml.pre-$MARK" ]]; then
    link "$CFG/starship.toml.pre-$MARK" "$STATE_DIR/starship/current.toml"
  else
    link "$STATE_DIR/empty" "$STATE_DIR/starship/current.toml"
  fi
  replace_with_symlink "$CFG/starship.toml" "$STATE_DIR/starship/current.toml"
}

# ---------------------------------------------------------------- spicetify
install_spicetify() {
  mkdir -p "$CFG/spicetify/Themes"
  link "$APPS/spicetify/Overworld" "$CFG/spicetify/Themes/Overworld"; state_add files "$CFG/spicetify/Themes/Overworld"
  have spicetify || warn "spicetify CLI not installed — theme files placed in ~/.config/spicetify/Themes/Overworld only"
  [[ -f "$CFG/spicetify/config-xpui.ini" ]] && backup_file "$CFG/spicetify/config-xpui.ini" || true
}

# ---------------------------------------------------------------- Zen browser (flatpak sandbox: real files, not symlinks)
install_zen() {
  local prof chrome
  prof="$(find "$CFG/zen" -maxdepth 1 -type d -name '*.Default (release)' 2>/dev/null | head -1)"
  [[ -n "$prof" ]] || prof="$(find "$CFG/zen" -maxdepth 1 -type d -name '*.Default*' 2>/dev/null | head -1)"
  [[ -n "$prof" ]] || { warn "zen profile not found under ~/.config/zen"; return 0; }
  chrome="$prof/chrome"; mkdir -p "$chrome"
  bash "$APPS/zen/build.sh"
  cp -f "$APPS/zen/overworld.css" "$chrome/overworld.css"; state_add files "$chrome/overworld.css"
  cp -f "$APPS/zen/overworld-content.css" "$chrome/overworld-content.css"; state_add files "$chrome/overworld-content.css"
  state_put '.keys["zen.profile"]' "$prof"
  # the @import lines themselves are added/removed by apply-mode (Zen reads userChrome at startup, and both themes
  # must not be imported at once), but make sure the pref that enables userChrome.css is there.
  append_marker "$prof/user.js" "user_pref(\"toolkit.legacyUserProfileCustomizations.stylesheets\", true); // $MARK"
}

# ---------------------------------------------------------------- nvim (never touches ~/.config/nvim)
install_nvim() {
  local site="$HOME/.local/share/nvim/site" m n
  mkdir -p "$site/colors" "$site/lua/overworld"
  for m in light dark; do
    n="$(dn $m)"
    link "$APPS/nvim/colors/overworld-$n.lua" "$site/colors/overworld-$n.lua";       state_add files "$site/colors/overworld-$n.lua"
    # tokens/build.py emits `end = "#…"`, a Lua keyword (REQUESTS -> design-director): quote that key until it is fixed there
    sed -E 's/^(\s*)end = /\1["end"] = /' "$TOKENS/$m/nvim-palette.lua" > "$STATE_DIR/nvim/palette_$n.lua"
    link "$STATE_DIR/nvim/palette_$n.lua" "$site/lua/overworld/palette_$n.lua";  state_add files "$site/lua/overworld/palette_$n.lua"
  done
  link "$APPS/nvim/lua/overworld/theme.lua" "$site/lua/overworld/theme.lua"; state_add files "$site/lua/overworld/theme.lua"
  link "$APPS/nvim/lua/overworld/init.lua"  "$site/lua/overworld/init.lua";  state_add files "$site/lua/overworld/init.lua"
}

# ---------------------------------------------------------------- wlogout (Game Menu)
build_wlogout() {
  local m n
  rm -rf "$STATE_DIR/wlogout/icons"; cp -r "$APPS/wlogout/icons" "$STATE_DIR/wlogout/icons"
  for m in light dark; do
    n="$(dn $m)"
    { echo "/* overworld wlogout — $n (generated: tokens wlogout-vars.css + apps/wlogout/style.css) */"
      cat "$TOKENS/$m/wlogout-vars.css"
      sed -e "s|@ICONS@|$STATE_DIR/wlogout/icons|g" -e "s|@MODE@|$n|g" "$APPS/wlogout/style.css"; } > "$STATE_DIR/wlogout/style-$m.css"
  done
}
install_wlogout() {
  build_wlogout
  link "$APPS/wlogout/layout" "$STATE_DIR/wlogout/overworld-layout"
  hook_file "$CFG/wlogout/style.css" "$STATE_DIR/wlogout/current.css"
  hook_file "$CFG/wlogout/layout"    "$STATE_DIR/wlogout/current-layout" "$APPS/wlogout/layout"
}

# ---------------------------------------------------------------- swappy
install_swappy() {
  local m
  for m in light dark; do
    sed "s|@RED@|$(palette $m error)|g" "$APPS/swappy/config.base" > "$STATE_DIR/swappy/config-$m"
  done
  hook_file "$CFG/swappy/config" "$STATE_DIR/swappy/current" "$STATE_DIR/swappy/config-light"
}

# ---------------------------------------------------------------- run
for app in kitty fastfetch rofi gtk qt superfile cava btop starship spicetify zen nvim wlogout swappy; do
  log "── $app"; "install_$app"
done
[[ -f "$STATE_DIR/apps-mode" ]] || echo off > "$STATE_DIR/apps-mode"
# re-link everything for the current mode (off on a first install = no visible change); no gsettings/keys touched
"$APPS/apply-mode.sh" "$(current_mode)" --link-only --no-handback
date -Iseconds > "$STATE_DIR/apps-mode.installed"
log "done. Nothing applied ($(current_mode)). Run: apps/apply-mode.sh light|dark|off  (or: overworld light|dark|off)"
