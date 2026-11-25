#!/usr/bin/env bash
# A stand-in for google_api.py (the hypr-gcal backend) for offscreen renders and tests — never talks to Google.
#   calendar list …    prints $FAKE_EVENTS (a JSON file), or fails when FAKE_FAIL is set / the file $FAKE_FAIL_FILE exists; FAKE_SLOW=<s> waits first
#   calendar create …  logs its arguments to $FAKE_LOG and pretends it worked
[[ -n "${FAKE_LOG:-}" ]] && echo "$@" >> "$FAKE_LOG"
[[ -n "${FAKE_SLOW:-}" ]] && sleep "$FAKE_SLOW"
[[ -n "${FAKE_FAIL:-}" || ( -n "${FAKE_FAIL_FILE:-}" && -e "${FAKE_FAIL_FILE:-}" ) ]] && { echo "ConnectionError: Max retries exceeded (fake backend)" >&2; exit 1; }
case "$1 $2" in
    "calendar list") cat "${FAKE_EVENTS:?FAKE_EVENTS not set}" ;;
    "calendar create") echo '{"status":"created","id":"fake-new","summary":"x","htmlLink":"https://example.invalid/event/new"}' ;;
    *) exit 3 ;;
esac
