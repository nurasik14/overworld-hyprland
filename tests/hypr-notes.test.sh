#!/usr/bin/env bash
# Test suite for scripts/hypr-notes — every verb against a temp file, never the real pad, never a window.
#   bash tests/hypr-notes.test.sh [path/to/hypr-notes]
set -uo pipefail
HN="${1:-$(cd "$(dirname "$0")/.." && pwd)/scripts/hypr-notes}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HYPR_NOTES_FILE="$T/data/notes.json"
export HOME="$T/home"; mkdir -p "$HOME"        # theme_on() looks at $HOME/.config/*/enabled
export XDG_RUNTIME_DIR="$T/run"; mkdir -p "$XDG_RUNTIME_DIR"
unset XDG_CONFIG_HOME XDG_DATA_HOME VISUAL EDITOR
pass=0; fail=0
ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
eq()   { [[ "$2" == "$3" ]] && ok || bad "$1" "expected [$3] got [$2]"; }
has()  { [[ "$2" == *"$3"* ]] && ok || bad "$1" "[$2] does not contain [$3]"; }
hasnt() { [[ "$2" != *"$3"* ]] && ok || bad "$1" "[$2] contains [$3]"; }
rc()   { local want="$1" name="$2"; shift 2; "$@" >/dev/null 2>&1; local got=$?; [[ "$got" == "$want" ]] && ok || bad "$name" "exit $got, wanted $want"; }
hn()   { bash "$HN" "$@"; }
texts() { jq -r '.sheets | map(.text) | join("|")' "$HYPR_NOTES_FILE"; }
cur()  { jq -r '. as $r | (.sheets | map(.id) | index($r.current)) // "none"' "$HYPR_NOTES_FILE"; }
reset() { rm -rf "$T/data"; }

# ---------------------------------------------------------------- empty pad
reset
has "list on no file gives a hint" "$(hn list)" "no notes yet"
[[ ! -e "$HYPR_NOTES_FILE" ]] && ok || bad "list does not create the file"
eq "--json on no file" "$(hn list --json)" "[]"
rc 3 "show with no sheets" hn show
rc 2 "rm without a number" hn rm
rc 3 "rm with no sheets" hn rm 1
rc 2 "add with no args" hn add
rc 2 "add with blank text" hn add "   "
eq "path honours the env" "$(hn path)" "$HYPR_NOTES_FILE"
[[ ! -e "$HYPR_NOTES_FILE" ]] && ok || bad "refused adds did not create the file"
has "help" "$(hn help)" "hypr-notes add"
has "help raw" "$(hn help raw)" "insert"
has "-h" "$(hn -h)" "hypr-notes menu"
rc 2 "unknown verb" hn frobnicate
rc 2 "unknown list option" hn list --what

# ---------------------------------------------------------------- add, numbering, current
has "add says pinned" "$(hn add first thought)" "pinned: first thought"
eq "args are joined with a space" "$(texts)" "first thought"
jq -e '.sheets[0] | (.id | length > 0) and (.created | test("^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\dZ$")) and .updated == .created' "$HYPR_NOTES_FILE" >/dev/null && ok || bad "sheet has id, ISO created, updated"
jq -e '.current == .sheets[0].id' "$HYPR_NOTES_FILE" >/dev/null && ok || bad "current points at the new sheet"
hn add "second" >/dev/null; hn add "third" >/dev/null
eq "file order = creation order" "$(texts)" "first thought|second|third"
eq "new sheet becomes current" "$(cur)" "2"
L="$(hn list)"
has "list numbers from 1" "$L" " 1  first thought"
has "list marks current" "$L" " 3* third"
has "list shows an age" "$L" "just now"
hasnt "list without a verb is the default" "$(hn | wc -l)" "4"
eq "numbers in --json" "$(hn list --json | jq -r 'map(.n) | join(",")')" "1,2,3"
eq "current in --json" "$(hn list --json | jq -r 'map(select(.current).text)[0]')" "third"
eq "show defaults to current" "$(hn show)" "third"
eq "show n" "$(hn show 2)" "second"
eq "show by id" "$(hn show "$(jq -r '.sheets[0].id' "$HYPR_NOTES_FILE")")" "first thought"
rc 3 "show out of range" hn show 9
rc 3 "show 0" hn show 0
rc 3 "show unknown id" hn show nosuch

# ---------------------------------------------------------------- stdin, multi-line, special characters, cap
echo "from stdin" | hn add - >/dev/null
eq "add - reads stdin" "$(hn show)" "from stdin"
printf 'line one\n  line two\n\nline four\n\n\n' | hn add - >/dev/null
eq "multi-line kept, trailing newlines dropped" "$(hn show)" "$(printf 'line one\n  line two\n\nline four')"
has "list shows the first line only" "$(hn list | tail -1)" "line one"
hasnt "list row has no second line" "$(hn list | tail -1)" "line two"
printf '\n\n  \nafter blanks\n' | hn add - >/dev/null
has "first non-blank line in list" "$(hn list | tail -1)" "after blanks"
rc 2 "add - with only blanks" bash -c "printf '  \n\n' | bash '$HN' add -"
hn add "- dash first" >/dev/null; eq "text starting with a dash" "$(hn show)" "- dash first"
hn add - - >/dev/null; eq "two dashes are text" "$(hn show)" "- -"
SP='a "quoted" \back $HOME `x` <b>&amp; ё қ ғ 🦊'
hn add "$SP" >/dev/null; eq "special characters survive" "$(hn show)" "$SP"
printf 'tab\there\n' | hn add - >/dev/null; has "tab in text shown in list" "$(hn list | tail -1)" "tab here"
reset
python3 -c 'print("x"*5000)' | hn add - >/dev/null
eq "cap at 4000 characters (stdin)" "$(jq -r '.sheets[0].text | length' "$HYPR_NOTES_FILE")" "4000"
hn add "$(python3 -c 'print("я"*5000)')" >/dev/null
eq "cap counts characters, not bytes" "$(jq -r '.sheets[1].text | length' "$HYPR_NOTES_FILE")" "4000"
python3 -c 'print("y"*200000)' 2>/dev/null | hn add - >/dev/null
eq "huge stdin is cut, not an error" "$(jq -r '.sheets[2].text | length' "$HYPR_NOTES_FILE")" "4000"
hn raw put longid "$(python3 -c 'print("z"*4100)')"
eq "raw put caps too" "$(jq -r '.sheets[3].text | length' "$HYPR_NOTES_FILE")" "4000"

# ---------------------------------------------------------------- rm + current
reset
for w in a b c d; do hn add "$w" >/dev/null; done
has "rm says what" "$(hn rm 2)" "torn off: b"
eq "rm removes that number" "$(texts)" "a|c|d"
eq "numbers close up" "$(hn show 2)" "c"
eq "rm of another keeps current" "$(hn show)" "d"
hn rm 3 >/dev/null
eq "rm of the last current → new last is current" "$(hn show)" "c"
A="$(jq -r '.sheets[0].id' "$HYPR_NOTES_FILE")"
hn raw current "$A"; eq "raw current flips" "$(hn show)" "a"
hn rm 1 >/dev/null; eq "rm of a current in the middle → next sheet" "$(hn show)" "c"
hn raw current nosuchid; eq "raw current to an unknown id changes nothing" "$(hn show)" "c"
rc 3 "rm out of range leaves the file" hn rm 5
eq "…still there" "$(texts)" "c"
hn rm 1 >/dev/null
eq "last sheet removed: no sheets" "$(jq -r '.sheets | length' "$HYPR_NOTES_FILE")" "0"
eq "…and no current" "$(jq -r '.current // "none"' "$HYPR_NOTES_FILE")" "none"
has "…list is the empty hint" "$(hn)" "no notes yet"

# ---------------------------------------------------------------- raw put / insert (the service's undo)
reset
hn raw put id1 "hello"; hn raw put id2 "world"
eq "raw put creates" "$(texts)" "hello|world"
eq "raw put makes it current" "$(hn show)" "world"
U0="$(jq -r '.sheets[0].updated' "$HYPR_NOTES_FILE")"
jq '.sheets[0].updated = "2020-01-01T00:00:00Z" | .sheets[0].created = "2020-01-01T00:00:00Z"' "$HYPR_NOTES_FILE" >"$T/x" && cat "$T/x" >"$HYPR_NOTES_FILE"
hn raw put id1 "hello"
eq "same text keeps updated" "$(jq -r '.sheets[0].updated' "$HYPR_NOTES_FILE")" "2020-01-01T00:00:00Z"
eq "…but flips current" "$(hn show)" "hello"
hn raw put id1 "hello again"
[[ "$(jq -r '.sheets[0].updated' "$HYPR_NOTES_FILE")" != "2020-01-01T00:00:00Z" ]] && ok || bad "changed text bumps updated"
eq "created stays" "$(jq -r '.sheets[0].created' "$HYPR_NOTES_FILE")" "2020-01-01T00:00:00Z"
ITEM="$(jq -c '.sheets[0]' "$HYPR_NOTES_FILE")"
hn raw remove id1
hn raw insert "$ITEM" 0
eq "insert restores at its place" "$(texts)" "hello again|world"
eq "…as current" "$(hn show)" "hello again"
eq "…with its dates" "$(jq -r '.sheets[0].created' "$HYPR_NOTES_FILE")" "2020-01-01T00:00:00Z"
hn raw insert "$ITEM" 0; eq "insert of an id that exists does nothing" "$(texts)" "hello again|world"
rc 1 "insert of junk" hn raw insert '{"nope":1}' 0
rc 2 "raw unknown op" hn raw frob
rc 2 "raw put with no id" hn raw put "" text
INO="$(stat -c %i "$HYPR_NOTES_FILE")"; MT0="$(stat -c %Y.%y "$HYPR_NOTES_FILE")"
sleep 0.02; hn raw current id2; hn raw current id2
eq "writes keep the inode" "$(stat -c %i "$HYPR_NOTES_FILE")" "$INO"
M1="$(stat -c %y "$HYPR_NOTES_FILE")"; sleep 0.05; hn raw current id2
eq "a write that changes nothing does not touch the file" "$(stat -c %y "$HYPR_NOTES_FILE")" "$M1"
jq -e '.sheets[0].color = "yellow"' "$HYPR_NOTES_FILE" >"$T/x" && cat "$T/x" >"$HYPR_NOTES_FILE"
hn raw put id1 "coloured"; eq "color and other fields are kept" "$(jq -r '.sheets[0].color' "$HYPR_NOTES_FILE")" "yellow"
jq '.future = 1' "$HYPR_NOTES_FILE" >"$T/x" && cat "$T/x" >"$HYPR_NOTES_FILE"
hn add "more" >/dev/null; eq "unknown root keys are kept" "$(jq -r '.future' "$HYPR_NOTES_FILE")" "1"

# ---------------------------------------------------------------- current missing / stale: the last sheet
reset
mkdir -p "$(dirname "$HYPR_NOTES_FILE")"
printf '{"sheets":[{"id":"a","text":"A"},{"id":"b","text":"B"}]}' >"$HYPR_NOTES_FILE"
eq "no current in the file → last sheet" "$(hn show)" "B"
printf '{"sheets":[{"id":"a","text":"A"},{"id":"b","text":"B"}],"current":"gone"}' >"$HYPR_NOTES_FILE"
eq "stale current → last sheet" "$(hn show)" "B"
has "sheet without dates lists fine" "$(hn list)" " 1  A"
printf '{"sheets":[{"id":"a","text":"A"},{"bad":true},7,{"id":"b","text":"B"}],"current":"a"}' >"$HYPR_NOTES_FILE"
eq "malformed entries are skipped in the numbering" "$(hn show 2)" "B"
hn add "new" >/dev/null
eq "…and kept in the file (never dropped silently)" "$(jq -c '.sheets[1]' "$HYPR_NOTES_FILE")" '{"bad":true}'
hn rm 1 >/dev/null
eq "rm with a malformed neighbour" "$(hn show 1)" "B"

# ---------------------------------------------------------------- invalid files are refused
reset; mkdir -p "$(dirname "$HYPR_NOTES_FILE")"
for BAD in '{"sheets": [ {bad' '[1,2,3]' '{"sheets":"nope"}' '"just a string"' '42' '{"sheets":false,"k":1}' '{"todo":[1,2]}' '{}' '{"sheets":[]}{"sheets":[]}'; do
    printf '%s' "$BAD" >"$HYPR_NOTES_FILE"; rm -f "$HYPR_NOTES_FILE.rescue"
    rc 1 "add refuses [$BAD]" hn add x
    rc 1 "raw put refuses [$BAD]" hn raw put i x
    rc 1 "list refuses [$BAD]" hn list
    rc 1 "clear --yes refuses [$BAD]" hn clear --yes
    rc 1 "edit refuses [$BAD] before opening an editor" env EDITOR=/bin/false bash "$HN" edit
    rc 1 "rm refuses [$BAD]" hn rm 1
    eq "[$BAD] left byte for byte" "$(cat "$HYPR_NOTES_FILE")" "$BAD"
done
for HEX in '\xff\xfe\xff' '\x00\x00'; do
    printf "$HEX" >"$HYPR_NOTES_FILE"; SUM="$(sha256sum <"$HYPR_NOTES_FILE")"
    rc 1 "add refuses binary junk [$HEX]" hn add x
    rc 1 "list refuses binary junk [$HEX]" hn list
    eq "binary junk left byte for byte" "$(sha256sum <"$HYPR_NOTES_FILE")" "$SUM"
done
# a refused write keeps the text
printf '{"sheets": [ {bad' >"$HYPR_NOTES_FILE"; rm -f "$HYPR_NOTES_FILE.rescue"
hn add "refused thought" 2>/dev/null
has "refused add: text in .rescue" "$(cat "$HYPR_NOTES_FILE.rescue")" "refused thought"
hn raw put someid "refused put" 2>/dev/null
has "refused put: text in .rescue" "$(cat "$HYPR_NOTES_FILE.rescue")" "refused put"
hn raw insert '{"id":"u","text":"refused undo"}' 0 2>/dev/null
has "refused insert: text in .rescue" "$(cat "$HYPR_NOTES_FILE.rescue")" "refused undo"
has "…the caller is told" "$(hn add again 2>&1)" ".rescue"
L0="$(wc -l <"$HYPR_NOTES_FILE.rescue")"; hn raw current x 2>/dev/null; hn raw remove x 2>/dev/null
eq "ops without text add nothing to .rescue" "$(wc -l <"$HYPR_NOTES_FILE.rescue")" "$L0"
rm -f "$HYPR_NOTES_FILE.rescue"
printf '   \n\n' >"$HYPR_NOTES_FILE"
hn add "into a blank file" >/dev/null; eq "a whitespace-only file counts as empty" "$(texts)" "into a blank file"
: >"$HYPR_NOTES_FILE"
hn add "into an empty file" >/dev/null; eq "an empty file counts as empty" "$(texts)" "into an empty file"

# ---------------------------------------------------------------- clear
reset
has "clear with nothing" "$(hn clear --yes)" "no notes"
hn add a >/dev/null; hn add b >/dev/null
rc 1 "clear without --yes and no tty" bash -c "bash '$HN' clear </dev/null"
eq "…kept them" "$(texts)" "a|b"
rc 2 "clear with an unknown option" hn clear --now
has "clear --yes" "$(hn clear --yes)" "tore off 2"
eq "…empty" "$(jq -r '.sheets | length' "$HYPR_NOTES_FILE")" "0"

# ---------------------------------------------------------------- edit (a scripted $EDITOR)
reset
cat >"$T/ed-append" <<'EOF'
#!/usr/bin/env bash
printf 'edited line\n' >>"$1"
EOF
cat >"$T/ed-noop" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$T/ed-empty" <<'EOF'
#!/usr/bin/env bash
: >"$1"
EOF
cat >"$T/ed-fail" <<'EOF'
#!/usr/bin/env bash
printf 'ruined' >"$1"; exit 3
EOF
cat >"$T/ed-args" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "--flag" ]] && printf 'args ok\n' >"$2"
EOF
chmod +x "$T"/ed-*
EDITOR="$T/ed-append" hn edit >/dev/null
eq "edit on an empty pad creates a sheet" "$(texts)" "$(printf '\nedited line')"
reset
hn add one >/dev/null; hn add two >/dev/null
EDITOR="$T/ed-append" hn edit 1 >/dev/null
eq "edit n rewrites that sheet" "$(hn show 1)" "$(printf 'one\nedited line')"
eq "…and it becomes current" "$(hn show)" "$(printf 'one\nedited line')"
VISUAL="$T/ed-append" EDITOR="$T/ed-fail" hn edit 2 >/dev/null
eq "VISUAL wins, edit with no n = that n" "$(hn show 2)" "$(printf 'two\nedited line')"
hn raw current "$(jq -r '.sheets[0].id' "$HYPR_NOTES_FILE")"
EDITOR="$T/ed-append" hn edit >/dev/null
eq "edit with no n edits the current sheet" "$(hn show 1)" "$(printf 'one\nedited line\nedited line')"
has "unchanged says so" "$(EDITOR="$T/ed-noop" hn edit 1)" "unchanged"
rc 1 "a failing editor is an error" env EDITOR="$T/ed-fail" bash "$HN" edit 1
eq "…and changes nothing" "$(hn show 1)" "$(printf 'one\nedited line\nedited line')"
EDITOR="$T/ed-args --flag" hn edit 2 >/dev/null
eq "an EDITOR with arguments" "$(hn show 2)" "args ok"
has "emptied: dropped" "$(EDITOR="$T/ed-empty" hn edit 2)" "dropped"
eq "…one left" "$(jq -r '.sheets | length' "$HYPR_NOTES_FILE")" "1"
rc 3 "edit out of range" env EDITOR="$T/ed-noop" bash "$HN" edit 9
# the file goes bad while the editor is open: the edit survives
reset; hn add keep >/dev/null
cat >"$T/ed-breaks" <<EOF
#!/usr/bin/env bash
printf 'my precious edit\n' >"\$1"; printf '{bad' >"$HYPR_NOTES_FILE"
EOF
chmod +x "$T/ed-breaks"
ER="$(EDITOR="$T/ed-breaks" bash "$HN" edit 1 2>&1)"; RC=$?
eq "edit into a broken file fails" "$RC" "1"
KEPT="$(sed -n 's/.*your edit is still in //p' <<<"$ER")"
has "…and says where the text is" "$ER" "your edit is still in"
eq "…which really holds it" "$(cat "$KEPT" 2>/dev/null)" "my precious edit"
rm -f "$KEPT" "$HYPR_NOTES_FILE.rescue"
# bigger than one argv string: cut, not an error; said so
reset; hn add keep >/dev/null
cat >"$T/ed-huge" <<'EOF'
#!/usr/bin/env bash
python3 -c 'print("h"*200000)' >"$1"
EOF
chmod +x "$T/ed-huge"
has "a huge edit says it was cut" "$(EDITOR="$T/ed-huge" bash "$HN" edit 1 2>&1)" "the rest was cut"
eq "…and is stored capped" "$(jq -r '.sheets[0].text | length' "$HYPR_NOTES_FILE")" "4000"
has "add over the cap says so" "$(python3 -c 'print("x"*5000)' | bash "$HN" add - 2>&1)" "the rest was cut"
hasnt "add under the cap says nothing" "$(bash "$HN" add short 2>&1)" "the rest was cut"
ER="$(bash "$HN" rm 99 2>&1)"; eq "error messages do not print the exit status" "$ER" "hypr-notes: no sheet '99' (hypr-notes list)"

# ---------------------------------------------------------------- concurrent writes
reset
for i in $(seq 1 12); do hn add "writer $i" >/dev/null & done
for i in $(seq 1 12); do hn raw put "fixed$i" "put $i" & done
wait
eq "24 concurrent writers: nothing lost" "$(jq -r '.sheets | length' "$HYPR_NOTES_FILE")" "24"
eq "ids unique" "$(jq -r '.sheets | map(.id) | unique | length' "$HYPR_NOTES_FILE")" "24"
jq -e . "$HYPR_NOTES_FILE" >/dev/null && ok || bad "file is valid JSON after the storm"
[[ -f "$HYPR_NOTES_FILE.lock" ]] && ok || bad "the lock file sits next to it"

# ---------------------------------------------------------------- readers during a write storm never see a half-written file
reset; hn add seed >/dev/null
( for i in $(seq 1 40); do hn raw put "w$((i % 3))" "$(printf 'x%.0s' $(seq 1 200)) $i"; done ) &
WP=$!; BADREAD=0; READS=0
while kill -0 "$WP" 2>/dev/null; do
    O="$(hn list --json 2>/dev/null)" || BADREAD=$((BADREAD + 1))
    [[ "$(jq 'length' <<<"$O" 2>/dev/null)" -ge 1 ]] || BADREAD=$((BADREAD + 1))
    READS=$((READS + 1))
done
wait "$WP"
eq "no torn reads in $READS reads" "$BADREAD" "0"

# ---------------------------------------------------------------- -f overrides the env
reset
hn -f "$T/other.json" add "elsewhere" >/dev/null
eq "-f writes there" "$(jq -r '.sheets[0].text' "$T/other.json")" "elsewhere"
[[ ! -e "$HYPR_NOTES_FILE" ]] && ok || bad "-f did not touch the env file"
eq "default path" "$(env -u HYPR_NOTES_FILE HOME=/h XDG_DATA_HOME= bash "$HN" path)" "/h/.local/share/hypr-notes/notes.json"
eq "XDG_DATA_HOME path" "$(env -u HYPR_NOTES_FILE XDG_DATA_HOME=/d bash "$HN" path)" "/d/hypr-notes/notes.json"

# ---------------------------------------------------------------- menu, driven by a scripted stand-in for rofi
# Each call pops one answer line from $ANSWERS: "esc" = exit 1, otherwise printed; the args and rows are logged.
cat >"$T/fake-rofi" <<'EOF'
#!/usr/bin/env bash
printf 'ARGS %s\n' "$*" >>"$FAKE_LOG"
if [[ " $* " == *" -l 0 "* ]]; then :; else cat | sed 's/^/ROW /' >>"$FAKE_LOG"; fi
a="$(head -n 1 "$ANSWERS")"; sed -i 1d "$ANSWERS"
[[ "$a" == "esc" || -z "$a" ]] && exit 1
printf '%s\n' "$a"
EOF
chmod +x "$T/fake-rofi"
export HYPR_NOTES_ROFI="$T/fake-rofi" ANSWERS="$T/answers" FAKE_LOG="$T/log"
menu() { : >"$FAKE_LOG"; printf '%s\n' "$@" >"$ANSWERS"; hn menu; }
reset
menu esc
has "empty pad: row 0 is + New note…" "$(cat "$FAKE_LOG")" "ROW + New note…"
hasnt "empty pad: no remove row" "$(cat "$FAKE_LOG")" "Remove"
hasnt "empty pad: no bogus sheet row" "$(cat "$FAKE_LOG")" "ROW 0."
[[ ! -e "$HYPR_NOTES_FILE" ]] && ok || bad "menu + Esc wrote nothing"
menu 0 "typed thought" esc
eq "+ New note… pins the typed line" "$(texts)" "typed thought"
menu 0 esc esc
eq "Esc in the prompt pins nothing" "$(texts)" "typed thought"
menu 0 "   " esc
eq "a blank line pins nothing" "$(texts)" "typed thought"
hn add "$(printf 'multi\nline <b>&')" >/dev/null
menu 2 esc esc
L="$(cat "$FAKE_LOG")"
has "sheets by first line" "$L" "ROW 2. multi"
has "remove row with sheets" "$L" "ROW ✕ Remove…"
has "Enter shows the sheet, Pango-escaped" "$L" "line &lt;b&gt;&amp;"
has "the view has a back row" "$L" "ROW ← Back"
eq "showing changes nothing" "$(texts)" "$(printf 'typed thought|multi\nline <b>&')"
menu 2 1 esc
eq "tear off from the view" "$(texts)" "typed thought"
hn add other >/dev/null
menu 3 0 esc esc
eq "✕ Remove… picks a sheet to tear off" "$(texts)" "other"
: >"$FAKE_LOG"; printf '1\n1\nesc\n' >"$ANSWERS"; hn menu
eq "tearing off the last sheet" "$(jq -r '.sheets | length' "$HYPR_NOTES_FILE")" "0"
# --if-stock + the single-window lock
reset; hn add x >/dev/null
mkdir -p "$HOME/.config/overworld"; : >"$HOME/.config/overworld/enabled"
: >"$FAKE_LOG"; printf 'esc\n' >"$ANSWERS"; hn menu --if-stock
eq "--if-stock with Overworld on: no menu" "$(wc -c <"$FAKE_LOG")" "0"
rm "$HOME/.config/overworld/enabled"; mkdir -p "$HOME/.config/apothecary"; : >"$HOME/.config/apothecary/enabled"
hn menu --if-stock
eq "--if-stock with Apothecary on: no menu" "$(wc -c <"$FAKE_LOG")" "0"
rm "$HOME/.config/apothecary/enabled"
hn menu --if-stock
has "--if-stock with no theme: the menu" "$(cat "$FAKE_LOG")" "ROW 1. x"
rc 2 "menu with an unknown option" hn menu --what
: >"$FAKE_LOG"; printf 'esc\n' >"$ANSWERS"
( exec 8>"$XDG_RUNTIME_DIR/hypr-notes-menu.lock"; flock 8; hn menu )
eq "a second menu while one holds the lock is a no-op" "$(wc -c <"$FAKE_LOG")" "0"
unset HYPR_NOTES_ROFI

echo "hypr-notes: $pass passed, $fail failed"
(( fail == 0 ))
