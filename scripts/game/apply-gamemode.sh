#!/usr/bin/env bash
# apply-gamemode.sh <new> [old] — the desktop side of a game mode switch (called by quickshell/Game/GameMode.qml).
#   survival   normal desktop                       creative   normal desktop (the HUD stops warning about hearts and hunger)
#   adventure  performance: animations, blur, shadows, gaps, rounding, opacity off + desktop widgets hidden
#   spectator  focus: gaps 0 + desktop widgets hidden (the HUD hides itself, DND is set by the shell)
# Leaving adventure/spectator restores the Hyprland config (`hyprctl reload`) and re-shows the widgets if they were visible.
# OW_GAME_DRYRUN=1 prints the commands instead of running them. OW_QS_ARGS picks the shell ("-c overworld", or "-p <dir>" in previews).
set -u
new="${1:?usage: apply-gamemode.sh <survival|creative|adventure|spectator> [old]}"; old="${2:-survival}"
rt="${XDG_RUNTIME_DIR:-/tmp}/overworld"; mkdir -p "$rt"
flag="$rt/gamemode-widgets"
read -ra QSARGS <<<"${OW_QS_ARGS:--c overworld}"
run() { if [[ "${OW_GAME_DRYRUN:-}" == 1 ]]; then echo "+ $*"; else "$@" >/dev/null 2>&1 || true; fi; }
qsipc() { run qs "${QSARGS[@]}" ipc call "$@"; }
widgets_status() { if [[ "${OW_GAME_DRYRUN:-}" == 1 ]]; then echo visible; else qs "${QSARGS[@]}" ipc call widgets status 2>/dev/null || echo visible; fi; }
special() { [[ "$1" == adventure || "$1" == spectator ]]; }

if special "$old" && [[ "$new" != "$old" ]]; then      # leaving a modified state: restore first
    run hyprctl reload
    if ! special "$new"; then
        [[ -r "$flag" && "$(head -n1 "$flag")" == hidden ]] || qsipc widgets reveal
        rm -f "$flag"
    fi
fi
if special "$new" && ! special "$old"; then            # entering: remember whether the widgets were visible
    printf '%s\n' "$(widgets_status)" >"$flag"
fi
case "$new" in
    adventure)
        run hyprctl --batch "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0; keyword decoration:active_opacity 1; keyword decoration:inactive_opacity 1; keyword decoration:dim_inactive 0"
        qsipc widgets hide ;;
    spectator)
        run hyprctl --batch "keyword general:gaps_in 0; keyword general:gaps_out 0"
        qsipc widgets hide ;;
esac
exit 0
