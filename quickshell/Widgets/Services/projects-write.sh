#!/usr/bin/env bash
# projects-write.sh <file> <op> [args…] — thin shim kept for ProjectsService.qml: the rules and the flock + in-place write now live in
# scripts/hypr-projects (shared with Apothecary and the stock desktop).  `help raw` there lists the ops.
HERE="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
FILE="$1"; shift
exec bash "$HERE/../../../scripts/hypr-projects" -f "$FILE" raw "$@"
