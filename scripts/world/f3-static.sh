#!/usr/bin/env bash
# f3-static.sh — the F3 screen's facts that never change while the shell runs. Prints ONE JSON object.
#   {"version","hyprland","kernel","cpu","cores","gpus":[…],"driver","monitor":{"name","w","h","hz"}}
# Run once, the first time F3 opens (quickshell/World/F3Layer.qml). Read-only; needs hyprctl, jq.
REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd -P)"
version="1.0"; [[ -r "$REPO/VERSION" ]] && version="$(head -n1 "$REPO/VERSION" | tr -d '[:space:]')"
hypr="$(hyprctl -j version 2>/dev/null | jq -r '.version // empty')"
kernel="$(cat /proc/sys/kernel/osrelease 2>/dev/null)"
cpu="$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -n1 | sed 's/  */ /g')"
cores="$(nproc 2>/dev/null || echo 1)"
gpus="[]"
if command -v lspci >/dev/null 2>&1; then
    gpus="$(lspci -mm 2>/dev/null | grep -iE '"(VGA compatible controller|3D controller|Display controller)"' \
        | sed -E 's/^[^"]*"[^"]*" "([^"]*)" "([^"]*)".*/\1|\2/' \
        | sed -E 's/ Corporation//; s/\(R\)//; s/^NVIDIA \|AD[0-9A-Z]+M? \[(.*)\]$/NVIDIA|\1/' \
        | sed -E 's/\|/ /' | jq -R . | jq -sc .)"
fi
driver=""
if command -v nvidia-smi >/dev/null 2>&1; then
    n="$(timeout 3 nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -n1)"
    if [[ -n "$n" ]]; then
        driver="${n##*, }"
        name="${n%%,*}"; gpus="$(jq -c --arg n "$name" 'map(if test("NVIDIA|GeForce") then $n else . end)' <<<"$gpus")"
    fi
fi
mon="$(hyprctl -j monitors 2>/dev/null | jq -c '.[0] | {name, w: .width, h: .height, hz: (.refreshRate | round)}' 2>/dev/null)"
[[ -n "$mon" && "$mon" != null ]] || mon='{"name":"","w":0,"h":0,"hz":60}'
jq -nc --arg v "$version" --arg h "$hypr" --arg k "$kernel" --arg c "$cpu" --argjson n "$cores" \
    --argjson g "$gpus" --arg d "$driver" --argjson m "$mon" \
    '{version:$v, hyprland:$h, kernel:$k, cpu:$c, cores:$n, gpus:$g, driver:$d, monitor:$m}'
