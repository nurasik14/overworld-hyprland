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

# no network: a stand-in yt-dlp. Whole files fail (as a made-up id would); --download-sections cuts a 2 h test video like yt-dlp
ffmpeg -v error -nostdin -y -f lavfi -i "testsrc2=s=64x36:r=2:d=7200" -c:v libx264 -g 10 -pix_fmt yuv420p "$T/src2h.mp4"
cat >"$T/fake-ytdlp" <<'FAKE'
#!/usr/bin/env bash
out=""; prev=""; sec=""
for a in "$@"; do [[ "$prev" == -o ]] && out="$a"; [[ "$prev" == --download-sections ]] && sec="${a#\*}"; prev="$a"; done
echo "${sec:+SECTION $sec }${@: -1}" >>"$FAKE_LOG"
[[ -z "$sec" ]] && { echo "ERROR: [youtube] fake: no network in tests" >&2; exit 1; }
sleep 0.3
exec ffmpeg -v error -nostdin -y -ss "${sec%-*}" -t "$(( ${sec#*-} - ${sec%-*} ))" -i "$FAKE_SRC" -c copy "${out//%(ext)s/mp4}"
FAKE
chmod +x "$T/fake-ytdlp"
export HYPR_NOWPLAYING_YTDLP="$T/fake-ytdlp" FAKE_LOG="$T/fake.log" FAKE_SRC="$T/src2h.mp4"
: >"$FAKE_LOG"

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
# ------------------------------------------------------------------ several sources (1.4.0): list, Auto vs pinned, controls routed, release
nptest2() { timeout 5 qs -p "$QML" ipc call nptest "$@" 2>/dev/null; }
( while :; do ttpost "$TTS" 2.8 >/dev/null; sleep 1; done ) & HB=$!          # keep the TikTok tab playing and fresh
det "one source -> one row (the chip stays hidden)" 'waitfor .shownId tab:tabS1 && [[ "$(last .sources)" == "tab:tabS1|TikTok|playing|pov: you beat the dragon" && "$(last .shownIndex)" == 1 ]]'
YB='{"tab":"tabYB","site":"youtube","pageUrl":"https://www.youtube.com/watch?v=bbbbbbbbbbb","videoId":"bbbbbbbbbbb","title":"Second tab song","author":"Band","position":10,"duration":100,"paused":true,"rate":1,"live":false,"isVideo":true,"ad":false,"visible":true,"bv":"1.4.0"}'
YC='{"tab":"tabYC","site":"youtube","pageUrl":"https://www.youtube.com/watch?v=ccccccccccc","videoId":"ccccccccccc","title":"Old bridge tab","author":"Old","position":5,"duration":100,"paused":true,"rate":1,"live":false,"isVideo":true,"ad":false,"visible":true}'
ttpost "$YB" 10 >/dev/null
det "two tabs -> two sources in order, Auto shows the playing one" 'waitfor .sources "tab:tabS1|TikTok|playing|pov: you beat the dragon;tab:tabYB|YouTube|paused|Second tab song" && [[ "$(last .auto)" == true && "$(last .shownId)" == tab:tabS1 && "$(last .shownIndex)" == 1 ]]'
det "ipc sources: auto marked, one line per source, the shown one" 'ipc sources >"$T/src"; head -1 "$T/src" | grep -q "^\* 0 auto   showing 1: TikTok" && grep -q "^  1 TikTok  playing  pov: you beat the dragon — blocky.builds  \[shown\]" "$T/src" && grep -q "^  2 YouTube  paused   Second tab song — Band" "$T/src"'
det "Auto, a TikTok tab with an older bridge and no MPRIS -> no controls (as before)" '[[ "$(last .route)" == none ]]'
det "ipc pick 2 -> pinned, the paused tab is shown" '[[ "$(ipc pick 2)" == "pinned 2/2: YouTube Second tab song" ]] && waitfor .shownId tab:tabYB && [[ "$(last .pinned)" == tab:tabYB && "$(last .auto)" == false && "$(last .title)" == "Second tab song" && "$(last .paused)" == true ]]'
det "the daemon got the pin (its bridge = the pinned tab)" 'for _ in $(seq 1 20); do [[ "$(dstate .pin)" == tabYB ]] && break; sleep 0.1; done; [[ "$(dstate .pin)" == tabYB && "$(dstate .bridge.tab)" == tabYB ]]'
det "status line: source pinned 2/2"  'ipc status | grep -q "source pinned 2/2"'
det "pinned tab, bridge 1.4, no MPRIS following it -> controls go to the tab" '[[ "$(last .route)" == tab && "$(last .canToggle)" == true && "$(last .canNext)" == true ]]'
det "play on the pinned paused tab -> queued for THAT tab" '[[ "$(nptest2 control toggle)" == tab ]] && for _ in $(seq 1 20); do [[ "$(dstate .action.tab)" == tabYB ]] && break; sleep 0.1; done; [[ "$(dstate ".action | \"\(.action) \(.tab) \(.status)\"")" == "play tabYB queued" ]]'
R="$(ttpost "$YB" 10)"; MID="$(jq -r ".actions[0].id" <<<"$R")"
det "... handed to that tab in its reply" '[[ "$(jq -r ".actions[0].action" <<<"$R")" == play ]]'
ttpost "$(jq -c --argjson i "$MID" '.paused=false | .done={id:$i, action:"play", ok:true, error:""}' <<<"$YB")" 10.2 >/dev/null
det "... done, and the PiP follows: playing" 'waitfor .paused false && [[ "$(dstate .action.status)" == done ]]'
nptest2 control next >/dev/null
det "next on the pinned tab -> queued for that tab" 'for _ in $(seq 1 20); do [[ "$(dstate .action.action)" == next ]] && break; sleep 0.1; done; [[ "$(dstate ".action | \"\(.action) \(.tab)\"")" == "next tabYB" ]]'
R="$(ttpost "$(jq -c '.paused=false' <<<"$YB")" 11)"; MID="$(jq -r ".actions[0].id" <<<"$R")"
ttpost "$(jq -c --argjson i "$MID" '.paused=false | .done={id:$i, action:"next", ok:false, error:"the browser refused to start a background tab (autoplay policy): click the tab once"}' <<<"$YB")" 11.2 >/dev/null
det "a refused command shows its reason" 'waitfor .actErrFresh true && [[ "$(last .actErr)" == *autoplay* ]]'
ttpost "$YB" 12 >/dev/null                                                   # paused again (a paused report stays fresh)
ttpost "$YC" 5 >/dev/null
det "a pinned tab with an older bridge -> no controls" 'waitfor .sources "tab:tabS1|TikTok|playing|pov: you beat the dragon;tab:tabYB|YouTube|paused|Second tab song;tab:tabYC|YouTube|paused|Old bridge tab" && ipc pick 3 >/dev/null && waitfor .shownId tab:tabYC && [[ "$(last .route)" == none && "$(last .canToggle)" == false ]]'
det "pick next from the last row -> auto"   '[[ "$(ipc pick next)" == auto* ]] && waitfor .auto true && [[ "$(last .pinned)" == "" && "$(last .shownId)" == tab:tabS1 ]]'
det "pick prev from auto -> the last row"   '[[ "$(ipc pick prev)" == "pinned 3/3"* ]] && waitfor .pinned tab:tabYC'
det "pick next wraps: 3 -> auto -> 1"       'ipc pick next >/dev/null; [[ "$(ipc pick next)" == "pinned 1/3"* ]] && waitfor .pinned tab:tabS1'
det "pick auto, and a bad number is refused" '[[ "$(ipc pick auto)" == auto* && "$(ipc pick 9)" == "no source 9"* ]] && waitfor .auto true'
det "the daemon pin follows Auto (null)"     'for _ in $(seq 1 20); do [[ "$(dstate .pin)" == null ]] && break; sleep 0.1; done; [[ "$(dstate .pin)" == null ]]'
ipc pick 2 >/dev/null; waitfor .pinned tab:tabYB >/dev/null
post /state '{"tab":"tabYB","gone":true}' >/dev/null
det "the pinned tab closes -> back to Auto within ~3 s" 'waitfor .auto true 24 && [[ "$(last .pinned)" == "" && "$(last .shownId)" == tab:tabS1 && "$(last .sources)" != *tabYB* ]]'
det "... and the daemon is automatic again" '[[ "$(dstate .pin)" == null ]]'
check "dedupe: the browser player of a listed tab is that tab; Spotify and other browser sites are their own rows" '[[ "$(nptest2 sourcesWith "org.mpris.MediaPlayer2.firefox.instance_1_642|Zen|POV: You Beat The Dragon|1;org.mpris.MediaPlayer2.spotify|Spotify|Pigstep|0;org.mpris.MediaPlayer2.chromium.instance9|Chromium|Some podcast|1")" == "tab:tabS1|TikTok|tiktok;tab:tabYC|YouTube|youtube;mpris:org.mpris.MediaPlayer2.spotify|Spotify|spotify;mpris:org.mpris.MediaPlayer2.chromium.instance9|Chromium|other" ]]'
check "dedupe: no browser player at all -> paused tabs are dropped (the browser quit)" '[[ "$(nptest2 sourcesWith "org.mpris.MediaPlayer2.spotify|Spotify|Pigstep|1")" == "tab:tabS1|TikTok|tiktok;mpris:org.mpris.MediaPlayer2.spotify|Spotify|spotify" ]]'
check "maximized source window (Hyprland fullscreen 1) -> still shown" '[[ "$(nptest2 fullscreen 1)" == "fullscreen 1" ]] && sleep 0.3 && waitfor .fs false && [[ "$(last .shown)" == true ]]'
check "fullscreen source window (2) -> hidden" 'nptest2 fullscreen 2 >/dev/null; waitfor .shown false && [[ "$(last .fs)" == true ]]'
check "fullscreen + maximized bits (3) -> hidden" 'nptest2 fullscreen 3 >/dev/null; waitfor .fs true'
check "back to a normal window -> shown"    'nptest2 fullscreen 0 >/dev/null; waitfor .shown true && nptest2 fullscreen none >/dev/null'
kill "$HB" 2>/dev/null; wait "$HB" 2>/dev/null
sleep 1.2                                                                     # a heartbeat still in flight lands first
post /state '{"tab":"tabYC","gone":true}' >/dev/null
post /state "$(jq -c ".ts=$(date +%s%3N) | .position=2.4 | .paused=true" <<<"$TT")" >/dev/null
det "paused follows the browser"      'waitfor .paused true && [[ "$(last .shown)" == true && "$(last .pos)" == 2.4 ]]'
det "status line"                     'ipc status | grep -q "TikTok paused: pov: you beat the dragon, video ready"'
check "reset answers"                   'ipc reset | grep -q "reset on"'
check "reveal answers"                  'ipc reveal | grep -q "revealed on"'
post /state '{"tab":"tabS1","gone":true}' >/dev/null
det "tab gone -> nothing, lingering"  'waitfor .kind none && [[ "$(last .lingering)" == true && "$(last .shown)" == true && "$(last .title)" == "pov: you beat the dragon" ]]'
det "auto-hide after autoHideSec (3 s)" 'waitfor .shown false 24 && [[ "$(last .lingering)" == false ]]'
check "ipc reveal shows it idle"        'ipc reveal >/dev/null; waitfor .shown true'
# ------------------------------------------------------------------ long videos in parts (default 5 min first part, 40 min parts)
YL='{"tab":"tabYL","site":"youtube","pageUrl":"https://www.youtube.com/watch?v=LLLLLLLLLLL","videoId":"LLLLLLLLLLL","title":"A long lecture","author":"Prof","position":3001,"duration":6377.9,"paused":false,"rate":1,"live":false,"isVideo":true,"ad":false,"visible":true,"bv":"1.4.1"}'
( while :; do post /state "$(jq -c ".ts=$(date +%s%3N) | .position=(3001 + ($(date +%s%3N) % 100000) / 100000)" <<<"$YL")" >/dev/null; sleep 1; done ) & HB=$!
det "a video longer than maxVideoMin -> parts mode, the first part asked at the position" 'waitfor .key youtube-LLLLLLLLLLL && waitfor .inParts true && for _ in $(seq 1 30); do grep -Eq "^SECTION 2999-33(00|01) .*LLLLLLLLLLL" "$FAKE_LOG" && break; sleep 0.2; done; grep -Eq "^SECTION 2999-33(00|01) " "$FAKE_LOG"'
det "parts: the part arrives -> the mirror gets it with its true start (the keyframe before the cut)" 'waitfor ".mirrorParts | length >= 1" true 40 && [[ "$(last ".mirrorParts[0].start")" == 2995 && "$(last ".mirrorParts[0].file")" == "$T/cache/youtube-LLLLLLLLLLL.part-"*.mp4 && "$(last .videoFile)" == "" ]]'
det "parts: status line \"video parts n/m ready\" (the next part may already be on its way)" '[[ "$(last .partsText)" =~ ^parts\ [12]/[12]\ ready$ ]] && ipc status | grep -Eq "video parts [12]/[12] ready"'
kill "$HB" 2>/dev/null; wait "$HB" 2>/dev/null
post /state '{"tab":"tabYL","gone":true}' >/dev/null
W1="$(nptest2 want MMMMMMMMMMM 7200 100 false)"
check "MPRIS-only long video: want carries the position, duration, paused, rate" '[[ "$(jq -c "[.cmd, .id, .duration, .position, .paused, .rate]" <<<"$W1")" == "[\"want\",\"MMMMMMMMMMM\",7200,100,false,1]" ]]'
check "... not again within 5 s while it plays on as predicted" '[[ "$(nptest2 want MMMMMMMMMMM 7200 100.5 false)" == "" ]]'
check "... at once after a jump (> 3 s off the prediction)" '[[ "$(nptest2 want MMMMMMMMMMM 7200 1500 false | jq -r .position)" == 1500 ]]'
check "... at once on pause"             '[[ "$(nptest2 want MMMMMMMMMMM 7200 1500 true | jq -r .paused)" == true ]]'
check "... and again after 5 s"          'sleep 5.1; [[ "$(nptest2 want MMMMMMMMMMM 7200 1500 true | jq -r .position)" == 1500 ]]'
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
