#!/usr/bin/env bash
# Overworld Hyprland — install (idempotent, no sudo, theme stays OFF).
# Links the theme into ~/.config and ~/.local/bin and creates the state dir. The ONLY edit to a JaKooLit
# file is one `source = … # overworld` line in ~/.config/hypr/hyprland.conf, right after Apothecary's line if that
# theme is installed (both stay installed; only one is ever on). It never touches Apothecary's files and never overwrites
# an existing ~/.config/overworld/config.json. Reversed exactly by scripts/uninstall.sh.
# Run `overworld on` afterwards to enable the theme.
set -euo pipefail
case "${1:-}" in -h|--help) sed -n "2,/^[^#]/{/^#/s/^# \{0,1\}//p}" "$0"; exit 0 ;; esac

REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd -P)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CFG/hypr"
STATE="$CFG/overworld"
BIN="$HOME/.local/bin"
MARK="# overworld"
HOOK="source = ~/.config/hypr/overworld.conf $MARK"

say() { printf '  %s\n' "$*"; }
link() {                                   # link <target> <linkpath>  (replaces an existing link, backs up a real file)
    local target="$1" path="$2"
    if [[ -e "$path" && ! -L "$path" ]]; then
        if [[ ! -e "$path.pre-overworld" ]]; then
            mv "$path" "$path.pre-overworld"; say "backed up $path -> $path.pre-overworld"
        else
            mv "$path" "$path.pre-overworld.$(date +%Y%m%d-%H%M%S)"; say "backed up $path (timestamped; existing backup kept)"
        fi
    fi
    mkdir -p "$(dirname "$path")"
    ln -sfn "$target" "$path"
    say "$path -> $target"
}

[[ -d "$HYPR" ]] || { echo "install: $HYPR not found — is Hyprland (JaKooLit dots) installed?" >&2; exit 1; }
[[ -f "$HYPR/hyprland.conf" ]] || { echo "install: $HYPR/hyprland.conf not found" >&2; exit 1; }

echo "Overworld Hyprland — install (repo: $REPO)"

# a) hyprland hook: symlink + one source line after Apothecary's, or at the end of hyprland.conf (idempotent, marked).
link "$REPO/hypr/overworld.conf" "$HYPR/overworld.conf"
if ! grep -qF "$MARK" "$HYPR/hyprland.conf"; then
    [[ -e "$HYPR/hyprland.conf.pre-overworld" ]] || cp -p "$HYPR/hyprland.conf" "$HYPR/hyprland.conf.pre-overworld"
    if grep -qE '^source *=.*apothecary\.conf' "$HYPR/hyprland.conf"; then
        # right after Apothecary's line. cat >, not sed -i: the file keeps its inode (and stays a symlink if it is one)
        tmp="$(mktemp "${TMPDIR:-/tmp}/hyprland.conf.XXXXXX")"
        awk -v hook="$HOOK" '{ print } !done && /^source *=.*apothecary\.conf/ { print hook; done = 1 }' "$HYPR/hyprland.conf" >"$tmp"
        cat "$tmp" >"$HYPR/hyprland.conf"; rm -f "$tmp"
        say "added after Apothecary's line in $HYPR/hyprland.conf: $HOOK"
    else
        # make sure the file ends with a newline before appending
        [[ -z "$(tail -c1 "$HYPR/hyprland.conf")" ]] || printf '\n' >>"$HYPR/hyprland.conf"
        printf '%s\n' "$HOOK" >>"$HYPR/hyprland.conf"
        say "appended to $HYPR/hyprland.conf: $HOOK"
    fi
else
    say "hyprland.conf already has the overworld hook"
fi

# b) quickshell config: ~/.config/quickshell/overworld -> repo/quickshell
link "$REPO/quickshell" "$CFG/quickshell/overworld"

# c) the CLI
mkdir -p "$BIN"
link "$REPO/scripts/overworld" "$BIN/overworld"
chmod +x "$REPO/scripts/overworld"
# the Projects list CLI (+ rofi menu on SUPER+SHIFT+P while no theme is on); the same script ships with Apothecary, the data is shared
link "$REPO/scripts/hypr-projects" "$BIN/hypr-projects"
chmod +x "$REPO/scripts/hypr-projects"
# the sticky-notes CLI (+ rofi menu on SUPER+ALT+N while no theme is on); same arrangement: one script per theme repo, the data is shared
link "$REPO/scripts/hypr-notes" "$BIN/hypr-notes"
chmod +x "$REPO/scripts/hypr-notes"
case ":$PATH:" in *":$BIN:"*) ;; *) say "note: $BIN is not in PATH for this shell (Hyprland uses the full path)";; esac

# d) state dir (defaults only if missing — never clobber the user's choices)
mkdir -p "$STATE"
[[ -s "$STATE/mode" ]] || printf 'light\n' >"$STATE/mode"
MODE="$(tr -d '[:space:]' <"$STATE/mode")"; [[ "$MODE" == "dark" ]] || MODE=light
[[ -e "$STATE/active.conf" ]] || ln -sfn "$REPO/hypr/off.conf" "$STATE/active.conf"
ln -sfn "$REPO/tokens/out/$MODE/hyprland-colors.conf" "$STATE/colors.conf"
ln -sfn "$REPO/tokens/out/$MODE/hyprlock-vars.conf"   "$STATE/hyprlock-vars.conf"
ln -sfn "$REPO/tokens/out/$MODE/kitty.conf"           "$STATE/kitty-colors.conf"
ln -sfn "$REPO"                                       "$STATE/repo"
lock="$REPO/assets/renders/lock-day.png"; [[ "$MODE" == dark ]] && lock="$REPO/assets/renders/lock-night.png"
if [[ -r "$lock" ]]; then
    ln -sfn "$lock" "$STATE/lock.png"
elif [[ ! -e "$STATE/lock.png" ]]; then
    first="$(find "$REPO/assets/wallpapers/$MODE" -maxdepth 1 -type f 2>/dev/null | LC_ALL=C sort | head -n1 || true)"
    [[ -n "$first" ]] && ln -sfn "$first" "$STATE/lock.png"
fi
"$REPO/hypr/scripts/lock-assets.sh" || say "lock screen pieces not built (no magick?): the button will be missing on the lock screen"
[[ -s "$STATE/config.json" ]] || printf '{"sounds": true, "weather": {}, "brew": {"work": 25, "break": 5}}\n' >"$STATE/config.json"
say "$STATE: mode=$MODE, active.conf -> $(readlink "$STATE/active.conf"), colors.conf/hyprlock-vars.conf/kitty-colors.conf/lock.png/repo linked, config.json"

# e) hyprlock is swapped only by `overworld on` (see scripts/overworld). Nothing to do here.
# f) hypridle: never replaced; `overworld on` restarts it with hypr/hypridle.conf.

# fonts: copy Mojangles next to Monocraft if it is not there yet (assets/fonts is gitignored, asset-forge builds it)
FONTS="$HOME/.local/share/fonts/overworld"
mkdir -p "$FONTS"
for f in "$REPO"/assets/fonts/*.ttf; do
    [[ -r "$f" && ! -e "$FONTS/$(basename "$f")" ]] && { cp "$f" "$FONTS/"; say "font installed: $(basename "$f")"; fc-cache -f "$FONTS" >/dev/null 2>&1 || true; }
done

# apps layer (owned by app-theming) — call if present, tolerate absence
if [[ -x "$REPO/apps/install.sh" ]]; then
    echo "running apps/install.sh …"; "$REPO/apps/install.sh" || echo "apps/install.sh failed (theme still installs)" >&2
else
    say "apps/install.sh not present yet — skipped"
fi

# reload Hyprland so the hook is live (the theme is OFF: off.conf is empty, nothing visible changes)
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    out="$(hyprctl reload 2>&1 || true)"; say "hyprctl reload: ${out:-ok}"
fi

cat <<EOF

Installed. The theme is OFF. Next:
  overworld on        # enable (Hyprland layer, Quickshell shell, hyprlock, hypridle)
  overworld status    # check
  overworld off       # back to what was there before (Apothecary in its mode, or stock JaKooLit)
SDDM login theme (needs sudo): see docs/SUDO-STEPS.md / scripts/install-sddm.sh
EOF
