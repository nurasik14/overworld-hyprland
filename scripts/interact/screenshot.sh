#!/usr/bin/env bash
# screenshot.sh [area|window|screen|swappy]   — Overworld's Print key (JaKooLit's ScreenShot.sh, same save place and names).
#
#   area     slurp a region, save + copy to the clipboard              (Print)
#   window   the active window, save + copy                            (ALT+Print)
#   screen   everything, save + copy                                   (SHIFT+Print)
#   swappy   slurp a region, copy only, open it in swappy to annotate  (SUPER+SHIFT+S)
#
# Files: $(xdg-user-dir PICTURES)/Screenshots/Screenshot_<dd-Mon_HH-MM-SS>_<rand>.png, like JaKooLit's script.
# Afterwards: sound `item.pickup`, then the event `screenshot {path}` — the shell prints the chat line
# "Saved screenshot as <file>" and plays the item-pickup pop; if the shell is not running a plain notification is sent.
#
# Test/dev overrides:  OW_SHOT_DIR=<dir>   save there instead        OW_SHOT_DRYRUN=1   print the grim/slurp lines, run nothing
#                      OW_SOUND_DRYRUN=1   (read by ow-sound)         OW_EVENTS_DIR=<dir> private event bus for `overworld event`
set -u
here="$(dirname "$(realpath "$0")")"; repo="$(realpath "$here/../..")"
mode="${1:-area}"
[[ -n "${WAYLAND_DISPLAY:-}" ]] || source "$repo/scripts/dev-env.sh" >/dev/null 2>&1 || true

pictures="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
dir="${OW_SHOT_DIR:-$pictures/Screenshots}"
file="Screenshot_$(date '+%d-%b_%H-%M-%S')_${RANDOM}.png"
path="$dir/$file"
dry="${OW_SHOT_DRYRUN:-0}"

run() { if [[ "$dry" == 1 ]]; then echo "DRYRUN: $*"; else "$@"; fi; }
fail() { notify-send -u low "Screenshot" "$1" 2>/dev/null; echo "screenshot: $1" >&2; exit 1; }
mkdir -p "$dir" || fail "cannot create $dir"

shoot() {            # shoot [grim args...]  → $path, and the clipboard unless OW_SHOT_NOCOPY=1
    if [[ "$dry" == 1 ]]; then echo "DRYRUN: grim $* $path"; return 0; fi
    grim "$@" "$path" || return 1
    [[ "${OW_SHOT_NOCOPY:-0}" == 1 ]] || { command -v wl-copy >/dev/null && wl-copy <"$path" & }
    return 0
}

case "$mode" in
    screen|full|now)
        shoot || fail "Screenshot NOT saved" ;;
    window|win|active)
        geo="$(hyprctl -j activewindow 2>/dev/null | jq -r 'select(.address) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        [[ -z "$geo" && "$dry" == 1 ]] && geo="<active window>"
        [[ -n "$geo" ]] || fail "no active window"
        shoot -g "$geo" || fail "Screenshot NOT saved" ;;
    area|region)
        if [[ "$dry" == 1 ]]; then echo "DRYRUN: grim -g \"\$(slurp)\" $path"
        else
            sel="$(slurp)" || exit 0                      # Escape in slurp = cancelled, say nothing
            [[ -n "$sel" ]] && shoot -g "$sel" || fail "Screenshot NOT saved"
        fi ;;
    swappy|swapp|swap|edit)
        if [[ "$dry" == 1 ]]; then echo "DRYRUN: grim -g \"\$(slurp)\" - | swappy -f -"; path="$dir/swappy-dryrun.png"
        else
            sel="$(slurp)" || exit 0
            tmp="$(mktemp --suffix=.png)"
            grim -g "$sel" "$tmp" && [[ -s "$tmp" ]] || { rm -f "$tmp"; fail "Screenshot NOT saved"; }
            command -v wl-copy >/dev/null && wl-copy <"$tmp"
            mv "$tmp" "$path"
            swappy -f "$path" -o "$path" >/dev/null 2>&1 &    # swappy writes the edited image back over the file
        fi ;;
    *) echo "usage: screenshot.sh [area|window|screen|swappy]" >&2; exit 2 ;;
esac

[[ "$dry" == 1 ]] && exit 0                 # a dry run neither plays the pop nor posts the chat line
[[ -s "$path" ]] || fail "Screenshot NOT saved"

"$repo/scripts/ow-sound" item.pickup >/dev/null 2>&1 &
data="$(jq -cn --arg p "$path" '{path: $p}')"
if [[ -n "${OW_EVENTS_DIR:-}" ]]; then   # the CLI writes to $XDG_RUNTIME_DIR/overworld; a private bus is the same thing one level up
    XDG_RUNTIME_DIR="$(dirname "$OW_EVENTS_DIR")" "$repo/scripts/overworld" event screenshot "$data" 2>/dev/null || true
else
    "$repo/scripts/overworld" event screenshot "$data" 2>/dev/null || true
fi
# the chat line is the shell's job; without a running shell nobody would tell the user where the file went
if ! timeout 2 qs -c overworld ipc call interact status >/dev/null 2>&1 && [[ -z "${OW_EVENTS_DIR:-}" ]]; then
    notify-send -u low -i "$path" "Screenshot" "Saved screenshot as $file" 2>/dev/null || true
fi
echo "$path"
wait
exit 0
