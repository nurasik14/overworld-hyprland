#!/usr/bin/env bash
# Overworld Hyprland — uninstall: reverses scripts/install.sh exactly (no sudo).
# Turns the theme off first (the previous theme or the stock desktop comes back), removes the hyprland.conf hook line, the
# symlinks and (with --purge) the state dir. Only Overworld's changes: Apothecary's line, links and state stay as they are.
# SDDM: see docs/SUDO-STEPS.md for the revert one-liner.
set -euo pipefail
case "${1:-}" in -h|--help) sed -n "2,/^[^#]/{/^#/s/^# \{0,1\}//p}" "$0"; exit 0 ;; esac

REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd -P)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CFG/hypr"
STATE="$CFG/overworld"
BIN="$HOME/.local/bin"
MARK="# overworld"
PURGE=0; [[ "${1:-}" == "--purge" ]] && PURGE=1

say() { printf '  %s\n' "$*"; }
unlink_ours() {                            # remove a symlink only if it points into the repo; restore a backup if present
    local path="$1"
    if [[ -L "$path" ]]; then
        case "$(readlink -f "$path" 2>/dev/null || true)" in
            "$REPO"|"$REPO"/*) rm -f "$path"; say "removed $path" ;;
            *) say "kept $path (not ours)";;
        esac
    fi
    if [[ ! -e "$path" && -e "$path.pre-overworld" ]]; then
        mv "$path.pre-overworld" "$path"; say "restored $path from backup"
    fi
}

echo "Overworld Hyprland — uninstall (repo: $REPO)"

# 1. theme off (restores hyprlock.conf, waybar/swaync/hypridle, wallpaper) — only if it was on
if [[ -e "$STATE/enabled" && -x "$REPO/scripts/overworld" ]]; then
    "$REPO/scripts/overworld" off || true
fi

# 2. apps layer first (owned by app-theming), tolerate absence
[[ -x "$REPO/apps/uninstall.sh" ]] && { "$REPO/apps/uninstall.sh" || true; }

# 3. hyprland.conf hook line
if [[ -f "$HYPR/hyprland.conf" ]] && grep -qF "$MARK" "$HYPR/hyprland.conf"; then
    tmp="$(mktemp "${TMPDIR:-/tmp}/hyprland.conf.XXXXXX")"
    grep -vE "^source *= *~/\.config/hypr/overworld\.conf" "$HYPR/hyprland.conf" >"$tmp" || true
    cat "$tmp" >"$HYPR/hyprland.conf"; rm -f "$tmp"
    say "removed the '$MARK' line from $HYPR/hyprland.conf"
fi
unlink_ours "$HYPR/overworld.conf"
unlink_ours "$HYPR/hyprlock.conf"          # in case `off` was not reachable
[[ -e "$HYPR/hyprland.conf.pre-overworld" ]] && { rm -f "$HYPR/hyprland.conf.pre-overworld"; say "removed hyprland.conf.pre-overworld (hook line already stripped)"; }

# 4. symlinks
unlink_ours "$CFG/quickshell/overworld"
unlink_ours "$BIN/overworld"
unlink_ours "$BIN/hypr-projects"
# hypr-projects is shared with Apothecary (its off.conf binds it): hand the link over instead of leaving it dangling.  The list itself
# (~/.local/share/hypr-projects/projects.json) is the user's data and is never removed.
if [[ ! -e "$BIN/hypr-projects" ]]; then
    other="$(readlink -f "$BIN/apothecary" 2>/dev/null || true)"
    [[ -n "$other" && -x "$(dirname "$other")/hypr-projects" ]] && ln -sfn "$(dirname "$other")/hypr-projects" "$BIN/hypr-projects"
fi
# hypr-notes likewise; the notes (~/.local/share/hypr-notes/notes.json) are the user's data and are never removed.
unlink_ours "$BIN/hypr-notes"
if [[ ! -e "$BIN/hypr-notes" ]]; then
    other="$(readlink -f "$BIN/apothecary" 2>/dev/null || true)"
    [[ -n "$other" && -x "$(dirname "$other")/hypr-notes" ]] && ln -sfn "$(dirname "$other")/hypr-notes" "$BIN/hypr-notes"
fi

# 5. state dir
if (( PURGE )); then
    rm -rf "$STATE"; say "removed $STATE"
else
    rm -f "$STATE/enabled" "$STATE/active.conf" "$STATE/colors.conf" "$STATE/hyprlock-vars.conf" \
          "$STATE/kitty-colors.conf" "$STATE/lock.png" "$STATE/repo" "$STATE/previous-theme"
    say "kept $STATE (mode, wallpaper choices, config.json) — use --purge to delete it"
fi

rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/overworld/lock"

# 6. hypridle back to stock if it is running with our config
if pgrep -f -x "hypridle -c $REPO/hypr/hypridle.conf" >/dev/null 2>&1; then
    pkill -x hypridle || true; sleep 0.2; setsid -f hypridle >/dev/null 2>&1 </dev/null || true
    say "hypridle restarted with the stock config"
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    out="$(hyprctl reload 2>&1 || true)"; say "hyprctl reload: ${out:-ok}"
fi
echo "Uninstalled. SDDM (if installed): sudo scripts/install-sddm.sh revert  (see docs/SUDO-STEPS.md)"
