#!/usr/bin/env bash
# set-config.sh <config.json> <dotted.key> <json value> — set one key in a JSON config IN PLACE (never mv: the file is
# watched by several shell services and may be a symlink). Same flock as `overworld` (config.json.lock) so writers queue up.
#   set-config.sh ~/.config/overworld/config.json sound_volume.master 75
#   set-config.sh ~/.config/overworld/config.json particles '"decreased"'
set -euo pipefail
f="${1:?file}"; key="${2:?key}"; val="${3:?json value}"
command -v jq >/dev/null || { echo "set-config: jq is required" >&2; exit 1; }
printf '%s' "$val" | jq -e . >/dev/null 2>&1 || { echo "set-config: value is not JSON: $val" >&2; exit 1; }
mkdir -p "$(dirname "$f")"
(
    flock 9
    [[ -s "$f" ]] || printf '{}\n' >"$f"
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    if jq --arg k "$key" --argjson v "$val" 'setpath($k | split(".") | map(if test("^[0-9]+$") then tonumber else . end); $v)' "$f" >"$tmp"; then
        cat "$tmp" >"$f"
    else
        echo "set-config: $f is not valid JSON, left untouched" >&2; exit 1
    fi
) 9>>"$f.lock"
