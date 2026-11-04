#!/usr/bin/env bash
# check-config.sh — validates hypr/ without touching the live session.
#   1. Hyprland --verify-config on the user's real hyprland.conf + on.conf, in both modes (parses only, starts nothing)
#   2. hypridle.conf and hyprlock.conf: every $ow_ variable exists in both modes; every cmd[] runs and prints something
#   3. keybinds: every Overworld key is either free in JaKooLit's files or unbound first; no key is bound twice by us
set -u
REPO="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd -P)"
T="$(mktemp -d /tmp/ow-check.XXXXXX)"; trap 'rm -rf "$T"' EXIT
fail=0
say() { printf '%s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=1; }

for m in light dark; do
    sed -e "s|~/.config/overworld/colors.conf|$REPO/tokens/out/$m/hyprland-colors.conf|" \
        -e "s|~/.config/overworld/repo|$REPO|" "$REPO/hypr/on.conf" >"$T/on-$m.conf"
    printf 'source = %s/.config/hypr/hyprland.conf\nsource = %s\n' "$HOME" "$T/on-$m.conf" >"$T/full-$m.conf"
    out="$(timeout 20 Hyprland --verify-config -c "$T/full-$m.conf" 2>&1)"
    if grep -q 'config ok' <<<"$out"; then say "PASS  verify-config ($m)"; else bad "verify-config ($m)"; tail -20 <<<"$out"; fi
done

for m in light dark; do
    for v in $(grep -oE '\$ow_[A-Za-z0-9_]+' "$REPO/hypr/hyprlock.conf" | sort -u); do
        grep -q "^\\$v = " "$REPO/tokens/out/$m/hyprlock-vars.conf" || bad "hyprlock: $v missing in $m"
    done
done
say "PASS  hyprlock variables checked"
scripts="$REPO/hypr/scripts"
while IFS= read -r line; do
    c="${line#*cmd\[*\] }"; c="${c//\$scripts/$scripts}"
    o="$(timeout 5 sh -c "$c" 2>&1)" || bad "hyprlock cmd failed: $c"
    [[ -n "$o" ]] && say "PASS  cmd: ${c:0:70} -> ${o:0:50}" || bad "hyprlock cmd empty: $c"
done < <(grep -E '^\s*text = cmd\[' "$REPO/hypr/hyprlock.conf" | sort -u)
for k in $(grep -oE '^\s*[a-z_]+( =|:)' "$REPO/hypr/hyprlock.conf" | tr -d ' =:' | sort -u); do
    case "$k" in monitor|source|bezier|animation|path|text|color|size|position|enabled|pam) continue ;; esac
    strings /usr/bin/hyprlock | grep -q "$k" || bad "hyprlock option not in the binary: $k"
done
say "PASS  hyprlock option names found in the binary"

python3 - "$REPO/hypr/keybinds.conf" "$HOME/.config/hypr/configs/Keybinds.conf" "$HOME/.config/hypr/UserConfigs/UserKeybinds.conf" <<'PY'
import re, sys
ours, jak, user = sys.argv[1:4]
def norm(mods, key):
    mods = mods.replace('$mainMod', 'SUPER').replace('_', ' ').upper().split()
    return (' '.join(sorted(set(mods))), key.strip().lower())
def binds(path):
    out = {}
    for line in open(path, encoding='utf-8'):
        line = line.split('#', 1)[0].strip() if not line.lstrip().startswith('bind') else line.strip()
        m = re.match(r'^(bind[a-z]*)\s*=\s*([^,]*),\s*([^,]+),(.*)$', line)
        if m: out.setdefault(norm(m.group(2), m.group(3)), []).append(m.group(1) + ': ' + m.group(4).split('#')[0].strip()[:60])
    return out
def unbinds(path):
    out = set()
    for line in open(path, encoding='utf-8'):
        m = re.match(r'^\s*unbind\s*=\s*([^,]*),\s*([^#\s]+)', line)
        if m: out.add(norm(m.group(1), m.group(2)))
    return out
o, j, u, ub, uub = binds(ours), binds(jak), binds(user), unbinds(ours), unbinds(user)
live = dict(j)
for k in uub: live.pop(k, None)     # the user's file unbinds some of JaKooLit's before binding its own
live.update(u)
bad = 0
for k, v in sorted(o.items()):
    if k in live and k not in ub and k[1] not in ('xf86audioraisevolume', 'xf86audiolowervolume', 'xf86audiomute', 'xf86monbrightnessup', 'xf86monbrightnessdown'):
        print(f'FAIL  {k} is taken by {live[k]} and not unbound'); bad += 1
    if len(v) > 1:
        print(f'FAIL  {k} bound {len(v)} times by us: {v}'); bad += 1
free = [k for k in o if k not in live]
print(f'{"PASS" if not bad else "FAIL"}  keybinds: {len(o)} keys, {len(free)} were free, {len(o)-len(free)} replaced JaKooLit binds')
print('      new free keys:', ', '.join(f'{k[0]}+{k[1]}' for k in sorted(free)))
sys.exit(1 if bad else 0)
PY
[[ $? == 0 ]] || fail=1
(( fail == 0 )) && say "ALL OK" || say "SOME CHECKS FAILED"
exit $fail
