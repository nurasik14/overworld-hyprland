#!/usr/bin/env bash
# apps/uninstall.sh — reverse apps/install.sh exactly.
#   1. apply-mode.sh off  (restores gsettings + sed'd keys + points symlinks at backups)
#   2. every user file we replaced with a symlink gets its `.pre-overworld` backup moved back
#   3. marker lines are removed, files we created are deleted, theme files we installed are removed
#   4. ~/.config/overworld/<app>/ dirs and apps-state.json are removed
# Safe to run twice. Never touches ~/.config/nvim or the pre-theme backup repo.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

[[ -f "$APPS_STATE" ]] || { log "nothing installed (no $APPS_STATE)"; exit 0; }

"$APPS/apply-mode.sh" off || warn "apply-mode off reported errors; continuing"

# 2. restore replaced files
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  if [[ -e "$f.pre-$MARK" ]]; then
    rm -f "$f"; mv "$f.pre-$MARK" "$f"; log "restored: $f"
  fi
done < <(jq -r '.backups[]?' "$APPS_STATE")

# 3a. markers
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  remove_marker "$f"
  [[ -e "$f.pre-$MARK" ]] && rm -f "$f.pre-$MARK"   # marker removed → the backup is redundant
done < <(jq -r '.markers[]?' "$APPS_STATE")

# 3b. files we created from nothing (symlinks, marker-only files, empty configs)
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  if [[ -f "$f" && ! -L "$f" ]] && grep -qE -- "$MARK_RE" "$f" 2>/dev/null; then
    remove_marker "$f"; [[ -s "$f" ]] || rm -f "$f"
  else
    rm -rf "$f"
  fi
  log "removed: $f"
done < <(jq -r '.created[]?' "$APPS_STATE")

# 3c. theme files installed next to the user's (btop/superfile/qt6ct/kvantum/starship/spicetify/nvim/zen)
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  rm -rf "$f"
done < <(jq -r '.files[]?' "$APPS_STATE")
rmdir "$HOME/.local/share/nvim/site/lua/overworld" 2>/dev/null || true

# leftover backups of sed-edited files (keys already restored by apply-mode off)
for f in "$CFG/qt6ct/qt6ct.conf" "$CFG/Kvantum/kvantum.kvconfig" "$CFG/superfile/config.toml" "$CFG/btop/btop.conf" "$CFG/spicetify/config-xpui.ini"; do
  [[ -e "$f.pre-$MARK" ]] && rm -f "$f.pre-$MARK"
done

# 4. state
for d in kitty fastfetch rofi gtk qt6ct superfile cava btop starship wlogout swappy zen nvim; do rm -rf "$STATE_DIR/$d"; done
rm -f "$APPS_STATE" "$STATE_DIR/apps-mode" "$STATE_DIR/apps-mode.installed" "$STATE_DIR/empty"
log "uninstalled. (~/.config/overworld/repo and the hyprland files are owned by scripts/uninstall.sh)"
