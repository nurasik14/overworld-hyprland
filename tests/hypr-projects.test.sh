#!/usr/bin/env bash
# Test suite for scripts/hypr-projects — every verb against a temp file, never the real list, never a window.
#   bash tests/hypr-projects.test.sh [path/to/hypr-projects]
set -uo pipefail
HP="${1:-$(cd "$(dirname "$0")/.." && pwd)/scripts/hypr-projects}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HYPR_PROJECTS_FILE="$T/data/projects.json"
export HYPR_PROJECTS_LEGACY="$T/legacy/projects.json"
export HOME="$T/home"; mkdir -p "$HOME"        # theme_on() looks at $HOME/.config/*/enabled
export XDG_RUNTIME_DIR="$T/run"; mkdir -p "$XDG_RUNTIME_DIR"
pass=0; fail=0
ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
eq()   { [[ "$2" == "$3" ]] && ok || bad "$1" "expected [$3] got [$2]"; }
has()  { [[ "$2" == *"$3"* ]] && ok || bad "$1" "[$2] does not contain [$3]"; }
rc()   { local want="$1" name="$2"; shift 2; "$@" >/dev/null 2>&1; local got=$?; [[ "$got" == "$want" ]] && ok || bad "$name" "exit $got, wanted $want"; }
hp()   { bash "$HP" "$@"; }
titles() { jq -r '.items | map(.title) | join("|")' "$HYPR_PROJECTS_FILE"; }
reset() { rm -rf "$T/data" "$T/legacy"; }

# ---- empty / missing
reset
has "list on a missing file is a hint, not an error" "$(hp list)" "no projects yet"
[[ ! -e "$HYPR_PROJECTS_FILE" ]] && ok || bad "list must not create the file"
eq "list --json on missing file" "$(hp list --json)" "[]"
eq "path" "$(hp path)" "$HYPR_PROJECTS_FILE"

# ---- add
hp add "Hyprland rice" >/dev/null; hp add "Write   report  " --note "due Friday" >/dev/null; hp add Done thing --built >/dev/null
eq "add: three items, whitespace collapsed" "$(titles)" "Hyprland rice|Write report|Done thing"
eq "add: note stored" "$(jq -r '.items[1].note' "$HYPR_PROJECTS_FILE")" "due Friday"
eq "add --built: status + built_at" "$(jq -r '.items[2] | .status + (.built_at | type)' "$HYPR_PROJECTS_FILE")" "builtstring"
eq "add: ids unique" "$(jq '[.items[].id] | unique | length' "$HYPR_PROJECTS_FILE")" "3"
rc 2 "add: empty title refused" hp add "   "
rc 2 "add: no title refused" hp add
eq "add: file still valid" "$(jq -e . "$HYPR_PROJECTS_FILE" >/dev/null && echo y)" "y"

# ---- list + numbering (in progress first in file order, then built newest first)
out="$(hp list)"
has "list: header in progress" "$out" "In progress (2)"
has "list: numbered 1" "$out" " 1. [ ] Hyprland rice"
has "list: note shown" "$out" " 2. [ ] Write report   (due Friday)"
has "list: built section" "$out" " 3. [x] Done thing"
eq "list --json: numbers" "$(hp list --json | jq -r 'map(.n | tostring) | join(",")')" "1,2,3"
eq "list --json: order" "$(hp list --json | jq -r 'map(.title) | join("|")')" "Hyprland rice|Write report|Done thing"

# ---- done / undone / toggle by number, prefix, substring
hp done 1 >/dev/null
eq "done by number: now built" "$(jq -r '.items[0].status' "$HYPR_PROJECTS_FILE")" "built"
eq "numbering after done: Write report is 1" "$(hp list --json | jq -r '.[0].title')" "Write report"
hp undone "hyprland" >/dev/null
eq "undone by prefix (case-insensitive)" "$(jq -r '.items[0].status' "$HYPR_PROJECTS_FILE")" "progress"
eq "undone removes built_at" "$(jq -r '.items[0] | has("built_at")' "$HYPR_PROJECTS_FILE")" "false"
hp toggle "report" >/dev/null
eq "toggle by substring" "$(jq -r '.items[1].status' "$HYPR_PROJECTS_FILE")" "built"
hp toggle "write" >/dev/null
eq "toggle back" "$(jq -r '.items[1].status' "$HYPR_PROJECTS_FILE")" "progress"
rc 3 "done: nothing matches" hp done zzz
rc 3 "done: number out of range falls back to text, no match" hp done 99
hp add "Hyprland widgets" >/dev/null
rc 4 "done: ambiguous prefix" hp done hyprland
hp done "Hyprland rice" >/dev/null
eq "exact title beats the other prefix match" "$(jq -r '.items[0].status' "$HYPR_PROJECTS_FILE")" "built"
rc 2 "done: no argument" hp done
out="$(hp done hyprland 2>&1)"; has "ambiguous message tells what to do" "$out" "matches several"
eq "id works as a query" "$(hp undone "$(jq -r '.items[0].id' "$HYPR_PROJECTS_FILE")" | head -1)" "  back in progress: Hyprland rice"

# ---- rename
hp rename 1 "Hyprland rice v2" >/dev/null
eq "rename by number" "$(jq -r '.items[0].title' "$HYPR_PROJECTS_FILE")" "Hyprland rice v2"
hp rename "write" "Write the report" >/dev/null
eq "rename keeps the note" "$(jq -r '.items[1] | .title + "/" + .note' "$HYPR_PROJECTS_FILE")" "Write the report/due Friday"
rc 2 "rename: empty title refused" hp rename 1 "  "

# ---- rm
before="$(jq '.items | length' "$HYPR_PROJECTS_FILE")"
hp rm "Hyprland widgets" >/dev/null
eq "rm: one fewer" "$(jq '.items | length' "$HYPR_PROJECTS_FILE")" "$((before - 1))"
rc 3 "rm: already gone" hp rm "Hyprland widgets"
rc 3 "rm on an empty/missing match" hp rm nothing-like-this

# ---- clear
rc 1 "clear: refuses without a tty or --yes" hp clear
hp clear --yes >/dev/null
eq "clear --yes removes the built, keeps the rest" "$(jq -r '[.items[] | select(.status == "built")] | length' "$HYPR_PROJECTS_FILE")" "0"
eq "clear keeps in-progress" "$(jq '.items | length' "$HYPR_PROJECTS_FILE")" "2"
has "clear again: nothing to do" "$(hp clear --yes)" "no built projects"

# ---- raw ops (the QML services)
id="$(hp raw add "Raw one" "a note" progress)"
[[ -n "$id" ]] && ok || bad "raw add prints the id"
eq "raw list has the id" "$(hp raw list | awk -F'\t' -v id="$id" '$3 == id { print $4 }')" "Raw one"
eq "raw resolve" "$(hp raw resolve "Raw one")" "$id"
hp raw set "$id" built; eq "raw set built" "$(jq -r --arg id "$id" '.items[] | select(.id == $id) | .status' "$HYPR_PROJECTS_FILE")" "built"
hp raw edit "$id" "Raw two" ""; eq "raw edit (empty note deletes it)" "$(jq -r --arg id "$id" '.items[] | select(.id == $id) | .title + (has("note") | tostring)' "$HYPR_PROJECTS_FILE")" "Raw twofalse"
item="$(jq -c --arg id "$id" '.items[] | select(.id == $id)' "$HYPR_PROJECTS_FILE")"
hp raw remove "$id"; hp raw insert "$item" 0
eq "raw insert (undo) puts it back first" "$(jq -r '.items[0].id' "$HYPR_PROJECTS_FILE")" "$id"
hp raw insert "$item" 0; eq "raw insert twice is a no-op" "$(jq --arg id "$id" '[.items[] | select(.id == $id)] | length' "$HYPR_PROJECTS_FILE")" "1"
hp raw set "$id" progress
first="$(jq -r '.items[0].id' "$HYPR_PROJECTS_FILE")"; second="$(jq -r '.items[1].id' "$HYPR_PROJECTS_FILE")"
hp raw move "$first" 1; eq "raw move down swaps" "$(jq -r '.items[0].id' "$HYPR_PROJECTS_FILE")" "$second"
hp raw move "$first" -1; eq "raw move up swaps back" "$(jq -r '.items[0].id' "$HYPR_PROJECTS_FILE")" "$first"
hp raw move "$first" -1; eq "raw move past the top does nothing" "$(jq -r '.items[0].id' "$HYPR_PROJECTS_FILE")" "$first"
rc 2 "raw: unknown op" hp raw frobnicate
eq "-f overrides the file" "$(bash "$HP" -f "$T/other.json" path)" "$T/other.json"

# ---- concurrent writers: nothing lost, ids unique, file valid
reset
for i in $(seq 1 24); do ( hp add "concurrent $i" >/dev/null ) & done; wait
eq "24 parallel adds: all there" "$(jq '.items | length' "$HYPR_PROJECTS_FILE")" "24"
eq "24 parallel adds: unique ids" "$(jq '[.items[].id] | unique | length' "$HYPR_PROJECTS_FILE")" "24"
for i in 3 6 9 12; do ( hp done "concurrent $i" >/dev/null ) & done
for i in 15 18; do ( hp rm "concurrent $i" >/dev/null ) & done
( hp add "while toggling" >/dev/null ) & wait
eq "mixed parallel writes: count" "$(jq '.items | length' "$HYPR_PROJECTS_FILE")" "23"
eq "mixed parallel writes: 4 built" "$(jq '[.items[] | select(.status == "built")] | length' "$HYPR_PROJECTS_FILE")" "4"

# ---- invalid JSON is never overwritten
printf '{ this is not json' >"$HYPR_PROJECTS_FILE"
rc 1 "add refuses to overwrite invalid JSON" hp add "x"
eq "invalid file untouched" "$(cat "$HYPR_PROJECTS_FILE")" "{ this is not json"
rc 1 "list reports invalid JSON" hp list

# ---- odd content (found in review)
reset; hp raw add 'back\slash "q" title' "" progress >/dev/null
eq "backslashes survive list" "$(hp raw list | cut -f4)" 'back\slash "q" title'
has "backslashes survive the human list" "$(hp list)" 'back\slash "q" title'
reset; mkdir -p "$T/data"; printf '\n' >"$HYPR_PROJECTS_FILE"
id="$(hp raw add "into a blank file" "" progress)"; [[ -n "$id" && "$(titles)" == "into a blank file" ]] && ok || bad "a whitespace-only file is treated as empty, the add lands" "$(cat "$HYPR_PROJECTS_FILE")"
has "list of a whitespace-only file is the hint" "$(printf '\n' >"$HYPR_PROJECTS_FILE"; hp list)" "no projects yet"
reset; mkdir -p "$T/data"; printf '{"items":[{"id":"x"},{"id":"y","title":"Titled"}]}' >"$HYPR_PROJECTS_FILE"
eq "an item without a title is not listed (the shells drop it too)" "$(hp list --json | jq -r 'map(.title) | join("|")')" "Titled"
hp done 1 >/dev/null; eq "numbers match what is listed" "$(jq -r '.items[0].status' "$HYPR_PROJECTS_FILE")" "built"
reset; hp add "Keep my note" --note "original" >/dev/null
hp raw edit "$(jq -r '.items[0].id' "$HYPR_PROJECTS_FILE")" "Keep my note" "edited in the dialog" >/dev/null; hp rename 1 "Renamed" >/dev/null
eq "rename does not touch the note" "$(jq -r '.items[0] | .title + "/" + .note' "$HYPR_PROJECTS_FILE")" "Renamed/edited in the dialog"

# ---- in-place write (same inode: the shells watch it)
reset; hp add one >/dev/null; ino="$(stat -c %i "$HYPR_PROJECTS_FILE")"; hp add two >/dev/null; hp done one >/dev/null
eq "writes keep the inode" "$(stat -c %i "$HYPR_PROJECTS_FILE")" "$ino"

# ---- migration from the old Overworld-only list
reset; mkdir -p "$T/legacy"
printf '{"items":[{"id":"a1","title":"Old one","status":"built","created":"2026-11-06T03:02:00Z","built_at":"2026-11-06T03:02:00Z"}]}\n' >"$HYPR_PROJECTS_LEGACY"
cp "$HYPR_PROJECTS_LEGACY" "$T/legacy.orig"
has "migration: first list shows the old item" "$(hp list)" "Old one"
cmp -s "$HYPR_PROJECTS_FILE" "$T/legacy.orig" && ok || bad "migration: copied byte for byte"
[[ ! -e "$HYPR_PROJECTS_LEGACY" && -e "$HYPR_PROJECTS_LEGACY.bak" ]] && ok || bad "migration: old file kept as .bak"
hp add "after migration" >/dev/null; hp list >/dev/null
eq "migration happens once (new items survive)" "$(titles)" "Old one|after migration"
reset; mkdir -p "$T/legacy"; cp "$T/legacy.orig" "$HYPR_PROJECTS_LEGACY"
hp add "first write migrates too" >/dev/null
eq "migration on a write: old items kept" "$(titles)" "Old one|first write migrates too"
reset; mkdir -p "$T/legacy" "$T/data"; cp "$T/legacy.orig" "$HYPR_PROJECTS_LEGACY"; printf '{"items":[]}\n' >"$HYPR_PROJECTS_FILE"
hp list >/dev/null; eq "an existing shared file is never overwritten by the old one" "$(titles)" ""
reset; mkdir -p "$T/legacy"; printf 'garbage' >"$HYPR_PROJECTS_LEGACY"; hp list >/dev/null
[[ ! -e "$HYPR_PROJECTS_FILE" ]] && ok || bad "garbage legacy file is not migrated"

# ---- summary
reset; hp add "Alpha" >/dev/null; hp add "Beta" >/dev/null; hp add "Gamma" --built >/dev/null
out="$(hp summary --print)"
has "summary: head" "$out" "Projects · 2 in progress · 1 built"
has "summary: open items listed" "$out" "☐ Alpha"
[[ "$out" != *"Gamma"* ]] && ok || bad "summary lists only the open ones"

# ---- menu: logic only, with a scripted stand-in for rofi (no window is ever opened)
FAKE="$T/fake-rofi"; ANS="$T/answers"; LOG="$T/rofi.log"
cat >"$FAKE" <<'EOF'
#!/usr/bin/env bash
# answers file: one answer per call; ESC = Esc (exit 1); anything else is printed
a="$(head -1 "$HYPR_FAKE_ANSWERS")"; sed -i 1d "$HYPR_FAKE_ANSWERS"
{ echo "== $*"; [[ -t 0 ]] || cat; } >>"$HYPR_FAKE_LOG"
[[ "$a" == ESC || -z "$a" ]] && exit 1
printf '%s\n' "$a"
EOF
chmod +x "$FAKE"; export HYPR_PROJECTS_ROFI="$FAKE" HYPR_FAKE_ANSWERS="$ANS" HYPR_FAKE_LOG="$LOG"
reset; hp add "Alpha" >/dev/null; hp add "Beta" >/dev/null; hp add "Gamma" --built >/dev/null; : >"$LOG"
printf '%s\n' 1 ESC >"$ANS"; hp menu
eq "menu: Enter on row 1 toggles Alpha to built" "$(jq -r '.items[0].status' "$HYPR_PROJECTS_FILE")" "built"
has "menu: rows have checkboxes" "$(cat "$LOG")" "☐ Beta"
has "menu: built rows have ☑" "$(cat "$LOG")" "☑ Gamma"
has "menu: add row first" "$(head -3 "$LOG")" "+ Add project…"
has "menu: remove row last" "$(cat "$LOG")" "✕ Remove…"
has "menu: second pass keeps the cursor on the toggled row" "$(cat "$LOG")" "-selected-row 1"
printf '%s\n' 0 "  Delta   task " ESC >"$ANS"; hp menu
eq "menu: + Add project… adds the typed title (collapsed)" "$(titles)" "Alpha|Beta|Gamma|Delta task"
printf '%s\n' 0 ESC ESC >"$ANS"; n0="$(jq '.items | length' "$HYPR_PROJECTS_FILE")"; hp menu
eq "menu: Esc in the title prompt adds nothing" "$(jq '.items | length' "$HYPR_PROJECTS_FILE")" "$n0"
# rows now: 1 Beta, 2 Delta task (in progress), 3 Alpha, 4 Gamma (built newest first… Alpha is newer), 5 = ✕ Remove…
printf '%s\n' 5 0 ESC ESC >"$ANS"; hp menu          # remove submenu: pick row 0 = "Beta"
eq "menu: ✕ Remove… deletes the picked project" "$(titles)" "Alpha|Gamma|Delta task"
printf '%s\n' 0 "" ESC >"$ANS"; hp menu
eq "menu: empty title adds nothing" "$(titles)" "Alpha|Gamma|Delta task"
reset; hp add "Alpha" >/dev/null; hp add "Beta" >/dev/null; hp add "Gamma" --built >/dev/null; : >"$LOG"
printf '%s\n' 0 "Zed" ESC >"$ANS"; hp menu
has "menu: after an add the cursor lands on the new project (row 3)" "$(cat "$LOG")" "-selected-row 3"
reset; : >"$LOG"; printf '%s\n' ESC >"$ANS"; hp menu
has "menu on an empty list: only the add row" "$(cat "$LOG")" "+ Add project…"
[[ "$(cat "$LOG")" != *"✕ Remove…"* ]] && ok || bad "menu on an empty list has no Remove row"
[[ ! -e "$HYPR_PROJECTS_FILE" ]] && ok || bad "opening and closing the menu writes nothing"
# --if-stock: silent while a theme is on, runs on the stock desktop
mkdir -p "$HOME/.config/overworld"; touch "$HOME/.config/overworld/enabled"
: >"$LOG"; printf '%s\n' ESC >"$ANS"; hp menu --if-stock; eq "menu --if-stock: no-op while Overworld is on" "$(wc -c <"$LOG")" "0"
rm "$HOME/.config/overworld/enabled"; mkdir -p "$HOME/.config/apothecary"; touch "$HOME/.config/apothecary/enabled"
printf '%s\n' ESC >"$ANS"; hp menu --if-stock; eq "menu --if-stock: no-op while Apothecary is on" "$(wc -c <"$LOG")" "0"
rm "$HOME/.config/apothecary/enabled"
printf '%s\n' ESC >"$ANS"; hp menu --if-stock; [[ -s "$LOG" ]] && ok || bad "menu --if-stock: runs when both themes are off"
# a second menu while one is open exits quietly (same key bound in both off.conf files)
: >"$LOG"; printf '%s\n' ESC >"$ANS"
( exec 8>"$XDG_RUNTIME_DIR/hypr-projects-menu.lock"; flock -n 8 && hp menu )
eq "a second menu while one is open exits without touching rofi" "$(wc -c <"$LOG")" "0"
unset HYPR_PROJECTS_ROFI
# the real rofi is only asked for its options, never opened
if command -v rofi >/dev/null; then
    h="$(rofi -h 2>&1)"
    for o in -dmenu -format -selected-row -mesg -no-custom -p -i -l; do [[ "$h" == *"	$o "* ]] && ok || bad "rofi supports $o"; done
fi

# ---- help / unknown
has "help lists the verbs" "$(hp help)" "hypr-projects menu"
has "help raw" "$(hp help raw)" "clearbuilt"
rc 2 "unknown verb" hp frobnicate

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
