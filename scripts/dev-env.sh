#!/usr/bin/env bash
# Source this in any shell that needs to talk to the running Hyprland session.
# (Shells spawned by the agent do not inherit Hyprland's environment.)
eval "$(systemctl --user show-environment | grep -E '^(WAYLAND_DISPLAY|HYPRLAND_INSTANCE_SIGNATURE|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|DISPLAY|DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)=' | sed 's/^/export /')"
export QT_QPA_PLATFORM=wayland
hyprctl version >/dev/null 2>&1 || echo "dev-env: hyprctl cannot reach Hyprland (is it running?)" >&2
