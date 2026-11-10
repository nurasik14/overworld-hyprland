#!/usr/bin/env bash
# tests/nowplaying-bridge.test.sh — runs the real userscript (apps/zen/nowplaying-bridge.user.js, a test token baked in) in a headless,
# muted Chromium against synthetic YouTube / YouTube Music / TikTok pages (tests/nowplaying-bridge/make-pages.sh), with a stub
# GM_xmlhttpRequest that answers like the daemon and TikTok's CDN, driven over the DevTools protocol (tests/nowplaying-bridge/run.js).
# No network (every host name fails to resolve), no real site, no window.
#   CHROME=<path to chrome/chromium> (default: ~/.hermes/tools/chromium-*/chrome-linux64/chrome, else chromium on PATH)
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CHROME="${CHROME:-$(ls "$HOME"/.hermes/tools/chromium-*/chrome-linux64/chrome 2>/dev/null | head -1)}"
[[ -x "$CHROME" ]] || CHROME="$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)"
[[ -x "$CHROME" ]] || { echo "SKIP: no chromium"; exit 0; }
T="$(mktemp -d /tmp/np-bridge.XXXXXX)"
trap 'rm -rf "$T"' EXIT
sed -e 's/__HYPR_NOWPLAYING_TOKEN__/test-token-0123456789abcdef/' -e 's/__HYPR_NOWPLAYING_PORT__/47999/' \
    "$REPO/apps/zen/nowplaying-bridge.user.js" >"$T/us.js"
bash "$REPO/tests/nowplaying-bridge/make-pages.sh" "$T/us.js" "$T/pages"
# the template itself: page 5, idle
bash -c 'source /dev/null' && cp "$T/pages/youtube.html" "$T/pages/template.html" && \
    python3 - "$T/pages/template.html" "$REPO/apps/zen/nowplaying-bridge.user.js" "$T/us.js" <<'PY'
import sys
p, tpl, baked = sys.argv[1:]
s = open(p).read(); s = s.replace(open(baked).read(), open(tpl).read()); open(p, "w").write(s)
PY
# in parallel (each page its own headless Chromium); the TikTok action pages run ~30 s of scripted steps
for f in "$T"/pages/*.html; do
    n="$(basename "$f" .html)"
    w=12000; [[ "$n" == tiktok-act* ]] && w=50000
    nice -n 10 node "$REPO/tests/nowplaying-bridge/run.js" "$CHROME" "$T/profile-$n" "$f" "$w" >"$T/$n.json" 2>/dev/null &
done
wait
node - "$T" <<'JS'
const fs = require("fs"), T = process.argv[2];
let pass = 0, fail = 0;
const ok = (n, c, x) => { if (c) { pass++; console.log("PASS " + n); } else { fail++; console.log("FAIL " + n + (x !== undefined ? "  [" + JSON.stringify(x).slice(0, 400) + "]" : "")); } };
const load = n => { try { return JSON.parse(fs.readFileSync(T + "/" + n + ".json", "utf8")); } catch (e) { return null; } };
const states = r => r.calls.filter(c => /\/state$/.test(c.url)).map(c => JSON.parse(c.data));

let r = load("youtube");
ok("youtube: page ran", !!r);
if (r) {
  const s = states(r).filter(x => !x.gone);
  ok("youtube: reports go to 127.0.0.1 with the token", r.calls.every(c => !/\/state$/.test(c.url) || (c.url === "http://127.0.0.1:47999/state" && c.headers["X-Hypr-Nowplaying-Token"] === "test-token-0123456789abcdef")));
  ok("youtube: first report", s.length > 0, r.calls);
  const a = s[0] || {};
  ok("youtube: the main player, not the muted preview", a.videoId === "dQw4w9WgXcQ" && a.position === 42, a);
  ok("youtube: title from mediaSession, author", a.title === "Never Gonna Give You Up (Official Video)" && a.author === "Rick Astley", a);
  ok("youtube: thumbnail + clean page URL", a.thumbnail === "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg" && a.pageUrl === "https://www.youtube.com/watch?v=dQw4w9WgXcQ", a);
  ok("youtube: fields", a.site === "youtube" && a.isVideo === true && a.live === false && a.ad === false && a.paused === false && a.rate === 1 && a.duration === 30 && a.width === 1280 && typeof a.ts === "number" && /^[A-Za-z0-9_-]{4,40}$/.test(a.tab), a);
  const playing = s.filter(x => !x.paused && !x.ad);
  ok("youtube: ~1 Hz while playing (2.5 s, plus 2 buffering events -> 3..6 reports)", playing.length >= 3 && playing.length <= 6, playing.length);
  ok("youtube: buffering reported, then cleared", s.some(x => x.buffering === true) && s.filter(x => !x.paused).slice(-1)[0].buffering === false, s.map(x => x.buffering));
  ok("youtube: pause reported", s.some(x => x.paused), s.map(x => x.paused));
  ok("youtube: nothing while paused (3 s)", r.extra.beforeAd === r.extra.afterPause, r.extra);
  ok("youtube: ad flagged", s.some(x => x.ad === true), s.map(x => x.ad));
  ok("youtube: no other hosts contacted", r.calls.every(c => /^http:\/\/127\.0\.0\.1:47999\//.test(c.url)));
}
r = load("ytmusic");
ok("ytmusic: page ran", !!r);
if (r) {
  const a = states(r)[0] || {};
  ok("ytmusic: site, id", a.site === "ytmusic" && a.videoId === "AAAAAAAAAAA", a);
  ok("ytmusic: an art track is not a video", a.isVideo === false, a);
  ok("ytmusic: the biggest album cover", a.thumbnail === "https://lh3.googleusercontent.com/abc=w544", a);
}
r = load("tiktok");
ok("tiktok: page ran", !!r);
if (r) {
  const a = states(r)[0] || {};
  ok("tiktok: the playing, visible item", a.videoId === "7400000000000000002", a);
  ok("tiktok: desc + author from the item data", a.title === "pov: you beat the dragon #minecraft" && a.author === "blocky.builds", a);
  ok("tiktok: cover from the item data", a.thumbnail === "https://p16-sign-va.tiktokcdn.com/cover2.jpeg", a);
  ok("tiktok: page URL built", a.pageUrl === "https://www.tiktok.com/@blocky.builds/video/7400000000000000002", a);
  ok("tiktok: portrait size, video", a.isVideo && a.width === 576 && a.height === 1024, a);
  const get = r.calls.find(c => c.method === "GET");
  ok("tiktok: asked -> fetches the lightest file first", get && get.url === "https://v16-webapp-prime.tiktok.com/video_slow/low2", get);
  ok("tiktok: with cookies and a tiktok Referer", get && get.anonymous === false && get.headers.Referer === "https://www.tiktok.com/", get);
  const up = r.calls.find(c => /\/video\//.test(c.url) && c.method === "POST");
  ok("tiktok: uploads it to the daemon", up && up.url === "http://127.0.0.1:47999/video/tiktok-7400000000000000002" && up.data === "[binary 4096]" && up.headers["Content-Type"] === "video/mp4", up);
  ok("tiktok: one upload only", r.calls.filter(c => /\/video\//.test(c.url)).length === 1);
}
r = load("tiktok-noitem");
ok("tiktok-noitem: page ran", !!r);
if (r) {
  const a = states(r)[0] || {};
  ok("tiktok-noitem: id from the xgwrapper", a.videoId === "7400000000000000009", a);
  ok("tiktok-noitem: desc + author from the overlay", a.title === "overlay desc" && a.author === "overlay.author", a);
  const api = r.calls.find(c => /api\/item\/detail/.test(c.url));
  ok("tiktok-noitem: falls back to the item API", !!api && /itemId=7400000000000000009/.test(api.url), r.calls.map(c => c.url));
  const err = r.calls.find(c => /video-error/.test(c.url));
  ok("tiktok-noitem: reports the failure", !!err && /blob:/.test(JSON.parse(err.data).reason), err);
}
// ------------------------------------------------------------------ TikTok like / repost / save (1.3.0)
const T1 = "7400000000000000002";
const okRes = (x, id) => x && x.last && x.last.id === id && x.last.ok === true && x.last.error === "";
r = load("tiktok-act1");
ok("tiktok-act1: page ran", !!r);
if (r) {
  const R = r.extra;
  ok("act: first report has the action-bar state (props: not liked / not saved, repost unknown)", R.first && R.first.bar === true && R.first.clip === T1
     && R.first.liked === false && R.first.saved === false && R.first.reposted === null && R.first.busy === "" && R.first.last === null, R.first);
  ok("act: only 127.0.0.1 contacted (TikTok's API is never called by the script)", r.calls.every(c => /^http:\/\/127\.0\.0\.1:47999\//.test(c.url)), r.calls.map(c => c.url));
  ok("act: like -> clicked once, aria-pressed true, reported liked", okRes(R.like, 1) && R.like.tt.liked === true && R.like.dom.liked === true
     && R.like.dom.clicks.filter(c => c === "like").length === 1, R.like);
  ok("act: like again -> unliked", okRes(R.unlike, 2) && R.unlike.tt.liked === false && R.unlike.dom.liked === false && R.unlike.dom.api.join() === "digg 1,digg 0", R.unlike);
  ok("act: repost -> share panel, Repost clicked, panel closed, reposted true", okRes(R.repost, 3) && R.repost.tt.reposted === true && R.repost.dom.reposted === true
     && R.repost.dom.panel === false && R.repost.dom.clicks.includes("repost"), R.repost);
  ok("act: repost again -> Remove repost, reposted false, panel closed", okRes(R.unrepost, 4) && R.unrepost.tt.reposted === false && R.unrepost.dom.reposted === false
     && R.unrepost.dom.panel === false, R.unrepost);
  ok("act: save -> favourite, Manage, Edits (395 -> 396), list closed, saved true (stale props)", okRes(R.save, 5) && R.save.tt.saved === true
     && R.save.dom.collected === true && R.save.dom.edits === 396 && R.save.dom.inEdits === true && R.save.dom.list === false
     && R.save.dom.clicks.slice(-4).join() === "favorite,manage,collection Edits,escape", R.save);
  ok("act: save again -> un-favourite (out of Edits too: 395), saved false", okRes(R.unsave, 6) && R.unsave.tt.saved === false && R.unsave.dom.collected === false
     && R.unsave.dom.edits === 395 && !R.unsave.dom.clicks.slice(-1)[0].startsWith("collection"), R.unsave);
  ok("act: a command for another clip is refused, nothing clicked", R.wrong && R.wrong.last && R.wrong.last.ok === false && /another clip/.test(R.wrong.last.error) && R.wrongClicks === 0, R.wrong);
  ok("act: busy reported while it runs", R.busySeen === true);
  ok("act: a second press while busy is refused, the like is not clicked", R.dup9 && R.dup9.ok === false && /busy/.test(R.dup9.error) && R.dupLikeClicks === 0, R.dup9);
  ok("act: the same command handed over twice runs once", R.dup8 && R.dup8.ok === true && R.dupShareClicks === 1, { dup8: R.dup8, shares: R.dupShareClicks });
  ok("act: (undo the repost)", okRes(R.undo8, 10) && R.undo8.tt.reposted === false, R.undo8);
  ok("act: no such collection -> error, left in Favorites only, list closed, nothing created", R.nocoll && R.nocoll.last.ok === false
     && /no collection named "Nope"/.test(R.nocoll.last.error) && R.nocoll.tt.saved === true && R.nocoll.dom.list === false
     && R.nocoll.dom.edits === 395 && !R.nocoll.dom.clicks.includes("create collection"), R.nocoll);
  ok("act: (un-save)", okRes(R.nocollUndo, 12) && R.nocollUndo.tt.saved === false, R.nocollUndo);
  ok("act: the collection name matches case-insensitively, not \"Edits old\"", okRes(R.ci, 13) && R.ci.dom.inEdits === true && R.ci.dom.clicks.includes("collection Edits")
     && !R.ci.dom.clicks.includes("collection Edits old"), R.ci);
  ok("act: end state = start state", R.dom && R.dom.liked === false && R.dom.collected === false && R.dom.reposted === false && R.dom.edits === 395 && !R.dom.panel && !R.dom.list, R.dom);
}
r = load("tiktok-act2");
ok("tiktok-act2: page ran", !!r);
if (r) {
  const R = r.extra;
  ok("act2: live props: starts liked + saved", R.first && R.first.liked === true && R.first.saved === true, R.first);
  ok("act2: paused + daemon says poll -> 1 s heartbeat (3 s: 2..4 reports)", R.pausedReports >= 2 && R.pausedReports <= 4, R.pausedReports);
  ok("act2: a command reaches the paused clip within 1.5 s", R.pausedLike && okRes(R.pausedLike, 1) && R.pausedLike.firstClickMs >= 0 && R.pausedLike.firstClickMs <= 1500
     && R.pausedLike.tt.liked === false, R.pausedLike && { ms: R.pausedLike.firstClickMs, last: R.pausedLike.last });
  ok("act2: un-save a favourited clip (no Manage, collect action=2)", okRes(R.unsave, 2) && R.unsave.tt.saved === false && R.unsave.dom.api.slice(-1)[0] === "collect action=2"
     && !R.unsave.dom.clicks.includes("manage"), R.unsave);
  ok("act2: no Manage toast -> \"saved to Favorites only\", saved true", R.notoast && R.notoast.last.ok === false && /Favorites only/.test(R.notoast.last.error)
     && R.notoast.tt.saved === true && R.notoast.dom.collected === true, R.notoast);
  ok("act2: (un-save)", okRes(R.notoastUndo, 4) && R.notoastUndo.tt.saved === false, R.notoastUndo);
  ok("act2: Escape does not close the share panel -> its close button does", okRes(R.repostClose, 5) && R.repostClose.dom.panel === false
     && R.repostClose.dom.clicks.includes("panel close") && R.repostClose.tt.reposted === true, R.repostClose);
  ok("act2: PiP off (no poll) -> quiet while paused", R.quietAfterOff === 0, R.quietAfterOff);
  ok("act2: logged out (no action column) -> no buttons", R.noBarTT && R.noBarTT.bar === false && R.noBarTT.liked === null, R.noBarTT);
  ok("act2: ... and a command fails with a reason", R.noBar && R.noBar.last && R.noBar.last.ok === false && /logged out/.test(R.noBar.last.error), R.noBar);
}
r = load("tiktok-feed");
ok("tiktok-feed: page ran", !!r);
if (r) {
  const R = r.extra;
  ok("feed: previous/next track handlers registered", JSON.stringify(R.handlers) === '["nexttrack","previoustrack"]', R.handlers);
  ok("feed: next -> the feed-navigation-next button, no scrolling", JSON.stringify(R.a) === '{"nav":["feed-navigation-next"],"scrolls":[]}', R.a);
  ok("feed: previous -> the feed-navigation-prev button", JSON.stringify(R.b) === '{"nav":["feed-navigation-next","feed-navigation-prev"],"scrolls":[]}', R.b);
  ok("feed: next disabled -> scrolls to the next item", JSON.stringify(R.c.scrolls) === '["it3"]' && R.c.nav.length === 2, R.c);
  ok("feed: no buttons -> scrolls to the previous item", JSON.stringify(R.d.scrolls) === '["it3","it1"]', R.d);
}
r = load("tiktok-stall");
ok("tiktok-stall: page ran", !!r);
if (r) ok("watchdog: a stuck clip is bounced away and back", JSON.stringify(r.extra.scrolls) === '["it1","it2"]', r.extra.scrolls);
r = load("tiktok-stall-paused");
ok("tiktok-stall-paused: page ran", !!r);
if (r) ok("watchdog: a clip the user paused is left alone", JSON.stringify(r.extra.scrolls) === "[]", r.extra.scrolls);
r = load("template");
ok("template: idle without a token", r && r.calls.length === 0, r && r.calls.length);
console.log("----\n" + pass + " passed, " + fail + " failed");
process.exit(fail ? 1 : 0);
JS
