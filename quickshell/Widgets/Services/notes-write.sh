#!/usr/bin/env bash
# notes-write.sh <file> <op> [args…] — thin shim for NotesService.qml: the rules and the flock + in-place write live in
# scripts/hypr-notes (shared with Apothecary and the stock desktop).  `help raw` there lists the ops.
HERE="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
FILE="$1"; shift
exec bash "$HERE/../../../scripts/hypr-notes" -f "$FILE" raw "$@"
