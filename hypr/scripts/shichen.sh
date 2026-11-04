#!/usr/bin/env bash
# shichen.sh — the traditional two-hour period (時辰 / 时辰) for the current hour.
#   shichen.sh            -> glyph, e.g. 午
#   shichen.sh --label    -> "11–13 · hour of the Horse (noon)"
#   shichen.sh --date     -> Chinese calendar-style date numerals for today, e.g. 十月廿九 (Gregorian month/day)
#   shichen.sh --all      -> "午|11–13 · hour of the Horse (noon)|十月廿九"
# Used by hypr/hyprlock.conf (cmd[update:60000]) and the SDDM theme (via install-sddm.sh baking, see Main.qml).
set -eu
hour="${SHICHEN_HOUR:-$(date +%-H)}"

# 子 23–1 · 丑 1–3 · 寅 3–5 · 卯 5–7 · 辰 7–9 · 巳 9–11 · 午 11–13 · 未 13–15 · 申 15–17 · 酉 17–19 · 戌 19–21 · 亥 21–23
glyphs=(子 丑 寅 卯 辰 巳 午 未 申 酉 戌 亥)
names=("Rat (midnight)" "Ox" "Tiger" "Rabbit" "Dragon" "Snake" "Horse (noon)" "Goat" "Monkey" "Rooster" "Dog" "Pig")
spans=("23–1" "1–3" "3–5" "5–7" "7–9" "9–11" "11–13" "13–15" "15–17" "17–19" "19–21" "21–23")
idx=$(( ((hour + 1) % 24) / 2 ))

cn_num() {                      # 1..31 -> 一 … 十 十一 … 二十 廿一 … 三十 三十一 (廿 = twenty, as on old calendars)
    local n="$1" d=(零 一 二 三 四 五 六 七 八 九 十)
    if (( n <= 10 )); then printf '%s' "${d[$n]}"
    elif (( n < 20 )); then printf '十%s' "${d[$((n-10))]}"
    elif (( n == 20 )); then printf '二十'
    elif (( n < 30 )); then printf '廿%s' "${d[$((n-20))]}"
    elif (( n == 30 )); then printf '三十'
    else printf '三十%s' "${d[$((n-30))]}"; fi
}
cn_date() { printf '%s月%s' "$(cn_num "$(date +%-m)")" "$(cn_num "$(date +%-d)")"; }

case "${1:-}" in
    --label) printf '%s · hour of the %s\n' "${spans[$idx]}" "${names[$idx]}" ;;
    --date)  cn_date; echo ;;
    --all)   printf '%s|%s · hour of the %s|%s\n' "${glyphs[$idx]}" "${spans[$idx]}" "${names[$idx]}" "$(cn_date)" ;;
    *)       printf '%s\n' "${glyphs[$idx]}" ;;
esac
