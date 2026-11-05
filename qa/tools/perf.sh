#!/usr/bin/env bash
# qa/tools/perf.sh <label> [seconds] : CPU % (one core = 100, like top) and RSS of `qs -c overworld`; children = its reaped helper processes.
pid="$(pgrep -f '^qs -c overworld$' | head -1)"; s="${2:-30}"; hz=$(getconf CLK_TCK)
read_t() { awk '{print $14+$15, $16+$17}' "/proc/$pid/stat"; }
read -r a0 c0 < <(read_t); sleep "$s"; read -r a1 c1 < <(read_t)
rss=$(awk '/VmRSS/{print int($2/1024)}' /proc/$pid/status)
awk -v l="$1" -v a=$((a1-a0)) -v c=$((c1-c0)) -v hz="$hz" -v s="$s" -v r="$rss" 'BEGIN{printf "%-28s self %.2f%%  children %.2f%%  RSS %d MB\n", l, 100*a/hz/s, 100*c/hz/s, r}'
