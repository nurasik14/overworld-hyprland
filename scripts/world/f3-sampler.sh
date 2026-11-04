#!/usr/bin/env bash
# f3-sampler.sh — the live values of the F3 screen, one line each, until it is killed.
#   C <x>, <y>                  cursor position, 4 times a second   (hyprctl cursorpos, read only)
#   W {"x","y","w","h","cls","title","ws"}   the active window, once a second ({} = none)
#   B <percent>                 backlight, once a second
# Started by quickshell/World/F3Layer.qml while F3 is visible; it stops with it.
dev="$("$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../backlight-dev.sh" 2>/dev/null)"
bl="/sys/class/backlight/$dev"
i=0
while :; do
    printf 'C %s\n' "$(hyprctl cursorpos 2>/dev/null)"
    if (( i % 4 == 0 )); then
        printf 'W %s\n' "$(hyprctl -j activewindow 2>/dev/null | jq -c 'if .address then {x: .at[0], y: .at[1], w: .size[0], h: .size[1], cls: .class, title: .title, ws: .workspace.id} else {} end' 2>/dev/null || echo '{}')"
        if [[ -r "$bl/brightness" ]]; then
            read -r cur <"$bl/brightness"; read -r max <"$bl/max_brightness"
            (( max > 0 )) && printf 'B %s\n' $(( (cur * 100 + max / 2) / max ))
        fi
    fi
    i=$(( i + 1 ))
    sleep 0.25
done
