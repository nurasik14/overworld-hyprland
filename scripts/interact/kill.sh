#!/usr/bin/env bash
# kill.sh [address]   — the window-close bind (SUPER+Q; `overworld kill` runs this).
#   no argument   mine the focused window (block-break animation, then close)
#   <address>     mine that window ("0x55…" as printed by `hyprctl clients`)
# The shell does the animation and the close. If the shell is not running (or does not answer within 1.5 s) the window is closed the
# plain way, so SUPER+Q never stops working: `hyprctl dispatch killactive` / `closewindow address:<a>`.
set -u
addr="${1:-}"
if [[ -n "$addr" ]]; then
    timeout 1.5 qs -c overworld ipc call interact killAddress "$addr" >/dev/null 2>&1 && exit 0
    exec hyprctl dispatch closewindow "address:$addr" >/dev/null
fi
timeout 1.5 qs -c overworld ipc call interact kill >/dev/null 2>&1 && exit 0
exec hyprctl dispatch killactive >/dev/null
