#!/usr/bin/env bash
# tests/nowplaying-service.test.sh — NowPlayingService + IPC target `nowplaying` in a private offscreen qs instance, with the real
# daemon as its child on a random port; temp state, runtime, cache, token and config. Fake browser reports through curl.
# Reads the real MPRIS players (read-only; OW_NOWPLAYING_DRYRUN=1 makes every control a log line). Never touches the live shell.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
QML="$REPO/quickshell/NowPlaying/preview/service-test.qml"
T="$(mktemp -d /tmp/np-svc.XXXXXX)"
PORT=$(( 20000 + RANDOM % 20000 ))
export OW_NOWPLAYING_STATE="$T/np.json" HYPR_NOWPLAYING_RUNTIME="$T/run" HYPR_NOWPLAYING_CACHE="$T/cache" HYPR_NOWPLAYING_DATA="$T/data"
export OW_CONFIG="$T/config.json" OW_NOWPLAYING_DRYRUN=1 QT_QPA_PLATFORM=offscreen
export OW_NOWPLAYING_NOMPRIS="${NP_WITH_MPRIS:-1}"   # deterministic: the bridge alone; NP_WITH_MPRIS=0 also merges the real players
echo "{\"nowplaying\": {\"port\": $PORT, \"autoHideSec\": 3, \"tiktokCollection\": \"Recipes\"}}" >"$OW_CONFIG"
pass=0; fail=0
det() { if [[ "$OW_NOWPLAYING_NOMPRIS" == 1 ]]; then check "$@"; else echo "SKIP $1 (a playing real player wins, by design)"; fi; }
check() { if eval "$2"; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1  [$2]"; fi; }
QPID=""
cleanup() { [[ -n "$QPID" ]] && kill "$QPID" 2>/dev/null; wait 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
ipc() { timeout 5 qs -p "$QML" ipc call nowplaying "$@" 2>/dev/null; }
last() { grep -a "STATE " "$T/qs.log" | tail -1 | sed 's/.*STATE //' | jq -r "$1"; }
waitfor() { for _ in $(seq 1 ${3:-40}); do [[ "$(last "$1")" == "$2" ]] && return 0; sleep 0.25; done; return 1; }

# a real portrait clip (the mirror file a TikTok upload would be)
SRC="${NP_SAMPLE:-$HOME/.hermes/cache/scratch/np/zoo.mp4}"
if [[ -s "$SRC" ]]; then ffmpeg -v error -nostdin -y -i "$SRC" -t 3 -an -vf "crop=135:240:100:0,scale=270:480" -c:v libx264 -pix_fmt yuv420p "$T/portrait.mp4"
else ffmpeg -v error -nostdin -y -f lavfi -i testsrc2=s=270x480:d=3 -c:v libx264 -pix_fmt yuv420p "$T/portrait.mp4"; fi

qs -p "$QML" >"$T/qs.log" 2>&1 &
QPID=$!
sleep 3
check "starts OFF"                      '[[ "$(last .on)" == false && "$(last .daemon)" == false ]]'
check "ipc status answers"              'ipc status | grep -q "^off"'
check "no daemon while off"             '[[ ! -e "$T/run/serve.pid" ]]'
check "ipc on"                          '[[ "$(ipc on)" == on ]]'
check "on persisted"                    'sleep 0.5; [[ "$(jq -r .on "$T/np.json")" == true ]]'
check "daemon started as a child"       'waitfor .daemon true && for _ in $(seq 1 20); do [[ -s "$T/run/serve.pid" ]] && break; sleep 0.25; done; [[ -s "$T/run/serve.pid" ]]'
DPID="$(cat "$T/run/serve.pid" 2>/dev/null)"
check "daemon parent is the shell"      '[[ "$(ps -o ppid= -p "$DPID" | tr -d " ")" == "$QPID" ]]'
check "daemon on the configured port"   'ss -ltnH "sport = :$PORT" | grep -q "127.0.0.1:$PORT"'
TOKEN="$(cat "$T/data/token")"
post() { curl -s -X POST -H "X-Hypr-Nowplaying-Token: $TOKEN" -H "Content-Type: ${3:-application/json}" --data-binary "$2" "http://127.0.0.1:$PORT$1"; }
TT='{"tab":"tabS1","site":"tiktok","pageUrl":"https://www.tiktok.com/@blocky.builds/video/7412345678901234567","videoId":"7412345678901234567","title":"pov: you beat the dragon","author":"blocky.builds","thumbnail":"https://p16-sign-va.tiktokcdn.com/obj/x.jpeg","position":1.5,"duration":3,"paused":false,"rate":1,"live":false,"isVideo":true,"ad":false,"width":0,"height":0,"visible":true}'
R="$(post /state "$(jq -c ".ts=$(date +%s%3N)" <<<"$TT")")"
check "daemon asks for the TikTok file" '[[ "$(jq -r .wantVideo <<<"$R")" == true ]]'
check "bridge shown: TikTok, title"     'waitfor .kind bridge && [[ "$(last .site)" == tiktok && "$(last .title)" == "pov: you beat the dragon" && "$(last .artist)" == blocky.builds ]]'
check "TikTok = portrait before the file" '[[ "$(last .aspect)" == 0.563 ]]'
check "shown while playing"             '[[ "$(last .shown)" == true ]]'
check "videoStatus fetching"            '[[ "$(last .videoStatus)" == fetching ]]'
post /video/tiktok-7412345678901234567 @"$T/portrait.mp4" video/mp4 >/dev/null
post /state "$(jq -c ".ts=$(date +%s%3N) | .position=2" <<<"$TT")" >/dev/null
check "upload -> videoFile ready"       'waitfor .videoFile "$T/cache/tiktok-7412345678901234567.mp4" && [[ "$(last .videoStatus)" == ready ]]'
check "aspect from the real file (270x480)" '[[ "$(last .aspect)" == 0.563 ]]'
check "position extrapolated"           '[[ "$(last ".pos >= 2")" == true ]]'

# ------------------------------------------------------------------ TikTok like / repost / save: PiP button -> stdin -> daemon -> tab -> state
nptest() { timeout 5 qs -p "$QML" ipc call nptest act "$1" 2>/dev/null; }
dstate() { jq -r "$1" "$T/run/state.json" 2>/dev/null; }
TTS="$(jq -c '.tt={bar:true, clip:"7412345678901234567", liked:false, saved:true, reposted:null}' <<<"$TT")"
ttpost() { post /state "$(jq -c ".ts=$(date +%s%3N) | .position=${2:-2.1}" <<<"$1")"; }
check "a report without tt -> no buttons"   '[[ "$(last .canLike)" == false && "$(last .liked)" == null ]]'
check "a press without buttons is refused"  '[[ "$(nptest like)" == refused ]]'
ttpost "$TTS" >/dev/null
check "tt -> buttons + their state"         'waitfor .canLike true && [[ "$(last .liked)" == false && "$(last .saved)" == true && "$(last .reposted)" == null && "$(last .busy)" == "" ]]'
check "press like -> written to the daemon" '[[ "$(nptest like)" == sent ]]'
check "the command went out on stdin (queued in the daemon)" 'for _ in $(seq 1 20); do [[ "$(dstate .action.status)" == queued ]] && break; sleep 0.1; done; [[ "$(dstate ".action | \"\(.action) \(.key) \(.tab)\"")" == "like tiktok-7412345678901234567 tabS1" ]]'
check "busy while queued"                   'waitfor .busy like'
check "a second press while busy is refused" '[[ "$(nptest save)" == refused && "$(dstate .action.action)" == like ]]'
R="$(ttpost "$TTS" 2.2)"
AID="$(jq -r ".actions[0].id" <<<"$R")"
check "the tab gets it in its /state reply, collection from config" '[[ "$(jq -c ".actions[0] | [.action, .key, .collection]" <<<"$R")" == "[\"like\",\"tiktok-7412345678901234567\",\"Recipes\"]" ]]'
check "still busy while the tab runs it"    'sleep 0.4; [[ "$(last .busy)" == like ]]'
ttpost "$(jq -c --argjson i "$AID" '.tt.liked=true | .tt.last={id:$i, action:"like", ok:true, error:""}' <<<"$TTS")" 2.3 >/dev/null
check "result -> liked, not busy, no error" 'waitfor .liked true && [[ "$(last .busy)" == "" && "$(last .actErr)" == "" ]]'
check "status line has the TikTok state"    'ipc status | grep -q "TikTok liked saved ? reposted"'
nptest save >/dev/null; sleep 0.3
R="$(ttpost "$(jq -c '.tt.liked=true' <<<"$TTS")" 2.4)"
AID="$(jq -r ".actions[0].id" <<<"$R")"
ttpost "$(jq -c --argjson i "$AID" '.tt.liked=true | .tt.last={id:$i, action:"save", ok:false, error:"saved to Favorites only: no collection named \"Recipes\""}' <<<"$TTS")" 2.5 >/dev/null
check "a failed save shows its reason (fresh)" 'waitfor .actErrFor save && [[ "$(last .actErr)" == "saved to Favorites only: no collection named \"Recipes\"" && "$(last .actErrFresh)" == true && "$(last .busy)" == "" ]]'
check "the action bar of another clip -> buttons hidden" 'ttpost "$(jq -c ".tt.clip=\"7499999999999999999\"" <<<"$TTS")" 2.6 >/dev/null; waitfor .canLike false'
YTS='{"tab":"tabY7","site":"youtube","pageUrl":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","videoId":"dQw4w9WgXcQ","title":"Never Gonna","author":"Rick","position":3,"duration":200,"paused":false,"rate":1,"live":false,"isVideo":false,"ad":false,"visible":true,"tt":{"bar":true,"clip":"7412345678901234567","liked":true}}'
ttpost "$YTS" 3 >/dev/null
check "YouTube (even claiming tt) -> no buttons" 'waitfor .site youtube && [[ "$(last .canLike)" == false && "$(last .liked)" == null ]]'
check "... and a press is refused"          '[[ "$(nptest repost)" == refused ]]'
post /state '{"tab":"tabY7","gone":true}' >/dev/null
ttpost "$TTS" 2.7 >/dev/null
check "back on the TikTok clip -> buttons again" 'waitfor .canLike true'
post /state "$(jq -c ".ts=$(date +%s%3N) | .position=2.4 | .paused=true" <<<"$TT")" >/dev/null
det "paused follows the browser"      'waitfor .paused true && [[ "$(last .shown)" == true && "$(last .pos)" == 2.4 ]]'
det "status line"                     'ipc status | grep -q "TikTok paused: pov: you beat the dragon, video ready"'
check "reset answers"                   'ipc reset | grep -q "reset on"'
check "reveal answers"                  'ipc reveal | grep -q "revealed on"'
post /state '{"tab":"tabS1","gone":true}' >/dev/null
det "tab gone -> nothing, lingering"  'waitfor .kind none && [[ "$(last .lingering)" == true && "$(last .shown)" == true && "$(last .title)" == "pov: you beat the dragon" ]]'
det "auto-hide after autoHideSec (3 s)" 'waitfor .shown false 24 && [[ "$(last .lingering)" == false ]]'
check "ipc reveal shows it idle"        'ipc reveal >/dev/null; waitfor .shown true'
if [[ "$OW_NOWPLAYING_NOMPRIS" != 1 ]]; then sleep 2; echo "  with the real MPRIS players: $(last '"kind=\(.kind) site=\(.site) title=\(.title) key=\(.key) video=\(.videoStatus)"')"; fi
check "ipc off"                         '[[ "$(ipc off)" == off ]]'
check "daemon stopped with off"         'for _ in $(seq 1 20); do kill -0 "$DPID" 2>/dev/null || break; sleep 0.25; done; ! kill -0 "$DPID" 2>/dev/null'
check "off persisted"                   'sleep 0.5; [[ "$(jq -r .on "$T/np.json")" == false ]]'
check "positions kept in the state file" '[[ "$(jq -r ".positions | type" "$T/np.json")" == object ]]'
check "toggle"                          '[[ "$(ipc toggle)" == on && "$(ipc toggle)" == off ]]'
kill "$QPID"; wait "$QPID" 2>/dev/null; QPID=""
check "no daemon left after the shell exits" '! pgrep -f "hypr-nowplaying serve.*--port $PORT" >/dev/null'
echo "--- qs log lines from NowPlaying (warnings/errors):"
grep -a "NowPlaying\|nowplaying" "$T/qs.log" | grep -av "STATE " | grep -aiE "warn|error|typeerror|referenceerror" | head -10 || true
echo "----"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
