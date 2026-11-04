#!/usr/bin/env bash
# daycycle-apply.sh — the desktop side of a day/night transition (called detached by quickshell/World/DayCycle.qml).
#
#   daycycle-apply.sh --time dawn|day|dusk|night [--mode light|dark] [--dry-run] [--force]
#
#   --time   the sky phase: when the current wallpaper is a scene with time variants in
#            assets/wallpapers/index.json (same `scene`, wanted `time`), fade to that variant (awww, slow fade).
#            Scenes without that time (Nether, End, your own pictures) keep their picture.
#   --mode   then flip the theme with `scripts/overworld light|dark` (only when it differs from the current one).
#            The new mode's remembered wallpaper is set to the variant first, so the CLI's own wallpaper step
#            repaints the picture that is already on screen (no flash of an old picture).
#   --dry-run  print what would happen; touch nothing.   --force  also act while the theme is off.
# Does nothing while the theme is off (no ~/.config/overworld/enabled) unless --force. Log: ~/.cache/overworld/daycycle.log
set -uo pipefail
REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd -P)"
STATE="${XDG_CONFIG_HOME:-$HOME/.config}/overworld"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/overworld"
WP="$REPO/assets/wallpapers"
INDEX="$WP/index.json"
time_wanted=""; mode_wanted=""; dry=0; force=0
while (( $# )); do
    case "$1" in
        --time) time_wanted="${2:-}"; shift ;;
        --mode) mode_wanted="${2:-}"; shift ;;
        --dry-run) dry=1 ;;
        --force) force=1 ;;
        *) echo "daycycle-apply: unknown argument $1" >&2; exit 2 ;;
    esac
    shift
done
[[ -z "$time_wanted" || "$time_wanted" =~ ^(dawn|day|dusk|night)$ ]] || { echo "bad --time $time_wanted" >&2; exit 2; }
[[ -z "$mode_wanted" || "$mode_wanted" =~ ^(light|dark)$ ]] || { echo "bad --mode $mode_wanted" >&2; exit 2; }

mkdir -p "$CACHE"
log() {
    printf '%s %s\n' "$(date +%H:%M:%S)" "$*"
    (( dry )) && return 0
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$CACHE/daycycle.log"
    [[ "$(wc -l <"$CACHE/daycycle.log")" -gt 300 ]] && tail -n 150 "$CACHE/daycycle.log" >"$CACHE/daycycle.log.tmp" && mv "$CACHE/daycycle.log.tmp" "$CACHE/daycycle.log"
    return 0
}

if [[ ! -e "$STATE/enabled" && $force == 0 ]]; then log "theme is off: nothing to do"; exit 0; fi
if (( ! dry )); then   # one transition at a time
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/overworld-daycycle.lock"; flock -w 30 9 || { log "lock timeout"; exit 4; }
fi

cur_mode="light"; [[ -r "$STATE/mode" && "$(tr -d '[:space:]' <"$STATE/mode")" == "dark" ]] && cur_mode="dark"
final_mode="${mode_wanted:-$cur_mode}"

# ---- the picture on screen now: the mode's remembered wallpaper, else awww's
current=""
[[ -r "$STATE/wallpaper-$cur_mode" ]] && current="$(head -n1 "$STATE/wallpaper-$cur_mode")"
if [[ -z "$current" || ! -r "$current" ]] && command -v awww >/dev/null 2>&1; then
    current="$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n1)"
fi

target=""
if [[ -n "$time_wanted" && -n "$current" && -r "$INDEX" ]] && command -v jq >/dev/null 2>&1; then
    rel="${current#"$WP"/}"
    target_rel="$(jq -r --arg f "$rel" --arg abs "$current" --arg t "$time_wanted" '
        ([.[] | select(.file == $f or .file == $abs)][0]) as $cur
        | if $cur == null then empty
          else ([.[] | select(.scene == $cur.scene and .time == $t and .world == $cur.world)][0].file // empty) end' "$INDEX" 2>/dev/null)"
    if [[ -n "$target_rel" ]]; then
        [[ "$target_rel" = /* ]] && target="$target_rel" || target="$WP/$target_rel"
        [[ -r "$target" ]] || target=""
    fi
fi

dur=4
[[ -r "$STATE/config.json" ]] && command -v jq >/dev/null 2>&1 \
    && [[ "$(jq -r '(.reduced_motion // .animations == false) // false' "$STATE/config.json" 2>/dev/null)" == "true" ]] && dur=0.3

changed=0
if [[ -n "$target" && "$target" != "$current" ]]; then
    changed=1
    log "wallpaper ${current#"$WP"/} -> ${target#"$WP"/} ($time_wanted, fade ${dur}s)"
    if (( ! dry )) && command -v awww >/dev/null 2>&1; then
        pgrep -x awww-daemon >/dev/null 2>&1 || { setsid -f awww-daemon >/dev/null 2>&1 </dev/null; sleep 0.4; }
        awww img "$target" --transition-type fade --transition-duration "$dur" --transition-fps 60 >/dev/null 2>&1 || log "awww failed"
    fi
elif [[ -n "$time_wanted" ]]; then
    log "wallpaper unchanged for $time_wanted (${current:+${current#"$WP"/}})"
fi
# remember the variant for the mode that will be active (and keep lock.png on it when there is no lock art)
if [[ -n "$target" ]] && (( ! dry )); then
    printf '%s\n' "$target" >"$STATE/wallpaper-$final_mode"
    [[ -r "$REPO/assets/art/lock-$final_mode.png" ]] || ln -sfn "$target" "$STATE/lock.png"
fi

# ---- the theme mode, after the fade so the picture does not jump under a half-blended UI
if [[ -n "$mode_wanted" && "$mode_wanted" != "$cur_mode" ]]; then
    log "mode $cur_mode -> $mode_wanted"
    if (( ! dry )); then
        (( changed )) && sleep "$dur"
        "$REPO/scripts/overworld" "$mode_wanted" >>"$CACHE/daycycle.log" 2>&1 || log "overworld $mode_wanted failed"
    fi
elif [[ -n "$mode_wanted" ]]; then
    log "mode already $cur_mode"
fi
exit 0
