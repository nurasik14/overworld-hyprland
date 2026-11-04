#!/usr/bin/env bash
# greeter-shot.sh <out.png> [theme-dir]: open the SDDM theme in test mode fullscreen on the empty workspace 77, shoot it through
# scripts/dev-shot.sh, close it again. Nothing is left running. Log: /tmp/ow-greeter.log
set -u
REPO="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd -P)"
source "$REPO/scripts/dev-env.sh"
out="${1:?usage: greeter-shot.sh <out.png> [theme-dir]}"; theme="${2:-$REPO/sddm/overworld}"
hyprctl dispatch exec "[workspace 77 silent; fullscreen] bash -c 'exec sddm-greeter-qt6 --test-mode --theme $theme >/tmp/ow-greeter.log 2>&1'" >/dev/null
pid=""
for _ in $(seq 1 40); do
    pid="$(hyprctl clients -j | jq -r '[.[] | select(.class | test("^sddm-greeter"; "i"))][0].pid // empty')"
    [[ -n "$pid" ]] && break
    sleep 0.25
done
[[ -n "$pid" ]] || { echo "greeter window did not appear"; tail -20 /tmp/ow-greeter.log; exit 1; }
sleep 2.5
"$REPO/scripts/dev-shot.sh" "$out" full
rc=$?
kill "$pid"
echo "greeter pid $pid closed, shot rc=$rc"
grep -vE 'libpng|^$' /tmp/ow-greeter.log | tail -25
exit $rc
