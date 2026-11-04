#!/usr/bin/env bash
# Print the name of the backlight that drives a *connected* display.
# Hybrid-GPU laptops expose several (intel_backlight -> eDP-1 on the iGPU, nvidia_0 -> unused dGPU output);
# brightnessctl's default picks the first alphabetically, which can be the wrong one.
for d in /sys/class/backlight/*; do
    [ "$(cat "$d/device/status" 2>/dev/null)" = connected ] && { basename "$d"; exit 0; }
done
ls /sys/class/backlight | head -n1
