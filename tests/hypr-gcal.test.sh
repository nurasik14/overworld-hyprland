#!/usr/bin/env bash
# Test suite for scripts/hypr-gcal — parser, normalisation, cache, dry-run add; a fake backend stands in for Google, never the real calendar.
#   bash tests/hypr-gcal.test.sh [path/to/hypr-gcal]
set -uo pipefail
G="${1:-$(cd "$(dirname "$0")/.." && pwd)/scripts/hypr-gcal}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"                 # DEFAULT_BACKEND lives under $HOME: nothing real is found
export TZ=Asia/Hong_Kong PYTHONDONTWRITEBYTECODE=1
export HYPR_GCAL_CACHE="$T/cache/events.json" HYPR_GCAL_CONFIG="$T/config/config.json"
export HYPR_GCAL_NOW=2026-11-25T11:00:00+08:00
export FAKE_EVENTS="$T/events.json" FAKE_LOG="$T/log.txt"
unset HYPR_GCAL_DRYRUN HYPR_GCAL_BACKEND HYPR_GCAL_OPENER
pass=0; fail=0
ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
eq()   { [[ "$2" == "$3" ]] && ok || bad "$1" "expected [$3] got [$2]"; }
has()  { [[ "$2" == *"$3"* ]] && ok || bad "$1" "[$2] does not contain [$3]"; }
hasnt(){ [[ "$2" != *"$3"* ]] && ok || bad "$1" "[$2] contains [$3]"; }
rc()   { local want="$1" name="$2"; shift 2; "$@" >/dev/null 2>&1; local got=$?; [[ "$got" == "$want" ]] && ok || bad "$name" "exit $got, wanted $want"; }
g()    { python3 -I "$G" "$@"; }
c()    { jq -r "$1" "$HYPR_GCAL_CACHE"; }
reset(){ rm -rf "$T/cache" "$T/log.txt"; }

cat >"$T/backend.sh" <<'FB'
#!/usr/bin/env bash
echo "$@" >> "$FAKE_LOG"
[[ -n "${FAKE_FAIL:-}" ]] && { echo "ConnectionError: Max retries exceeded (fake)" >&2; exit 1; }
[[ -n "${FAKE_JUNK:-}" ]] && { echo "<html>login</html>"; exit 0; }
[[ "$1 $2" == "calendar list" ]] && { cat "$FAKE_EVENTS"; exit 0; }
[[ "$1 $2" == "calendar create" ]] && { echo '{"status":"created","id":"newid"}'; exit 0; }
exit 3
FB
chmod +x "$T/backend.sh"
cat >"$T/events.json" <<'EOF2'
[
 {"id":"e1","summary":"[class] Algorithms lecture","start":"2026-11-25T10:30:00+08:00","end":"2026-11-25T12:00:00+08:00","location":"LT-9","description":"Week 12","status":"confirmed","htmlLink":"https://example.invalid/e1"},
 {"id":"e2","summary":"[opp] [email] Reply to the club","start":"2026-11-25T16:00:00+08:00","end":"2026-11-25T16:30:00+08:00","location":"","description":"","status":"confirmed","htmlLink":"https://example.invalid/e2"},
 {"id":"e3","summary":"Exam: Calculus","start":"2026-11-27","end":"2026-11-28","location":"","description":"","status":"confirmed","htmlLink":"https://example.invalid/e3"},
 {"id":"e4","summary":"Gone","start":"2026-11-26T10:00:00+08:00","end":"2026-11-26T11:00:00+08:00","status":"cancelled"},
 {"id":"e5","summary":"Hackathon","start":"2026-11-28","end":"2026-11-30","status":"confirmed"},
 {"id":"e6","summary":"Night shift","start":"2026-11-25T23:00:00+08:00","end":"2026-11-26T01:00:00+08:00","status":"confirmed"},
 {"id":"e7","summary":"[weird thing] Odd prefix","start":"2026-12-01T09:00:00Z","end":"2026-12-01T10:00:00Z","status":"confirmed"},
 {"id":"e8","summary":"[tag-only]","start":"2026-12-02T09:00:00+08:00","end":"2026-12-02T10:00:00+08:00"},
 {"id":"e9","summary":"Made by add","start":"2026-12-03T00:00:00+08:00","end":"2026-12-04T00:00:00+08:00"},
 {"id":"e10","summary":"Ends at midnight","start":"2026-12-04T20:00:00+08:00","end":"2026-12-05T00:00:00+08:00"},
 {"id":"e11","summary":"Long notes","start":"2026-12-05T09:00:00+08:00","end":"2026-12-05T10:00:00+08:00","description":"LONGTEXT"},
 {"id":"e1","summary":"Duplicate id","start":"2026-12-06T09:00:00+08:00","end":"2026-12-06T10:00:00+08:00"},
 {"summary":"No id","start":"2026-12-06T09:00:00+08:00","end":"2026-12-06T10:00:00+08:00"},
 {"id":"e12","summary":"No usable start","start":"","end":""}
]
EOF2
long="$(python3 -c "print('x' * 900)")"; sed -i "s/LONGTEXT/$long/" "$T/events.json"

# ---- help has no side effects (not even on unknown arguments / with a command in front)
reset
has "-h prints usage" "$(g -h)" "hypr-gcal sync"
rc 0 "-h exits 0" g -h
rc 0 "--help exits 0" g --help
rc 0 "help exits 0" g help
rc 0 "no args = usage, exit 0" g
has "sync -h prints usage" "$(g sync -h)" "hypr-gcal sync"
has "add --bogus -h prints usage" "$(g add --bogus -h)" "hypr-gcal add"
[[ ! -e "$T/cache" && ! -e "$T/config" ]] && ok || bad "help created files"
rc 2 "unknown command exits 2" g frobnicate
rc 2 "sync with an unknown flag exits 2" g sync --bogus
[[ ! -e "$T/cache" ]] && ok || bad "unknown args created the cache dir"
rc 0 "help leaves the log alone" test ! -e "$T/log.txt"

# ---- not configured: no backend anywhere
reset
rc 2 "sync without a backend exits 2" g sync
eq "…error is not-configured" "$(c .error)" "not-configured"
eq "…no events" "$(c '.events | length')" "0"
eq "status is not-configured" "$(g status | head -1)" "not configured"
rc 2 "status exits 2" g status
eq "status --json state" "$(g status --json | jq -r .state)" "not-configured"
eq "next prints nothing" "$(g next)" ""
rm -rf "$T/cache"; rc 1 "list without a cache is an error" g list
eq "list --json without a cache" "$(g list --json)" "[]"
# config file and env pick a backend
mkdir -p "$T/config"; echo "{\"backend\": \"$T/backend.sh\"}" >"$HYPR_GCAL_CONFIG"
rc 0 "sync via config.json" g sync
eq "…config backend used" "$(c .ok)" "true"
rm -f "$HYPR_GCAL_CONFIG"; rc 2 "…and without it again: not-configured" g sync
# the default backend is google_api.py under $HOME, run with a Python that can import the Google libraries (the system python3 has none)
H2="$T/home2"; GA="$H2/.hermes/skills/productivity/google-workspace/scripts"; VP="$H2/.hermes/installs/a/environments/b/venv/bin"
mkdir -p "$GA" "$VP"
cat >"$GA/google_api.py" <<'PY'
import json, sys
open(sys.argv[0] + ".log", "a").write(" ".join(sys.argv[1:]) + "\n")
print(json.dumps([{"id": "g1", "summary": "[class] From google_api", "start": "2026-11-26T09:00:00+08:00", "end": "2026-11-26T10:00:00+08:00", "status": "confirmed"}]))
PY
printf '#!/usr/bin/env bash\n[[ "$1" == -c ]] && exit 0\nexec python3 "$@"\n' >"$VP/python3"; chmod +x "$VP/python3"     # "has the libraries": the probe (-c import) succeeds
gd() { env -u HYPR_GCAL_BACKEND HOME="$H2" HYPR_GCAL_PROBE=no_such_google_module_xyz python3 -I "$G" "$@"; }
reset; gd sync >/dev/null 2>&1; eq "default backend: sync works through the venv python" "$(c '.events[0].title + "|" + .events[0].tag')" "From google_api|class"
has "…google_api.py got the list call" "$(cat "$GA/google_api.py.log")" "calendar list --start"
eq "…dry-run add names the venv python and the script" "$(HYPR_GCAL_DRYRUN=1 gd add Lab 2026-12-03 9:00 | cut -d' ' -f1-3)" "dry-run: $VP/python3 $GA/google_api.py"
rm -rf "$H2/.hermes/installs"; PYX="$(python3 -I -c 'import sys; print(sys.executable)')"
eq "no interpreter with the libraries: the running python is the fallback (the failure, if any, is reported by the backend)" "$(HYPR_GCAL_DRYRUN=1 gd add Lab 2026-12-03 9:00 | cut -d' ' -f1-3)" "dry-run: $PYX $GA/google_api.py"
eq "a bad HYPR_GCAL_PYTHON is skipped" "$(HYPR_GCAL_PYTHON=/nonexistent/python HYPR_GCAL_DRYRUN=1 gd add Lab 2026-12-03 9:00 | cut -d' ' -f2)" "$PYX"
export HYPR_GCAL_BACKEND="$T/backend.sh"

# ---- sync + normalisation
reset
has "sync reports the count" "$(g sync)" "synced 10 events"
eq "ok" "$(c .ok)" "true"
eq "error null" "$(c .error)" "null"
has "calendar list asked for the range" "$(cat "$T/log.txt")" "calendar list --start 2026-11-18T00:00:00+08:00 --end 2027-01-25T00:00:00+08:00 --max 500"
eq "range from/to" "$(c '.range.from + " " + .range.to')" "2026-11-18 2027-01-24"
eq "cancelled dropped" "$(c '[.events[] | select(.id == "e4")] | length')" "0"
eq "no-id and no-start dropped, duplicate id once" "$(c '[.events[].id] | sort | join(",")')" "e1,e10,e11,e2,e3,e5,e6,e7,e8,e9"
eq "tag extracted and stripped" "$(c '.events[] | select(.id == "e1") | .tag + "|" + .title')" "class|Algorithms lecture"
eq "two prefixes: first is the tag, both stripped" "$(c '.events[] | select(.id == "e2") | .tag + "|" + .title')" "opp|Reply to the club"
eq "no prefix: empty tag" "$(c '.events[] | select(.id == "e3") | .tag + "|" + .title')" "|Exam: Calculus"
eq "unknown prefix kept as a tag" "$(c '.events[] | select(.id == "e7") | .tag')" "weird thing"
eq "a title that is only a tag keeps the text" "$(c '.events[] | select(.id == "e8") | .tag + "|" + .title')" "|[tag-only]"
eq "timed: start/end local ISO" "$(c '.events[] | select(.id == "e1") | .start + " " + .end')" "2026-11-25T10:30:00+08:00 2026-11-25T12:00:00+08:00"
eq "timed: allDay false, day = lastDay" "$(c '.events[] | select(.id == "e1") | (.allDay | tostring) + " " + .day + " " + .lastDay')" "false 2026-11-25 2026-11-25"
eq "UTC event converted to local time" "$(c '.events[] | select(.id == "e7") | .start')" "2026-12-01T17:00:00+08:00"
eq "all day: dates, end exclusive" "$(c '.events[] | select(.id == "e3") | .start + " " + .end + " " + (.allDay | tostring)')" "2026-11-27 2026-11-28 true"
eq "all day: day / lastDay" "$(c '.events[] | select(.id == "e3") | .day + " " + .lastDay')" "2026-11-27 2026-11-27"
eq "multi-day all day: lastDay inclusive" "$(c '.events[] | select(.id == "e5") | .day + " " + .lastDay')" "2026-11-28 2026-11-29"
eq "timed across midnight: lastDay" "$(c '.events[] | select(.id == "e6") | .day + " " + .lastDay')" "2026-11-25 2026-11-26"
eq "timed ending exactly at midnight stays on its day" "$(c '.events[] | select(.id == "e10") | .day + " " + .lastDay + " " + (.allDay | tostring)')" "2026-12-04 2026-12-04 false"
eq "midnight-to-midnight timed = all day (what add makes)" "$(c '.events[] | select(.id == "e9") | (.allDay | tostring) + " " + .start + " " + .end')" "true 2026-12-03 2026-12-04"
eq "description trimmed to 400" "$(c '.events[] | select(.id == "e11") | .description | length')" "400"
eq "…with an ellipsis" "$(c '.events[] | select(.id == "e11") | .description[-1:]')" "…"
eq "location + link carried" "$(c '.events[] | select(.id == "e1") | .location + " " + .link')" "LT-9 https://example.invalid/e1"
eq "sorted: day, all-day first, start" "$(c '[.events[0:6][].id] | join(",")')" "e1,e2,e6,e3,e5,e7"
eq "updated is the sync time" "$(c .updated)" "2026-11-25T11:00:00+08:00"
[[ "$(stat -c %a "$HYPR_GCAL_CACHE")" == "600" ]] && ok || bad "cache is private (600)"
python3 -I -c "import json,sys; d=json.load(open(sys.argv[1])); assert set(d)=={'updated','ok','error','lastError','range','events'}" "$HYPR_GCAL_CACHE" && ok || bad "cache keys"

# ---- a failed sync keeps the last good data
ino1="$(stat -c %i "$HYPR_GCAL_CACHE")"
HYPR_GCAL_NOW=2026-11-25T12:00:00+08:00 FAKE_FAIL=1 g sync >/dev/null 2>"$T/err"; rcode=$?
eq "failed sync exits 1" "$rcode" "1"
has "…says why on stderr" "$(cat "$T/err")" "Max retries exceeded"
eq "…ok false" "$(c .ok)" "false"
eq "…error recorded" "$(c .error)" "ConnectionError: Max retries exceeded (fake)"
eq "…lastError time" "$(c .lastError)" "2026-11-25T12:00:00+08:00"
eq "…updated stays the last good sync" "$(c .updated)" "2026-11-25T11:00:00+08:00"
eq "…events kept" "$(c '.events | length')" "10"
eq "…same inode (written in place)" "$(stat -c %i "$HYPR_GCAL_CACHE")" "$ino1"
has "status says offline" "$(g status)" "offline"
rc 1 "status exits 1 when offline" g status
eq "list still works offline" "$(g today | wc -l)" "3"
FAKE_JUNK=1 g sync >/dev/null 2>&1; eq "junk instead of JSON: exit" "$?" "1"
eq "…keeps the events" "$(c '.events | length')" "10"
eq "…says so" "$(c .error)" "the backend did not return JSON"
echo '{"a":1}' >"$T/events2.json"; FAKE_EVENTS="$T/events2.json" g sync >/dev/null 2>&1
eq "an object instead of a list is refused" "$(c .error)" "the backend did not return a list"
eq "…events kept" "$(c '.events | length')" "10"
g sync >/dev/null; eq "next good sync recovers" "$(c .ok)" "true"
eq "…error cleared, lastError remembered" "$(c '(.error | tostring) + " " + .lastError')" "null 2026-11-25T11:00:00+08:00"
HYPR_GCAL_BACKEND="$T/nonexistent-cmd" g sync >/dev/null 2>&1; eq "a backend that cannot start: exit 1" "$?" "1"
eq "…kept" "$(c '.events | length')" "10"
g sync >/dev/null

# ---- stale
eq "fresh = ok" "$(g status --json | jq -r .state)" "ok"
eq "31 min later = stale" "$(HYPR_GCAL_NOW=2026-11-25T11:31:00+08:00 g status --json | jq -r .state)" "stale"
rc 0 "stale exits 0" env HYPR_GCAL_NOW=2026-11-25T11:31:00+08:00 python3 -I "$G" status

# ---- a second sync while one runs
( flock -x 9; sleep 3 ) 9>"$HYPR_GCAL_CACHE.sync" &
sleep 0.4
has "a second sync does not pile up" "$(g sync)" "another sync is running"
wait

# ---- reading
out="$(g list)"
has "list: day header" "$out" "Wed 25 Nov"
has "list: timed line with tag and location" "$out" "10:30-12:00  [class] Algorithms lecture  @LT-9"
eq "list --day timed lines" "$(g list --day 2026-11-25 | head -1)" "10:30-12:00  [class] Algorithms lecture  @LT-9"
has "all-day line" "$(g list --day 2026-11-27)" "all day      Exam: Calculus"
has "multi-day all-day shows on the second day" "$(g list --day 2026-11-29)" "Hackathon"
has "timed across midnight: start day" "$(g list --day 2026-11-25)" "23:00→"
has "timed across midnight: end day" "$(g list --day 2026-11-26)" "…-01:00"
eq "list --day tomorrow" "$(g list --day tomorrow | wc -l)" "1"
eq "list --day with no events" "$(g list --day 2026-12-20)" "no events"
eq "list --upcoming 2" "$(g list --upcoming 2 | grep -c '^  ')" "2"
has "upcoming skips what is over today" "$(HYPR_GCAL_NOW=2026-11-25T13:00:00+08:00 g list --upcoming 1)" "Reply to the club"
eq "list --json is a JSON array" "$(g list --day 2026-11-25 --json | jq 'length')" "3"
rc 2 "list --day garbage" g list --day banana
eq "today" "$(g today | wc -l)" "3"
eq "today with nothing" "$(HYPR_GCAL_NOW=2026-12-20T09:00:00+08:00 g today)" "nothing today"
eq "next while one is running" "$(g next)" "now Algorithms lecture @LT-9"
eq "next, soon" "$(HYPR_GCAL_NOW=2026-11-25T12:30:00+08:00 g next)" "16:00 Reply to the club"
eq "next, within 90 min" "$(HYPR_GCAL_NOW=2026-11-25T15:00:00+08:00 g next)" "16:00 (in 60m) Reply to the club"
eq "next, all-day only" "$(HYPR_GCAL_NOW=2026-11-27T09:00:00+08:00 g next)" "all day today Exam: Calculus"
eq "next: tomorrow" "$(HYPR_GCAL_NOW=2026-11-30T20:00:00+08:00 g next)" "tomorrow 17:00 Odd prefix"
eq "next: nothing left prints nothing" "$(HYPR_GCAL_NOW=2027-02-01T09:00:00+08:00 g next)" ""
has "status line" "$(g status)" "ok · 10 events"
eq "status --json count" "$(g status --json | jq .count)" "10"
eq "path" "$(g path)" "$HYPR_GCAL_CACHE"

# ---- the date words
d() { g parse x --date "$1" | jq -r .date; }
eq "today" "$(d today)" "2026-11-25"
eq "tomorrow" "$(d tomorrow)" "2026-11-26"
eq "yesterday" "$(d yesterday)" "2026-11-24"
eq "+3" "$(d +3)" "2026-11-28"
eq "-2" "$(d -2)" "2026-11-23"
eq "ISO" "$(d 2027-01-05)" "2027-01-05"
eq "MM-DD this year" "$(d 12-05)" "2026-12-05"
eq "MM-DD already long past rolls to next year" "$(d 03-01)" "2027-03-01"
eq "D.M" "$(d 5.12)" "2026-12-05"
eq "weekday: Fri" "$(d fri)" "2026-11-27"
eq "weekday: today counts (Wed)" "$(d wed)" "2026-11-25"
eq "weekday: Tuesday = next" "$(d tuesday)" "2026-12-01"
rc 2 "bad date" g parse x --date 2026-13-40
rc 2 "bad word" g parse x --date someday

# ---- the line parser (parse prints JSON, creates nothing)
p() { g parse "$1" --date 2026-12-03 | jq -r '(if .allDay then "all" else (.start[11:16] + "-" + .end[11:16]) end) + "|" + .title + "|" + .location'; }
eq "14:00 Meeting @MMW2450" "$(p '14:00 Meeting @MMW2450')" "14:00-15:00|Meeting|MMW2450"
eq "all day Exam" "$(p 'all day Exam')" "all|Exam|"
eq "allday / all-day / All Day" "$(p 'allday A'),$(p 'all-day B'),$(p 'All Day C')" "all|A|,all|B|,all|C|"
eq "9:30-11 Lab" "$(p '9:30-11 Lab')" "09:30-11:00|Lab|"
eq "9:30 - 11 spaced" "$(p '9:30 - 11:15 Lab')" "09:30-11:15|Lab|"
eq "en dash" "$(p '9:30–11 Lab')" "09:30-11:00|Lab|"
eq "to" "$(p '9 to 11 Lab')" "09:00-11:00|Lab|"
eq "a range may end past midnight" "$(p '23:00-1:00 Night shift')" "23:00-01:00|Night shift|"
eq "2pm" "$(p '2pm Call')" "14:00-15:00|Call|"
eq "2:30 pm" "$(p '2:30 pm Call')" "14:30-15:30|Call|"
eq "12am is midnight, 12pm noon" "$(p '12am A'),$(p '12pm B')" "00:00-01:00|A|,12:00-13:00|B|"
eq "10am-12pm" "$(p '10am-12pm Class')" "10:00-12:00|Class|"
eq "+1h30" "$(p '9:00 +1h30 Lab')" "09:00-10:30|Lab|"
eq "for 90m" "$(p '14:00 for 90m Study')" "14:00-15:30|Study|"
eq "for 2h" "$(p '14:00 for 2h Study')" "14:00-16:00|Study|"
eq "at 9 (a bare hour needs 'at')" "$(p 'at 9 Lab')" "09:00-10:00|Lab|"
eq "a bare number is part of the title" "$(p '9 lives')" "all|9 lives|"
eq "title with a colon after the time" "$(p '14:00: Meeting')" "14:00-15:00|Meeting|"
eq "tag prefix is kept for Google to show" "$(p '[class] 14:00 x')" "all|[class] 14:00 x|"
eq "time then tag" "$(p '14:00 [class] Lab')" "14:00-15:00|[class] Lab|"
eq "location with spaces runs to the end" "$(p '9:00 Lab @MMW 2450')" "09:00-10:00|Lab|MMW 2450"
eq "a lone @ in a word is not a location" "$(p 'mail a@b.c')" "all|mail a@b.c|"
eq "no time = all day" "$(p 'Buy a gift')" "all|Buy a gift|"
eq "whitespace collapsed" "$(p '  14:00    Team    sync  ')" "14:00-15:00|Team sync|"
eq "a time that does not exist is part of the title" "$(p '25:00 Odd')" "all|25:00 Odd|"
eq "24:00 end" "$(p '22:00-24:00 Late')" "22:00-00:00|Late|"
rc 2 "empty line" g parse ""
rc 2 "time but no title" g parse "14:00"
rc 2 "all day but no title" g parse "all day"
rc 2 "only a location" g parse "@MMW2450"
eq "title cap 200" "$(g parse "$(python3 -c "print('t' * 300)")" | jq '.title | length')" "200"
eq "unicode title" "$(p '14:00 Лекция по алгебре @LT-1')" "14:00-15:00|Лекция по алгебре|LT-1"

# ---- add: dry run prints the exact backend command, runs nothing
reset
export HYPR_GCAL_DRYRUN=1
BE="$T/backend.sh"
eq "dry-run --parse" "$(g add --parse '14:00 Meeting @MMW2450' --date 2026-12-03)" "dry-run: $BE calendar create --summary Meeting --start 2026-12-03T14:00:00+08:00 --end 2026-12-03T15:00:00+08:00 --location MMW2450"
eq "dry-run positional with duration" "$(g add 'Dentist' 2026-12-03 14:00 1h30 --location Clinic)" "dry-run: $BE calendar create --summary Dentist --start 2026-12-03T14:00:00+08:00 --end 2026-12-03T15:30:00+08:00 --location Clinic"
eq "dry-run positional with end time" "$(g add 'Lab' 12-03 9:30 11:00)" "dry-run: $BE calendar create --summary Lab --start 2026-12-03T09:30:00+08:00 --end 2026-12-03T11:00:00+08:00"
eq "dry-run positional start only = 1 h" "$(g add 'Lab' 2026-12-03 9:30)" "dry-run: $BE calendar create --summary Lab --start 2026-12-03T09:30:00+08:00 --end 2026-12-03T10:30:00+08:00"
eq "dry-run all day = midnight to midnight" "$(g add 'Exam' 2026-12-03)" "dry-run: $BE calendar create --summary Exam --start 2026-12-03T00:00:00+08:00 --end 2026-12-04T00:00:00+08:00"
eq "dry-run description" "$(g add 'Exam' 2026-12-03 --description 'room 5')" "dry-run: $BE calendar create --summary Exam --start 2026-12-03T00:00:00+08:00 --end 2026-12-04T00:00:00+08:00 --description 'room 5'"
eq "dry-run quotes odd characters" "$(g add "It's \"x\" \$HOME" 2026-12-03 | sed 's/.*--summary //; s/ --start.*//')" "'It'\"'\"'s \"x\" \$HOME'"
eq "dry-run --parse with --date tomorrow" "$(g add --parse 'all day Exam' --date tomorrow | grep -o '2026-11-26T00:00:00+08:00' | head -1)" "2026-11-26T00:00:00+08:00"
eq "--location overrides the @place" "$(g add --parse '9:00 Lab @A' --date 2026-12-03 --location B | grep -o -- '--location .*')" "--location B"
[[ ! -e "$T/log.txt" ]] && ok || bad "dry-run called the backend" "$(cat "$T/log.txt" 2>/dev/null)"
[[ ! -e "$T/cache" ]] && ok || bad "dry-run wrote the cache"
rc 2 "add without a date" g add "Only a title"
rc 2 "add with a bad time" g add Lab 2026-12-03 25:99
rc 2 "add with a bad end" g add Lab 2026-12-03 9:00 soon
rc 2 "add --parse with positional junk" g add --parse "9:00 Lab" extra
rc 2 "add empty title" g add "  " 2026-12-03
unset HYPR_GCAL_DRYRUN
# ---- add for real against the FAKE backend: create call, then a re-sync
reset
out="$(g add --parse '9:30-11 Lab @MMW2450' --date 2026-12-03)"
eq "add says what it did" "$out" "added: Lab on 2026-12-03 09:30-11:00"
eq "backend got exactly one create" "$(grep -c '^calendar create' "$T/log.txt")" "1"
eq "…with the right arguments" "$(grep '^calendar create' "$T/log.txt")" "calendar create --summary Lab --start 2026-12-03T09:30:00+08:00 --end 2026-12-03T11:00:00+08:00 --location MMW2450"
eq "…then re-synced" "$(grep -c '^calendar list' "$T/log.txt")" "1"
eq "…the cache exists afterwards" "$(c .ok)" "true"
reset
FAKE_FAIL=1 g add Lab 2026-12-03 >/dev/null 2>"$T/err"; eq "a failing create exits 1" "$?" "1"
has "…and says why" "$(cat "$T/err")" "Max retries exceeded"
hasnt "…without claiming success" "$(cat "$T/err")" "added"
unset HYPR_GCAL_BACKEND; rc 2 "add without a backend exits 2" g add Lab 2026-12-03
HYPR_GCAL_DRYRUN=1 g add Lab 2026-12-03 | grep -q '<no-backend>' && ok || bad "dry-run without a backend says so"
export HYPR_GCAL_BACKEND="$T/backend.sh"

# ---- open
g sync >/dev/null
eq "open prints the opener command in dry-run" "$(HYPR_GCAL_DRYRUN=1 g open e1)" "dry-run: xdg-open https://example.invalid/e1"
rc 1 "open: an ambiguous id prefix" g open e
printf '#!/usr/bin/env bash\necho "$@" > "%s/opened"\n' "$T" >"$T/opener.sh"; chmod +x "$T/opener.sh"
HYPR_GCAL_OPENER="$T/opener.sh" g open e2; sleep 0.3
eq "open runs the opener with the link" "$(cat "$T/opened" 2>/dev/null)" "https://example.invalid/e2"
rc 1 "open: unknown id" g open nosuch
rc 1 "open: an event without a link" g open e8
rc 2 "open: no id" g open

# ---- syntax
python3 -I -m py_compile "$G" 2>/dev/null && ok || bad "py_compile"
rm -rf "$(dirname "$G")/__pycache__"

printf '%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" == 0 ]]
