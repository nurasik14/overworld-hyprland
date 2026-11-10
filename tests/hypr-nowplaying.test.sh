#!/usr/bin/env bash
# tests/hypr-nowplaying.test.sh [path/to/hypr-nowplaying] — the shared Now Playing daemon/CLI, entirely in temp dirs:
# temp token, runtime, cache, a random port. Nothing touches ~/.local/share/hypr-nowplaying, $XDG_RUNTIME_DIR or ~/.cache.
#   NP_REAL=1   also fetch one real, short YouTube video with yt-dlp into the temp cache and ffprobe it (network)
set -uo pipefail
NP="$(realpath "${1:-$(dirname "$0")/../scripts/hypr-nowplaying}")"
T="$(mktemp -d /tmp/np-test.XXXXXX)"
export HYPR_NOWPLAYING_DATA="$T/data" HYPR_NOWPLAYING_RUNTIME="$T/run" HYPR_NOWPLAYING_CACHE="$T/cache"
PORT=$(( 20000 + RANDOM % 20000 ))
export HYPR_NOWPLAYING_PORT=$PORT
pass=0; fail=0
ok()   { pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s  [%s]\n' "$1" "${2:-}"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "$2"; fi; }
SPID=""
cleanup() { [[ -n "$SPID" ]] && kill "$SPID" 2>/dev/null; wait 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

URL="http://127.0.0.1:$PORT"
post() {   # post <path> <json> [token]  -> prints "code body"
    local tok="${3-$(cat "$T/data/token" 2>/dev/null)}"
    curl -s -o "$T/body" -w '%{http_code}' -X POST -H "X-Hypr-Nowplaying-Token: $tok" -H 'Content-Type: application/json' \
        --data-binary "$2" "$URL$1"; printf ' '; cat "$T/body"
}
state() { jq -r "$1" "$T/run/state.json" 2>/dev/null; }
fake_mp4() {   # fake_mp4 <file> <kb>: an ftyp header + zeros (passes the magic check, not a playable video)
    { printf '\x00\x00\x00\x18ftypisom\x00\x00\x02\x00isomiso2'; head -c $(( $2 * 1024 - 24 )) /dev/zero; } >"$1"
}
start() {   # start [extra serve args]
    "$NP" serve --keep "$@" >"$T/serve.log" 2>&1 &
    SPID=$!
    for _ in $(seq 1 50); do
        curl -s -o /dev/null "$URL/ping" 2>/dev/null && return 0
        sleep 0.1
    done
    return 1
}
stop() { [[ -n "$SPID" ]] && kill "$SPID" 2>/dev/null; wait "$SPID" 2>/dev/null; SPID=""; }

# ------------------------------------------------------------------ CLI basics
check "help prints usage"           '"$NP" -h | grep -q "serve \[--port"'
check "unknown verb exits 2"        '! "$NP" bogus 2>/dev/null; [[ $? -eq 0 ]]; "$NP" bogus >/dev/null 2>&1; [[ $? -eq 2 ]]'
check "init creates a token"        '"$NP" init | grep -q created && [[ -s "$T/data/token" ]]'
check "token is 0600, dir 0700"     '[[ "$(stat -c %a "$T/data/token")" == 600 && "$(stat -c %a "$T/data")" == 700 ]]'
TOKEN="$(cat "$T/data/token")"
check "init keeps the token"        '"$NP" init | grep -q kept && [[ "$(cat "$T/data/token")" == "$TOKEN" ]]'
cp "$T/data/token" "$T/token.keep"; : >"$T/data/token"
check "an empty token file is replaced" '"$NP" init | grep -q created && [[ $(wc -c <"$T/data/token") -gt 30 && "$(stat -c %a "$T/data/token")" == 600 ]]'
cp "$T/token.keep" "$T/data/token"
check "status when stopped"         '"$NP" status | grep -q "not running"'
check "status --json when stopped"  '[[ "$("$NP" status --json | jq -r .running)" == false ]]'
check "path lists the files"        '"$NP" path | grep -q "^state  $T/run/state.json"'

# ------------------------------------------------------------------ userscript
"$NP" userscript --port 4242 >"$T/us.out" 2>&1
US="$T/cache/userscript/nowplaying-bridge.user.js"
check "userscript written"          '[[ -s "$US" ]]'
check "userscript has the token"    'grep -qF "$TOKEN" "$US"'
check "userscript has the port"     'grep -q "4242" "$US" && ! grep -q "__HYPR_NOWPLAYING_PORT__" "$US"'
check "userscript is private"       '[[ "$(stat -c %a "$US")" == 600 ]]'
check "userscript --print = stdout" '"$NP" userscript --print | grep -q "==UserScript=="'
check "the repo template has no token" '! grep -qF "$TOKEN" "$(dirname "$NP")/../apps/zen/nowplaying-bridge.user.js"'
( "$NP" userscript --serve --port 4242 >"$T/serve-us.out" 2>&1 & echo $! >"$T/serve-us.pid" )
for _ in $(seq 1 30); do grep -q "open:" "$T/serve-us.out" && break; sleep 0.1; done
USURL="$(grep -o "http://127.0.0.1:[0-9]*/[^ ]*" "$T/serve-us.out" | head -1)"
check "userscript --serve: a random URL path" '[[ "$USURL" =~ ^http://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_-]{12,}/nowplaying-bridge\.user\.js$ ]]'
check "userscript --serve: the guessable path is 404" '[[ "$(curl -s -o /dev/null -w "%{http_code}" "${USURL%%/*/*}/nowplaying-bridge.user.js" 2>/dev/null; curl -s -o /dev/null -w "%{http_code}" "$(sed -E "s#^(http://[^/]+)/.*#\1#" <<<"$USURL")/nowplaying-bridge.user.js")" == *404 ]]'
check "userscript --serve: the real URL serves it" 'curl -s "$USURL" | grep -qF "$TOKEN"'
kill "$(cat "$T/serve-us.pid")" 2>/dev/null
check "userscript JS parses"        'node --check "$US" 2>/dev/null || node -e "new Function(require(\"fs\").readFileSync(process.argv[1],\"utf8\"))" "$US"'

# a stand-in for yt-dlp: no network. Logs its URL, sleeps $FAKE_SLEEP, writes a fake mp4 where -o says (FAKE_FAIL=1: exit 1)
cat >"$T/fake-ytdlp" <<'FAKE'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do [[ "$prev" == -o ]] && out="$a"; prev="$a"; done
echo "${@: -1}" >>"$FAKE_LOG"
sleep "${FAKE_SLEEP:-0.2}"
[[ "${FAKE_FAIL:-0}" == 1 ]] && { echo "ERROR: [youtube] fake failure" >&2; exit 1; }
f="${out//%(ext)s/mp4}"
{ printf '\x00\x00\x00\x18ftypisom\x00\x00\x02\x00isomiso2'; head -c 2048 /dev/zero; } >"$f"
FAKE
chmod +x "$T/fake-ytdlp"
export HYPR_NOWPLAYING_YTDLP="$T/fake-ytdlp" FAKE_LOG="$T/fake.log" FAKE_SLEEP=0.2
: >"$FAKE_LOG"

# ------------------------------------------------------------------ the server
start --cache-mb 1 --max-min 20 || { bad "server starts" "$(cat "$T/serve.log")"; }
check "server answers /ping with the token" '[[ "$(curl -s -H "X-Hypr-Nowplaying-Token: $TOKEN" "$URL/ping" | jq -r .ok)" == true ]]'
check "state.json written at start"  '[[ "$(state .server.port)" == "$PORT" && "$(state .bridge)" == null ]]'
check "pid file"                     '[[ "$(cat "$T/run/serve.pid")" == "$SPID" ]]'
check "listens on 127.0.0.1 only"    'ss -ltnH "sport = :$PORT" | awk "{print \$4}" | grep -qx "127.0.0.1:$PORT"'
check "second instance exits 3 (after a 3 s grace)" '"$NP" serve --keep >/dev/null 2>&1; [[ $? -eq 3 ]]'
check "status shows it running"      '"$NP" status | grep -q "serving on 127.0.0.1:$PORT"'

YT='{"tab":"tabA1","site":"youtube","pageUrl":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","videoId":"dQw4w9WgXcQ","title":"Never Gonna","author":"Rick","thumbnail":"https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg","position":12.5,"duration":3600,"paused":false,"rate":1,"live":false,"isVideo":true,"ad":false,"width":854,"height":480,"visible":true,"ts":1}'
check "no token -> 403"              '[[ "$(post /state "$YT" "" | cut -d" " -f1)" == 403 ]]'
check "wrong token -> 403"           '[[ "$(post /state "$YT" "nope-nope-nope-nope-nope" | cut -d" " -f1)" == 403 ]]'
check "GET without token -> 403"     '[[ "$(curl -s -o /dev/null -w "%{http_code}" "$URL/ping")" == 403 ]]'
check "foreign Host header -> 403"   '[[ "$(curl -s -o /dev/null -w "%{http_code}" -H "Host: evil.example:$PORT" -H "X-Hypr-Nowplaying-Token: $TOKEN" "$URL/ping")" == 403 ]]'
check "OPTIONS (CORS preflight) -> 403" '[[ "$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "$URL/state")" == 403 ]]'
check "bad JSON -> 400"              '[[ "$(post /state "{nope" | cut -d" " -f1)" == 400 ]]'
check "unknown site -> 400"          '[[ "$(post /state "$(jq -c ".site=\"vimeo\"" <<<"$YT")" | cut -d" " -f1)" == 400 ]]'
check "huge body -> 400"             '[[ "$(post /state "$(jq -c ".title=\"$(head -c 40000 /dev/zero | tr "\0" a)\"" <<<"$YT")" | cut -d" " -f1)" == 400 ]]'

# a 60 min video: longer than --max-min 20 -> skipped, no yt-dlp run
R="$(post /state "$YT")"
check "good state -> 200"            '[[ "${R%% *}" == 200 ]]'
check "youtube never asks the browser for bytes" '[[ "$(jq -r .wantVideo <<<"${R#* }")" == false ]]'
check "state.json has the bridge"    '[[ "$(state .bridge.videoId)" == dQw4w9WgXcQ && "$(state .bridge.title)" == "Never Gonna" ]]'
check "received stamped"             '[[ "$(state .bridge.received)" -gt 1000000000000 ]]'
check "too long -> skipped"          '[[ "$(state .videoStatus)" == skipped ]]'
check "state.json is 0600"           '[[ "$(stat -c %a "$T/run/state.json")" == 600 ]]'
INODE="$(stat -c %i "$T/run/state.json")"
post /state "$(jq -c '.position=13.5' <<<"$YT")" >/dev/null
check "rewritten in place (same inode)" '[[ "$(stat -c %i "$T/run/state.json")" == "$INODE" && "$(state .bridge.position)" == 13.5 ]]'

# sanitising
post /state "$(jq -c '.thumbnail="https://evil.example/x.jpg" | .pageUrl="javascript:alert(1)" | .title="a\u0007b" | .rate=99 | .position=-5' <<<"$YT")" >/dev/null
check "foreign thumbnail host dropped" '[[ "$(state .bridge.thumbnail)" == "" ]]'
check "non-https page URL dropped"   '[[ "$(state .bridge.pageUrl)" == "" ]]'
check "control chars stripped"       '[[ "$(state .bridge.title)" == "ab" ]]'
check "rate and position clamped"    '[[ "$(state ".bridge.rate == 16 and .bridge.position == 0")" == true ]]'
post /state "$(jq -c '.videoId="../../etc"' <<<"$YT")" >/dev/null
check "bad video id dropped"         '[[ "$(state .bridge.videoId)" == "" && "$(state .bridge.key)" == "" ]]'

# buffering passes through
post /state "$(jq -c '.buffering=true' <<<"$YT")" >/dev/null
check "buffering passed through"     '[[ "$(state .bridge.buffering)" == true ]]'

# tab selection: a playing tab beats a paused one; the newest playing wins
post /state "$(jq -c '.tab="tabB2" | .paused=true | .title="Paused one"' <<<"$YT")" >/dev/null
check "playing tab beats paused tab" '[[ "$(state .bridge.tab)" == tabA1 ]]'
post /state "$(jq -c '.tab="tabC3" | .title="Newer"' <<<"$YT")" >/dev/null
check "newest playing tab wins"      '[[ "$(state .bridge.tab)" == tabC3 ]]'
post /state '{"tab":"tabC3","gone":true}' >/dev/null
post /state '{"tab":"tabA1","gone":true}' >/dev/null
check "gone removes the tab"         '[[ "$(state .bridge.tab)" == tabB2 && "$(state .bridge.paused)" == true ]]'
post /state "$(jq -c '.tab="tabD4"' <<<"$YT")" >/dev/null
sleep 6.5
check "silent playing tab expires (5 s)" '[[ "$(state .bridge.tab)" == tabB2 ]]'

# ------------------------------------------------------------------ TikTok upload path
TT='{"tab":"tabT1","site":"tiktok","pageUrl":"https://www.tiktok.com/@someone/video/7312345678901234567","videoId":"7312345678901234567","title":"a dance","author":"someone","thumbnail":"https://p16-sign-va.tiktokcdn.com/obj/x.jpeg","position":3,"duration":15,"paused":false,"rate":1,"live":false,"isVideo":true,"ad":false,"width":576,"height":1024,"visible":true,"ts":1}'
fake_mp4 "$T/up.mp4" 300
upload() { curl -s -o "$T/body" -w '%{http_code}' -X POST -H "X-Hypr-Nowplaying-Token: ${3:-$TOKEN}" -H 'Content-Type: video/mp4' --data-binary @"$2" "$URL/video/$1"; }
check "upload before it was asked -> 409" '[[ "$(upload tiktok-7312345678901234567 "$T/up.mp4")" == 409 ]]'
R="$(post /state "$TT")"
check "tiktok: daemon asks for the video" '[[ "$(jq -r .wantVideo <<<"${R#* }")" == true && "$(jq -r .key <<<"${R#* }")" == tiktok-7312345678901234567 ]]'
check "status fetching while waiting"     '[[ "$(state .videoStatus)" == fetching ]]'
check "thumbnail on tiktokcdn kept"       '[[ "$(state .bridge.thumbnail)" == https://p16-sign-va.tiktokcdn.com/obj/x.jpeg ]]'
check "upload with a bad token -> 403"    '[[ "$(upload tiktok-7312345678901234567 "$T/up.mp4" bad-token-bad-token)" == 403 ]]'
check "upload to a bad key -> 400"        '[[ "$(upload youtube-dQw4w9WgXcQ "$T/up.mp4")" == 400 ]]'
head -c 5000 /dev/urandom >"$T/junk.bin"
check "junk bytes refused (not a video)"  '[[ "$(upload tiktok-7312345678901234567 "$T/junk.bin")" == 400 && "$(state .videoStatus)" == failed ]]'
check "no junk left in the cache"         '! ls "$T/cache" | grep -q "^tiktok-"'
post /state '{"tab":"tabT1","gone":true}' >/dev/null
TT2="$(jq -c '.tab="tabT2" | .videoId="7399999999999999999" | .pageUrl="https://www.tiktok.com/@someone/video/7399999999999999999"' <<<"$TT")"
R="$(post /state "$TT2")"
check "second tiktok asked for"          '[[ "$(jq -r .wantVideo <<<"${R#* }")" == true ]]'
check "a real upload is accepted"        '[[ "$(upload tiktok-7399999999999999999 "$T/up.mp4")" == 200 ]]'
check "videoStatus ready + videoFile"     '[[ "$(state .videoStatus)" == ready && "$(state .videoFile)" == "$T/cache/tiktok-7399999999999999999.mp4" ]]'
R="$(post /state "$TT2")"
check "not asked again once cached"      '[[ "$(jq -r .wantVideo <<<"${R#* }")" == false ]]'
TT3="$(jq -c '.tab="tabT3" | .videoId="7388888888888888888"' <<<"$TT")"
post /state "$TT3" >/dev/null
check "video-error marks it failed"      '[[ "$(post /video-error/tiktok-7388888888888888888 "{\"reason\":\"blob only\"}" | cut -d" " -f1)" == 200 && "$(state ".videos[\"tiktok-7388888888888888888\"].status")" == failed && "$(state ".videos[\"tiktok-7388888888888888888\"].reason")" == "blob only" ]]'
R="$(post /state "$TT3")"
check "a failed key is not asked again at once" '[[ "$(jq -r .wantVideo <<<"${R#* }")" == false ]]'
TT4="$(jq -c '.tab="tabT4" | .videoId="7377777777777777777" | .live=true' <<<"$TT")"
R="$(post /state "$TT4")"
check "live tiktok is not asked for"     '[[ "$(jq -r .wantVideo <<<"${R#* }")" == false && "$(state .videoStatus)" == skipped ]]'

# ------------------------------------------------------------------ oversize upload (restart with a tiny cap)
stop
start --cache-mb 1 --upload-mb 0.1 || bad "server restarts"
post /state "$(jq -c '.tab="tabT5" | .videoId="7366666666666666666"' <<<"$TT")" >/dev/null
check "oversize upload -> 413, failed"   '[[ "$(upload tiktok-7366666666666666666 "$T/up.mp4")" == 413 && "$(state .videoStatus)" == failed ]]'

# ------------------------------------------------------------------ LRU (cap 1 MB)
stop
rm -f "$T"/cache/*.mp4
for i in 1 2 3; do fake_mp4 "$T/cache/tiktok-711111111111111111$i.mp4" 400; touch -d "-$((10 - i)) min" "$T/cache/tiktok-711111111111111111$i.mp4"; done
start --cache-mb 1 || bad "server restarts (lru)"
check "start-up prune keeps the cache <= cap" '[[ $(du -cb "$T"/cache/*.mp4 | tail -1 | cut -f1) -le 1048576 ]]'
check "the oldest went first"            '[[ ! -e "$T/cache/tiktok-7111111111111111111.mp4" && -e "$T/cache/tiktok-7111111111111111113.mp4" ]]'
post /state "$(jq -c '.tab="tabL1" | .videoId="7355555555555555555"' <<<"$TT")" >/dev/null
fake_mp4 "$T/new.mp4" 500
check "upload after LRU"                 '[[ "$(upload tiktok-7355555555555555555 "$T/new.mp4")" == 200 ]]'
check "new file kept, total <= cap"      '[[ -e "$T/cache/tiktok-7355555555555555555.mp4" && $(du -cb "$T"/cache/*.mp4 | tail -1 | cut -f1) -le 1048576 ]]'
check "cache list shows it"              '"$NP" cache list | grep -q tiktok-7355555555555555555'

# ------------------------------------------------------------------ the yt-dlp worker (fake yt-dlp)
waitst() { for _ in $(seq 1 60); do [[ "$(state ".videos[\"$1\"].status")" == "$2" ]] && return 0; sleep 0.1; done; return 1; }
check "want: not an id -> exit 2"        '"$NP" want "https://evil.example/watch?v=dQw4w9WgXcQ" >/dev/null 2>&1; [[ $? -eq 2 ]]'
check "want: url parsed"                 '"$NP" want "https://youtu.be/dQw4w9WgXcQ?t=3" | grep -q "youtube-dQw4w9WgXcQ"'
check "fetch -> ready"                   'waitst youtube-dQw4w9WgXcQ ready && [[ -s "$T/cache/youtube-dQw4w9WgXcQ.mp4" ]]'
check "yt-dlp got the canonical URL"     'grep -qx "https://www.youtube.com/watch?v=dQw4w9WgXcQ" "$FAKE_LOG"'
post /state "$(jq -c '.tab="tabY1" | .duration=200' <<<"$YT")" >/dev/null
check "bridge on a cached id -> ready at once" '[[ "$(state .videoStatus)" == ready && "$(state .videoFile)" == "$T/cache/youtube-dQw4w9WgXcQ.mp4" ]]'
check "no second download of a cached id" '[[ "$(grep -c dQw4w9WgXcQ "$FAKE_LOG")" == 1 ]]'
check "no work dirs left"                '! ls -a "$T/cache" | grep -q "^.ytdlp-"'
stop; FAKE_SLEEP=3 start --cache-mb 1 || bad "server restarts (worker)"
"$NP" want aaaaaaaaaaa >/dev/null; sleep 0.5; "$NP" want bbbbbbbbbbb >/dev/null
check "newest request wins"              'waitst youtube-bbbbbbbbbbb ready'
check "the superseded job left nothing"  '[[ ! -e "$T/cache/youtube-aaaaaaaaaaa.mp4" && "$(state ".videos[\"youtube-aaaaaaaaaaa\"]")" == null ]]'
stop; FAKE_FAIL=1 start --cache-mb 1 || bad "server restarts (fail)"
"$NP" want ccccccccccc >/dev/null
check "yt-dlp failure -> failed + reason" 'waitst youtube-ccccccccccc failed && [[ "$(state ".videos[\"youtube-ccccccccccc\"].reason")" == "ERROR: [youtube] fake failure" ]]'
n="$(wc -l <"$FAKE_LOG")"; "$NP" want ccccccccccc >/dev/null; sleep 0.5
check "a failed id is not retried at once" '[[ "$(wc -l <"$FAKE_LOG")" == "$n" ]]'
# a report that first says "too long" (soft skip) and then the real, short duration: fetched after all
stop; FAKE_FAIL=0 start --cache-mb 1 || bad "server restarts (soft skip)"
SK="$(jq -c '.tab="tabK1" | .videoId="ddddddddddd" | .duration=7200' <<<"$YT")"
post /state "$SK" >/dev/null
check "too long in one report -> skipped (soft)" '[[ "$(state ".videos[\"youtube-ddddddddddd\"].status")" == skipped ]]'
post /state "$(jq -c '.duration=95' <<<"$SK")" >/dev/null
check "the next report with the real length fetches it" 'waitst youtube-ddddddddddd ready'
# the worker survives an exception (cache dir made unwritable mid-run)
chmod 500 "$T/cache"; "$NP" want eeeeeeeeeee >/dev/null
check "worker error -> failed, not stuck fetching" 'waitst youtube-eeeeeeeeeee failed'
chmod 700 "$T/cache"; "$NP" want fffffffffff >/dev/null
check "the worker still runs afterwards" 'waitst youtube-fffffffffff ready'
check "status --json running"            '[[ "$("$NP" status --json | jq -r .running)" == true ]]'

# ------------------------------------------------------------------ restarts and yt-dlp's life
OLD=$SPID; kill "$OLD"; SPID=""                      # no wait: the new one starts while the old one is still exiting
start --cache-mb 1 || bad "restart overlapping the old instance"
check "a restart overlapping the old one gets the lock" '[[ -n "$SPID" ]] && kill -0 "$SPID" && curl -s -o /dev/null -H "X-Hypr-Nowplaying-Token: $TOKEN" "$URL/ping"'
wait "$OLD" 2>/dev/null
stop; FAKE_SLEEP=30 start --cache-mb 1 || bad "server restarts (long fetch)"
"$NP" want ggggggggggg >/dev/null; sleep 1
FPID="$(pgrep -f "fake-ytdlp.*ggggggggggg" | head -1)"
check "a long fetch is running"      '[[ -n "$FPID" ]]'
kill -9 "$SPID"; wait "$SPID" 2>/dev/null; SPID=""; sleep 1
check "yt-dlp dies with a SIGKILLed daemon (pdeathsig)" '! grep -qs "^State:[[:space:]]*[^Z]" "/proc/$FPID/status"'   # gone, or a zombie waiting to be reaped
FAKE_SLEEP=0.2 start --cache-mb 1 || bad "server restarts after SIGKILL"

# ------------------------------------------------------------------ TikTok actions: stdin -> per-tab queue -> /state reply -> result
stop
mkfifo "$T/ctl"
"$NP" serve --keep --stdin <"$T/ctl" >"$T/serve.log" 2>&1 &
SPID=$!
exec 7>"$T/ctl"                                      # hold the write end open (EOF = the shell is gone = exit)
for _ in $(seq 1 50); do curl -s -o /dev/null "$URL/ping" && break; sleep 0.1; done
ctl() { printf '%s\n' "$1" >&7; sleep 0.3; }
reply() { local r; r="$(post /state "$1")"; printf '%s' "${r#* }"; }
CLIP=7411111111111111111
TA="$(jq -c --arg c "$CLIP" '.tab="tabX1" | .videoId=$c | .pageUrl="https://www.tiktok.com/@someone/video/"+$c | .tt={bar:true, clip:$c, liked:false, saved:false, reposted:null}' <<<"$TT")"
act() { jq -nc --arg t "${2:-tabX1}" --arg k "${3:-tiktok-$CLIP}" --arg a "$1" '{cmd:"action", tab:$t, key:$k, action:$a, collection:"Edits"}'; }
R="$(reply "$(jq -c '.tt={bar:true, clip:"'$CLIP'", liked:false, saved:"yes", reposted:null, busy:"hack", last:{id:"x"}, extra:1}' <<<"$TA")")"
check "tt: state sanitised"              '[[ "$(jq -c .bridge.tt "$T/run/state.json")" == "{\"bar\":true,\"clip\":\"$CLIP\",\"liked\":false,\"saved\":null,\"reposted\":null,\"busy\":\"\",\"last\":null}" ]]'
check "tiktok reply asks for the heartbeat (poll)" '[[ "$(jq -r .poll <<<"$R")" == true && "$(jq -c .actions <<<"$R")" == "[]" ]]'
reply "$(jq -c '.tt.clip="7499999999999999999"' <<<"$TA")" >/dev/null
check "tt: the action bar of another clip -> no state, no buttons" '[[ "$(state .bridge.tt.bar)" == false && "$(state .bridge.tt.liked)" == null ]]'
reply "$(jq -c '.tt.clip="../../x" | .tt.liked=1' <<<"$TA")" >/dev/null
check "tt: bad clip id and non-bool flags dropped" '[[ "$(state .bridge.tt.clip)" == "" && "$(state .bridge.tt.bar)" == false && "$(state .bridge.tt.liked)" == null ]]'
R="$(reply "$(jq -c '.tab="tabY9" | .tt={bar:true}' <<<"$YT")")"
check "youtube: no tt, no poll"          '[[ "$(jq -r .poll <<<"$R")" == false && "$(state .bridge.tab)" == tabY9 && "$(state .bridge.tt)" == null ]]'
post /state '{"tab":"tabY9","gone":true}' >/dev/null
reply "$TA" >/dev/null
ctl "$(act like)"
check "action queued (state.action)"     '[[ "$(state .action.status)" == queued && "$(state .action.action)" == like && "$(state .action.key)" == "tiktok-$CLIP" && "$(state .action.tab)" == tabX1 ]]'
ID1="$(state .action.id)"
ctl "$(act like)"; ctl "$(act save)"
check "a second press while one is queued is ignored" '[[ "$(state .action.id)" == "$ID1" && "$(state .action.action)" == like ]]'
check "a bad token gets nothing (still queued)" '[[ "$(post /state "$TA" bad-token-bad-token | cut -d" " -f1)" == 403 && "$(state .action.status)" == queued ]]'
R="$(reply "$TA")"
check "delivered in the /state reply"    '[[ "$(jq -c ".actions" <<<"$R")" == "[{\"id\":$ID1,\"key\":\"tiktok-$CLIP\",\"action\":\"like\",\"collection\":\"Edits\"}]" && "$(state .action.status)" == sent ]]'
R="$(reply "$TA")"
check "delivered once only"              '[[ "$(jq -c .actions <<<"$R")" == "[]" && "$(state .action.status)" == sent ]]'
ctl "$(act repost)"
check "still busy while sent: another action ignored" '[[ "$(state .action.id)" == "$ID1" ]]'
reply "$(jq -c --argjson i "$ID1" '.tt.liked=true | .tt.last={id:$i, action:"like", ok:true, error:""}' <<<"$TA")" >/dev/null
check "result ok -> done, liked state passed through" '[[ "$(state .action.status)" == done && "$(state .bridge.tt.liked)" == true && "$(state .bridge.tt.last.id)" == "$ID1" ]]'
ctl "$(act repost)"; ID2="$(state .action.id)"
R="$(reply "$TA")"
reply "$(jq -c --argjson i "$ID2" '.tt.last={id:$i, action:"repost", ok:false, error:"the share panel has no Repost button\u0007"}' <<<"$TA")" >/dev/null
check "result failed -> failed + error (cleaned)" '[[ "$ID2" -gt "$ID1" && "$(state .action.status)" == failed && "$(state .action.error)" == "the share panel has no Repost button" ]]'
ctl "$(act delete)"
check "bad action refused"               '[[ "$(state .action.status)" == refused && "$(state .action.error)" == *"unknown action"* && "$(state .action.action)" == "" ]]'
ctl "$(act like tabZZ9)"
check "unknown tab refused"              '[[ "$(state .action.status)" == refused && "$(state .action.error)" == *"gone"* ]]'
ctl "$(act like tabX1 tiktok-7422222222222222222)"
check "a clip the tab does not show refused" '[[ "$(state .action.status)" == refused && "$(state .action.error)" == *"another clip"* ]]'
ctl "$(act like tabX1 youtube-dQw4w9WgXcQ)"
check "a YouTube key refused"            '[[ "$(state .action.status)" == refused && "$(state .action.error)" == *"TikTok"* ]]'
check "actions are not accepted over HTTP" '[[ "$(post /want "$(act like)" | cut -d" " -f1)" == 400 && "$(state .action.status)" == refused ]]'
ctl "$(act save)"
reply "$(jq -c '.videoId="7433333333333333333" | .tt.clip="7433333333333333333"' <<<"$TA")" >/dev/null
check "the clip changed before delivery -> failed, not sent" '[[ "$(state .action.status)" == failed && "$(state .action.error)" == *"clip changed"* ]]'
reply "$TA" >/dev/null; ctl "$(act like)"
post /state '{"tab":"tabX1","gone":true}' >/dev/null
check "the tab closed -> failed"         '[[ "$(state .action.status)" == failed && "$(state .action.error)" == *"closed"* ]]'
reply "$(jq -c '.paused=true' <<<"$TA")" >/dev/null; ctl "$(act like)"
check "status shows the action"          '"$NP" status | grep -q "action:  like tiktok-$CLIP queued" && "$NP" status | grep -q "tiktok:  liked no, saved no, reposted ?"'
sleep 10.6
check "not picked up in 10 s -> expired" '[[ "$(state .action.status)" == expired && "$(state .action.error)" == *"did not pick it up"* ]]'
R="$(reply "$(jq -c '.paused=true' <<<"$TA")")"
check "an expired command is never delivered" '[[ "$(jq -c .actions <<<"$R")" == "[]" ]]'
exec 7>&-
for _ in $(seq 1 30); do kill -0 "$SPID" 2>/dev/null || break; sleep 0.1; done
check "stdin closed -> it exits, state says stopped (action null)" '! kill -0 "$SPID" 2>/dev/null && [[ "$(state .server)" == null && "$(state .action)" == null ]]'
wait "$SPID" 2>/dev/null; SPID=""
FAKE_SLEEP=0.2 start --cache-mb 1 || bad "server restarts after the actions"

# ------------------------------------------------------------------ SIGTERM: clean exit, state says stopped
kill "$SPID"; wait "$SPID" 2>/dev/null; SPID=""
check "stopped state written on exit"    '[[ "$(state .server)" == null && ! -e "$T/run/serve.pid" ]]'
check "cache clear"                      '"$NP" cache clear | grep -q removed && ! ls "$T/cache"/*.mp4 >/dev/null 2>&1'

# ------------------------------------------------------------------ --stdin: EOF = exit (the shell is gone); death with the parent
( sleep 1.5 ) | "$NP" serve --keep --stdin >/dev/null 2>&1 &
P=$!
sleep 0.8; check "--stdin server runs"   'kill -0 $P 2>/dev/null'
sleep 1.6; check "--stdin EOF -> it exits" '! kill -0 $P 2>/dev/null'
wait $P 2>/dev/null
bash -c '"$0" serve >/dev/null 2>&1 & echo $! >"$1/child.pid"; sleep 1' "$NP" "$T" &
sleep 2.2
CP="$(cat "$T/child.pid")"
check "PR_SET_PDEATHSIG: dies with its parent" '! kill -0 "$CP" 2>/dev/null'

# ------------------------------------------------------------------ optional: a real YouTube fetch (network)
if [[ "${NP_REAL:-0}" == 1 ]]; then
    unset HYPR_NOWPLAYING_YTDLP           # the real yt-dlp this time
    start --cache-mb 400 --max-min 20 -v || bad "server starts (real)"
    VID="${NP_REAL_ID:-jNQXAC9IVRw}"          # "Me at the zoo", 19 s
    "$NP" want "$VID" >/dev/null
    for _ in $(seq 1 120); do
        st="$(state ".videos[\"youtube-$VID\"].status")"
        [[ "$st" == ready || "$st" == failed || "$st" == skipped ]] && break
        sleep 1
    done
    check "real fetch ready"             '[[ "$(state ".videos[\"youtube-$VID\"].status")" == ready ]]'
    F="$(state ".videos[\"youtube-$VID\"].file")"
    if [[ -s "$F" ]]; then
        P="$(ffprobe -v error -show_entries stream=codec_type,codec_name,height -of json "$F")"
        echo "  ffprobe: $(jq -c '[.streams[] | {codec_type, codec_name, height}]' <<<"$P")  $(du -h "$F" | cut -f1)"
        check "video only (no audio stream)" '[[ "$(jq "[.streams[] | select(.codec_type==\"audio\")] | length" <<<"$P")" == 0 ]]'
        check "<= 480p"                  '[[ "$(jq "[.streams[] | select(.codec_type==\"video\") | .height] | max" <<<"$P")" -le 480 ]]'
        check "decodes (ffmpeg -f null)" 'ffmpeg -v error -nostdin -i "$F" -f null - 2>&1 | wc -l | grep -qx 0'
        [[ -n "${NP_KEEP:-}" ]] && cp "$F" "$NP_KEEP" && echo "  kept a copy in $NP_KEEP"
    fi
    stop
fi

echo "----"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
