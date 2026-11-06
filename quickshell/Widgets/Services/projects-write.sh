#!/usr/bin/env bash
# projects-write.sh <file> <op> [args…] — read-modify-write of projects.json under flock, IN PLACE (`cat tmp > file`, never mv:
# the shell's FileView watches the inode).  Shared by ProjectsService.qml and `overworld projects`; the rules are in projects.jq.
#   add <title> [note] [built]      prints the new id          toggle <id>            set <id> built|progress
#   remove <id>                     edit <id> <title> [note]   move <id> <+1|-1>      clearbuilt
#   insert <json-item> <index>      (undo of a remove)
#   list                            n<TAB>status<TAB>id<TAB>title<TAB>note   in the displayed order, no write
#   resolve <n|id|title-text>       prints the id; status 3 = nothing matches, 4 = several match
# Env: OW_PROJECTS overrides <file> (tests).  A file that is not valid JSON is never overwritten.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQF="$HERE/projects.jq"
FILE="${OW_PROJECTS:-$1}"; shift
OP="${1:-}"; shift || true
command -v jq >/dev/null || { echo "projects: jq is required" >&2; exit 1; }

ID=""; TITLE=""; NOTE=""; STATUS=""; DELTA=0; AT=0; ITEM=null
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NEWID="$(printf '%x%04x' "$(date +%s)" $((RANDOM % 65536)))"
run_jq() {                      # run_jq <op> <file>
    jq "${JQ_FLAGS:--c}" --arg op "$1" --arg id "$ID" --arg title "$TITLE" --arg note "$NOTE" --arg status "$STATUS" --arg now "$NOW" \
       --arg newid "$NEWID" --argjson delta "$DELTA" --argjson at "$AT" --argjson item "$ITEM" -f "$JQF" "$2"
}

case "$OP" in
    list|resolve)
        [[ -s "$FILE" ]] || { [[ "$OP" == list ]] && exit 0; echo "projects: no projects yet" >&2; exit 3; }
        ordered="$(run_jq ordered "$FILE")" || { echo "projects: $FILE is not valid JSON" >&2; exit 1; }
        if [[ "$OP" == list ]]; then
            jq -r 'to_entries[] | [(.key + 1), (.value.status // "progress"), .value.id, .value.title, (.value.note // "")] | @tsv' <<<"$ordered"
            exit 0
        fi
        q="${1:-}"
        res="$(jq -r --arg q "$q" '
            ($q | ascii_downcase) as $l
            | (if ($q | test("^[0-9]+$")) and ($q | tonumber) >= 1 and ($q | tonumber) <= length then .[($q | tonumber) - 1].id
               else ([.[] | select(.id == $q)][0].id // null) end) as $direct
            | ([.[] | select(.title | ascii_downcase == $l)]) as $exact
            | if $direct != null then $direct
              elif ($exact | length) == 1 then $exact[0].id
              else ([.[] | select(.title | ascii_downcase | startswith($l))]) as $pre
                | (if ($pre | length) > 0 then $pre else [.[] | select(.title | ascii_downcase | contains($l))] end) as $m
                | if ($m | length) == 1 then $m[0].id elif ($m | length) == 0 then "!none" else "!many" end
              end' <<<"$ordered")"
        case "$res" in
            '!none') echo "projects: nothing matches '$q'" >&2; exit 3 ;;
            '!many') echo "projects: '$q' matches several projects: use more of the title, or the number from 'overworld projects list'" >&2; exit 4 ;;
            *) echo "$res"; exit 0 ;;
        esac ;;
    add) TITLE="${1:-}"; NOTE="${2:-}"; [[ "${3:-}" == built ]] && STATUS=built
         [[ -n "${TITLE//[[:space:]]/}" ]] || { echo "projects: empty title" >&2; exit 2; } ;;
    toggle|remove) ID="${1:-}" ;;
    set) ID="${1:-}"; STATUS="${2:-}" ;;
    edit) ID="${1:-}"; TITLE="${2:-}"; NOTE="${3:-}"; [[ -n "${TITLE//[[:space:]]/}" ]] || { echo "projects: empty title" >&2; exit 2; } ;;
    move) ID="${1:-}"; DELTA="${2:-0}" ;;
    clearbuilt) ;;
    insert) ITEM="${1:-null}"; AT="${2:-0}" ;;
    *) echo "projects-write: unknown op '$OP'" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$FILE")"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
(
    flock 9
    [[ -s "$FILE" ]] || printf '{"items":[]}\n' >"$FILE"
    JQ_FLAGS=-M run_jq "$OP" "$FILE" >"$TMP" || { echo "projects: could not update $FILE (is it valid JSON?)" >&2; exit 1; }
    cat "$TMP" >"$FILE"
) 9>>"$FILE.lock" || exit 1
[[ "$OP" == add ]] && echo "$NEWID"
exit 0
