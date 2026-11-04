#!/usr/bin/env bash
# apps/lib.sh — shared helpers for apps/install.sh, apps/apply-mode.sh, apps/uninstall.sh
# Sourced, not executed. Every helper is idempotent and never overwrites an existing backup.
#
# Conventions (see docs/APPS.md):
#   REPO                 repo root (resolved from this file's location)
#   STATE_DIR            ~/.config/overworld            (runtime contract, BRIEF §4)
#   APPS_STATE           ~/.config/overworld/apps-state.json
#   <file>.pre-overworld   backup of a user file we replaced with a symlink (never overwritten)
#   markers              "# overworld" / "/* overworld */" / "// overworld" on lines we append
#   ~/.config/overworld/<app>/current*   symlinks flipped by apply-mode.sh

set -euo pipefail

OW_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$OW_LIB_DIR/.." && pwd)"
APPS="$REPO/apps"
TOKENS="$REPO/tokens/out"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CFG/overworld"
APPS_STATE="$STATE_DIR/apps-state.json"
MARK="overworld"
# a line is ours only if it carries one of these exact marker forms
MARK_RE='(/\* overworld \*/|# overworld$|// overworld$|~/\.config/overworld/)' 

log()  { printf '\033[1;32m[apps]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[apps] warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[apps] error:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- state (json via jq)
state_init() {
  mkdir -p "$STATE_DIR"
  if [[ ! -f "$APPS_STATE" ]]; then
    jq -n --arg repo "$REPO" --arg at "$(date -Iseconds)" \
      '{repo:$repo, installed_at:$at, gsettings:{}, keys:{}, backups:[], markers:[], created:[], files:[]}' \
      > "$APPS_STATE"
  fi
}
state_get()  { jq -r "$1 // empty" "$APPS_STATE" 2>/dev/null || true; }
# state_set <jq-path> <string>   (only sets when the key is absent — keeps the PRE-theme value)
state_set_once() {
  local path="$1" val="$2"
  if [[ -z "$(state_get "$path")" ]]; then
    local tmp; tmp="$(mktemp)"
    jq --arg v "$val" "$path = \$v" "$APPS_STATE" > "$tmp" && mv "$tmp" "$APPS_STATE"
  fi
}
state_add() {   # state_add <array-name> <string>  (set semantics)
  local arr="$1" val="$2" tmp; tmp="$(mktemp)"
  jq --arg v "$val" ".$arr = ((.$arr // []) + [\$v] | unique)" "$APPS_STATE" > "$tmp" && mv "$tmp" "$APPS_STATE"
}

# ---------------------------------------------------------------- files
# backup_file <file>: copy to <file>.pre-overworld unless a backup already exists.
backup_file() {
  local f="$1"
  [[ -e "$f" || -L "$f" ]] || return 0
  if [[ -L "$f" ]]; then local t; t="$(readlink "$f")"; [[ "$t" == "$STATE_DIR"/* || "$t" == "$REPO"/* ]] && return 0; fi   # already ours
  if [[ ! -e "$f.pre-$MARK" ]]; then
    cp -a "$f" "$f.pre-$MARK"
    log "backup: $f -> $f.pre-$MARK"
  fi
}

# link <target> <linkpath>: ln -sfn, creating the parent dir.
link() { mkdir -p "$(dirname "$2")"; ln -sfn "$1" "$2"; }

# replace_with_symlink <userfile> <target>: back the user's file up, then make it a symlink to <target>.
replace_with_symlink() {
  local f="$1" target="$2"
  mkdir -p "$(dirname "$f")"
  if [[ -L "$f" && "$(readlink "$f")" == "$target" ]]; then return 0; fi
  backup_file "$f"
  if [[ -e "$f" || -L "$f" ]]; then
    [[ -e "$f.pre-$MARK" ]] && state_add backups "$f" || state_add created "$f"
    rm -f "$f"
  else
    state_add created "$f"
  fi
  ln -s "$target" "$f"
  log "link: $f -> $target"
}

# append_marker <file> <line>: append <line> (which must contain the marker) once; create file if absent.
append_marker() {
  local f="$1" line="$2"
  mkdir -p "$(dirname "$f")"
  if [[ ! -e "$f" ]]; then touch "$f"; state_add created "$f"; fi
  if ! grep -qE -- "$MARK_RE" "$f" 2>/dev/null; then
    backup_file "$f"
    [[ -e "$f.pre-$MARK" ]] && state_add markers "$f"
    # make sure we start on a fresh line
    [[ -s "$f" && -n "$(tail -c1 "$f")" ]] && printf '\n' >> "$f"
    printf '%s\n' "$line" >> "$f"
    log "marker: $f += $line"
  fi
}
remove_marker() {   # delete every line carrying the marker
  local f="$1"
  [[ -f "$f" && ! -L "$f" ]] || return 0
  grep -qE -- "$MARK_RE" "$f" && sed -i -E "\@$MARK_RE@d" "$f" && log "unmark: $f" || true
}

# set_kv <file> <key> <value> <style>  style: ini (key=value) | toml (key = "value") | toml-raw (key = value)
# Records the pre-theme value under .keys["<file>|<key>"] the first time.
set_kv() {
  local f="$1" key="$2" val="$3" style="${4:-ini}" cur
  [[ -f "$f" ]] || { warn "set_kv: $f missing"; return 0; }
  if grep -qE "^${key}\s*=" "$f"; then
    case "$style" in
      ini)      cur="$(grep -E "^${key}=" "$f" | head -1 | cut -d= -f2-)" ;;
      toml)     cur="$(grep -E "^${key}\s*=" "$f" | head -1 | sed -E 's/^[^=]*=\s*"?([^"]*)"?.*$/\1/')" ;;
      toml-raw) cur="$(grep -E "^${key}\s*=" "$f" | head -1 | sed -E 's/^[^=]*=\s*//')" ;;
    esac
    [[ -n "$cur" ]] || cur="__empty__"      # key present with an empty value (e.g. superfile `editor = ""`)
  else
    cur="__absent__"
  fi
  state_set_once ".keys[\"$f|$key\"]" "$cur"
  backup_file "$f"
  local esc; esc="$(printf '%s' "$val" | sed -e 's/[\/&|]/\\&/g')"
  case "$style" in
    ini)
      if grep -qE "^${key}=" "$f"; then sed -i -E "s|^${key}=.*|${key}=${esc}|" "$f"
      else printf '%s=%s\n' "$key" "$val" >> "$f"; fi ;;
    toml)
      if grep -qE "^${key}\s*=" "$f"; then sed -i -E "s|^${key}\s*=.*|${key} = \"${esc}\"|" "$f"
      else printf '%s = "%s"\n' "$key" "$val" >> "$f"; fi ;;
    toml-raw)
      if grep -qE "^${key}\s*=" "$f"; then sed -i -E "s|^${key}\s*=.*|${key} = ${esc}|" "$f"
      else printf '%s = %s\n' "$key" "$val" >> "$f"; fi ;;
  esac
}
# restore_kv <file> <key> <style>: put the recorded pre-theme value back (or drop the key if it was absent).
restore_kv() {
  local f="$1" key="$2" style="${3:-ini}" orig
  [[ -f "$f" ]] || return 0
  orig="$(state_get ".keys[\"$f|$key\"]")"
  [[ -n "$orig" ]] || return 0
  if [[ "$orig" == "__absent__" ]]; then
    sed -i -E "/^${key}\s*=/d" "$f"
  else
    [[ "$orig" == "__empty__" ]] && orig=""
    local esc; esc="$(printf '%s' "$orig" | sed -e 's/[\/&|]/\\&/g')"
    case "$style" in
      ini)      sed -i -E "s|^${key}=.*|${key}=${esc}|" "$f" ;;
      toml)     sed -i -E "s|^${key}\s*=.*|${key} = \"${esc}\"|" "$f" ;;
      toml-raw) sed -i -E "s|^${key}\s*=.*|${key} = ${esc}|" "$f" ;;
    esac
  fi
}

# ---------------------------------------------------------------- gsettings
GS_SCHEMA="org.gnome.desktop.interface"
GS_KEYS=(gtk-theme icon-theme cursor-theme font-name color-scheme)
record_gsettings() {
  have gsettings || return 0
  local k
  for k in "${GS_KEYS[@]}"; do
    state_set_once ".gsettings[\"$k\"]" "$(gsettings get "$GS_SCHEMA" "$k" 2>/dev/null || true)"
  done
}
gset() { have gsettings && gsettings set "$GS_SCHEMA" "$1" "$2" 2>/dev/null || true; }

# ---------------------------------------------------------------- mode helpers
current_mode() {   # light|dark|off  — what apply-mode last applied for apps
  local m; m="$(cat "$STATE_DIR/apps-mode" 2>/dev/null || echo off)"
  case "$m" in light|dark) echo "$m" ;; *) echo off ;; esac
}
dn() { [[ "$1" == dark ]] && echo night || echo day; }   # internal mode -> user-facing name (Day/Night)

# ---------------------------------------------------------------- coexistence with Apothecary
APO_STATE="$CFG/apothecary"
apo_repo() {   # the Apothecary checkout (read-only reference), via its own state dir symlink
  local r; r="$(readlink -f "$APO_STATE/repo" 2>/dev/null || true)"
  [[ -x "$r/apps/apply-mode.sh" ]] || r="$HOME/Projects/apothecary-hyprland"
  [[ -x "$r/apps/apply-mode.sh" ]] && echo "$r" || true
}
# apo_apps_wait: Apothecary's `apothecary off` runs its apps/apply-mode.sh detached; if we activate while it is
# still restoring user files/keys it would overwrite what we set. Wait (max 25 s) until it has finished.
apo_apps_wait() {
  local r i; r="$(apo_repo)"; [[ -n "$r" ]] || return 0
  for i in $(seq 1 50); do pgrep -f "$r/apps/apply-mode.sh" >/dev/null 2>&1 || return 0; sleep 0.5; done
  warn "Apothecary's apps/apply-mode.sh still running after 25 s — continuing"
}
# detect_previous: print "<apothecary|stock> <light|dark>" — which theme Overworld is replacing.
#   1. $OW_PREVIOUS_THEME ("apothecary [mode]" / "stock")     2. ~/.config/overworld/previous-theme (hyprland-engineer's
#   `overworld on` writes it before turning Apothecary off; first word apothecary|stock, optional second word light|dark)
#   3. fallback: Apothecary still enabled / its apps still on
detect_previous() {
  local raw="${OW_PREVIOUS_THEME:-}" w1 w2 amode
  [[ -n "$raw" ]] || raw="$(head -n1 "$STATE_DIR/previous-theme" 2>/dev/null || true)"
  amode="$(cat "$APO_STATE/mode" 2>/dev/null || true)"
  case "$amode" in light|dark) ;; *) amode="$(cat "$APO_STATE/apps-mode" 2>/dev/null || true)"; case "$amode" in light|dark) ;; *) amode=dark ;; esac ;; esac
  w1="${raw%% *}"; w2=""; [[ "$raw" == *" "* ]] && w2="${raw#* }"
  case "$w1" in
    apothecary) case "$w2" in light|dark) amode="$w2" ;; esac; echo "apothecary $amode"; return ;;
    stock|none|"") [[ -n "$w1" ]] && { echo "stock $amode"; return; } ;;
  esac
  if [[ -e "$APO_STATE/enabled" ]] || [[ "$(cat "$APO_STATE/apps-mode" 2>/dev/null || echo off)" =~ ^(light|dark)$ ]]; then
    echo "apothecary $amode"
  else echo "stock $amode"; fi
}
# capture_pre: called on every off -> light|dark transition. The values apps hold NOW are, by definition, the ones
# `off` must restore, so forget the ones recorded earlier (install time, or a previous session) and re-record them.
capture_pre() {
  local tmp; tmp="$(mktemp)"
  jq '.gsettings = {} | .keys |= with_entries(select(.key | contains("|") | not))' "$APPS_STATE" > "$tmp" && mv "$tmp" "$APPS_STATE"
  record_gsettings
  local prev; prev="$(detect_previous)"
  state_put '.keys["previous.theme"]' "${prev%% *}"
  state_put '.keys["previous.apothecary_mode"]' "${prev##* }"
  log "previous theme: ${prev%% *} (${prev##* })"
}
state_put() {   # state_put <jq-path> <string>   (always overwrites)
  local tmp; tmp="$(mktemp)"
  jq --arg v "$2" "$1 = \$v" "$APPS_STATE" > "$tmp" && mv "$tmp" "$APPS_STATE"
}
palette() {   # palette <mode> <role>  → hex from tokens/out/<mode>/palette.json
  jq -r --arg r "$2" '.[$r]' "$TOKENS/$1/palette.json"
}
