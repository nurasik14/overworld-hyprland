#!/usr/bin/env bash
# make-pages.sh <userscript with token/port baked in> <outdir>: builds one HTML page per scenario around the real userscript
US="$1"; OUT="$2"; HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
page() {   # page <name> <location-json> <dom-html> <setup-js> <steps-js>
    # Headless Chromium never finishes a --dump-dom of a page whose markup (or a cloned template) holds a <video>, but one made with
    # createElement after `load` is fine: so the DOM is a <template> with <x-video> placeholders, swapped in on `load`, and the
    # userscript runs right after it (wrapped so that `location` is the fake one).
    {
        echo '<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0} video{display:block;width:600px;height:340px} .tall video{width:360px;height:640px} .off{margin-top:3000px}</style></head><body>'
        echo '<template id="dom">'; echo "$3" | sed 's/<video /<x-video /g; s/<\/video>/<\/x-video>/g'; echo '</template>'
        echo '<pre id="out"></pre><script>'; cat "$HERE/harness.js"; echo '</script>'
        echo '<script type="text/plain" id="us">'; cat "$US"; echo '</script>'
        echo "<script>addEventListener('load', () => { document.body.prepend(document.getElementById('dom').content.cloneNode(true));"
        echo "for (const x of document.querySelectorAll('x-video')) { const v = document.createElement('video'); for (const a of x.attributes) v.setAttribute(a.name, a.value); x.replaceWith(v); }"
        echo "const fakeLocation = $2; $4"
        echo "new Function('location', document.getElementById('us').textContent)(fakeLocation);"
        echo "$5 });</script>"
        echo '</body></html>'
    } >"$OUT/$1.html"
}
YTLOC='{"hostname":"www.youtube.com","href":"https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=RDx&index=3","origin":"https://www.youtube.com","pathname":"/watch"}'
# 1. YouTube watch page: the main player plays, a muted hover preview also plays (ignored); then pause, then an ad
page youtube "$YTLOC" '
<div id="movie_player" class="html5-video-player"><video id="main"></video></div>
<ytd-video-preview><video id="preview"></video></ytd-video-preview>' '
const main = document.getElementById("main"), prev = document.getElementById("preview");
fakeMedia(main, { currentTime: 42 }); fakeMedia(prev, { muted: true, currentTime: 3 });
document.getElementById("movie_player").getVideoData = () => ({ video_id: "dQw4w9WgXcQ", title: "Never Gonna Give You Up", author: "Rick Astley", isLive: false });
try { navigator.mediaSession.metadata = new MediaMetadata({ title: "Never Gonna Give You Up (Official Video)", artist: "Rick Astley" }); } catch (e) {}' '
setTimeout(() => fire(main, "play"), 50);
setTimeout(() => { main.__st.readyState = 2; fire(main, "waiting"); }, 1700);
setTimeout(() => { main.__st.readyState = 4; fire(main, "playing"); }, 2200);
setTimeout(() => { main.__st.paused = true; fire(main, "pause"); }, 2600);
setTimeout(() => { window.__afterPause = window.__calls.length; }, 3000);
setTimeout(() => { document.getElementById("movie_player").classList.add("ad-showing"); main.__st.paused = false; fire(main, "play"); }, 6000);
setTimeout(() => finish({ afterPause: window.__afterPause, beforeAd: window.__beforeAd }), 6800);
setTimeout(() => { window.__beforeAd = window.__calls.length; }, 5900);'
# 2. YouTube Music: an art track (ATV) has a picture but is not a video
page ytmusic '{"hostname":"music.youtube.com","href":"https://music.youtube.com/watch?v=AAAAAAAAAAA","origin":"https://music.youtube.com","pathname":"/watch"}' '
<ytmusic-player><div id="movie_player" class="html5-video-player"><video id="main"></video></div></ytmusic-player>' '
const main = document.getElementById("main"); fakeMedia(main, { videoWidth: 500, videoHeight: 500 });
const mp = document.getElementById("movie_player");
mp.getVideoData = () => ({ video_id: "AAAAAAAAAAA", title: "Song", author: "Artist", isLive: false });
mp.getPlayerResponse = () => ({ videoDetails: { musicVideoType: "MUSIC_VIDEO_TYPE_ATV" } });
try { navigator.mediaSession.metadata = new MediaMetadata({ title: "Song", artist: "Artist", artwork: [{ src: "https://lh3.googleusercontent.com/abc=w120", sizes: "120x120" }, { src: "https://lh3.googleusercontent.com/abc=w544", sizes: "544x544" }] }); } catch (e) {}' '
setTimeout(() => fire(main, "play"), 50); setTimeout(() => finish(), 1500);'
# 3. TikTok For You feed (2026 layout): three items, blob: sources, the second plays and fills the view; data in the page JSON
TTJSON='{"__DEFAULT_SCOPE__":{"webapp.updated-items":[{"id":"7400000000000000001","desc":"first","author":{"uniqueId":"a1"},"video":{"playAddr":"https://v16-webapp-prime.tiktok.com/video/1"}},{"id":"7400000000000000002","desc":"pov: you beat the dragon #minecraft","author":{"uniqueId":"blocky.builds"},"music":{"title":"original sound"},"video":{"cover":"https://p16-sign-va.tiktokcdn.com/cover2.jpeg","playAddr":"https://v16-webapp-prime.tiktok.com/video/play2","downloadAddr":"https://v16-webapp-prime.tiktok.com/video/dl2","bitrateInfo":[{"Bitrate":900000,"PlayAddr":{"UrlList":["https://v16-webapp-prime.tiktok.com/video/high2"]}},{"Bitrate":300000,"PlayAddr":{"UrlList":["https://v16-webapp-prime.tiktok.com/video_slow/low2"]}}]}}]}}'
page tiktok '{"hostname":"www.tiktok.com","href":"https://www.tiktok.com/foryou","origin":"https://www.tiktok.com","pathname":"/foryou"}' "
<script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\" type=\"application/json\">$TTJSON</script>
<div class=\"tall\">
<article data-e2e=\"recommend-list-item-container\" class=\"off\"><div class=\"tiktok-web-player\" id=\"xgwrapper-0-7400000000000000001\"><video id=\"v1\"></video></div></article>
<article data-e2e=\"recommend-list-item-container\" style=\"position:absolute;top:0\"><div class=\"tiktok-web-player\" id=\"xgwrapper-0-7400000000000000002\"><video id=\"v2\"></video></div><picture><img src=\"https://p16-sign-va.tiktokcdn.com/fallback.jpeg\"></picture></article>
<article data-e2e=\"recommend-list-item-container\" class=\"off\"><div class=\"tiktok-web-player\" id=\"xgwrapper-0-7400000000000000003\"><video id=\"v3\"></video></div></article>
</div>
<div data-e2e=\"anchoring-description-layer\"><a data-e2e=\"video-author-avatar\" href=\"/@overlay.author\">x</a><div data-e2e=\"video-desc\">overlay desc</div></div>" '
const v1 = document.getElementById("v1"), v2 = document.getElementById("v2"), v3 = document.getElementById("v3");
fakeMedia(v1, { paused: true, videoWidth: 576, videoHeight: 1024, duration: 20, currentTime: 0 });
fakeMedia(v2, { videoWidth: 576, videoHeight: 1024, duration: 34, currentTime: 5 });
fakeMedia(v3, { paused: true, videoWidth: 576, videoHeight: 1024, duration: 15, currentTime: 0 });
window.__wantVideo = true;' '
setTimeout(() => fire(v2, "play"), 50); setTimeout(() => finish(), 2500);'
# 4. TikTok feed item NOT in the page JSON: the id comes from the wrapper, desc/author from the overlay; no file URL -> video-error
page tiktok-noitem '{"hostname":"www.tiktok.com","href":"https://www.tiktok.com/foryou","origin":"https://www.tiktok.com","pathname":"/foryou"}' '
<div class="tall"><article data-e2e="recommend-list-item-container"><div class="tiktok-web-player" id="xgwrapper-0-7400000000000000009"><video id="v9"></video></div></article></div>
<div data-e2e="anchoring-description-layer"><a data-e2e="video-author-avatar" href="/@overlay.author">x</a><div data-e2e="video-desc">overlay desc</div></div>' '
const v9 = document.getElementById("v9"); fakeMedia(v9, { videoWidth: 576, videoHeight: 1024 }); window.__wantVideo = true;' '
setTimeout(() => fire(v9, "play"), 50); setTimeout(() => finish(), 2500);'
# --- TikTok, logged in: the For You feed with its action column (fakeTikTok in harness.js), for like / repost / save, the
#     feed-navigation buttons and the stall watchdog. Three items, the second is the current one (fills the view).
TTLOC='{"hostname":"www.tiktok.com","href":"https://www.tiktok.com/foryou","origin":"https://www.tiktok.com","pathname":"/foryou"}'
TTFEED="
<script id=\"__UNIVERSAL_DATA_FOR_REHYDRATION__\" type=\"application/json\">$TTJSON</script>
<div class=\"tall\">
<article data-e2e=\"recommend-list-item-container\" id=\"it1\" class=\"off\"><div class=\"tiktok-web-player\" id=\"xgwrapper-0-7400000000000000001\"><video id=\"v1\"></video></div></article>
<article data-e2e=\"recommend-list-item-container\" id=\"it2\" style=\"position:absolute;top:0\"><div class=\"tiktok-web-player\" id=\"xgwrapper-0-7400000000000000002\"><video id=\"v2\"></video></div></article>
<article data-e2e=\"recommend-list-item-container\" id=\"it3\" class=\"off\"><div class=\"tiktok-web-player\" id=\"xgwrapper-0-7400000000000000003\"><video id=\"v3\"></video></div></article>
</div>"
TTMEDIA='const v1 = document.getElementById("v1"), v2 = document.getElementById("v2"), v3 = document.getElementById("v3");
fakeMedia(v1, { paused: true, videoWidth: 576, videoHeight: 1024, duration: 20, currentTime: 0 });
fakeMedia(v2, { videoWidth: 576, videoHeight: 1024, duration: 34, currentTime: 5 });
fakeMedia(v3, { paused: true, videoWidth: 576, videoHeight: 1024, duration: 15, currentTime: 0 });
setInterval(() => { if (!v2.__st.paused) v2.__st.currentTime += 0.25; }, 250);
function makeCurrent(el) {   // what scrolling the snap container does: el fills the view, the others are far below
  for (const it of document.querySelectorAll("article")) { it.className = it === el ? "" : "off"; it.style.position = it === el ? "absolute" : ""; it.style.top = it === el ? "0" : ""; }
}
window.__scrolls = [];
Element.prototype.scrollIntoView = function () { window.__scrolls.push(this.id || "?"); makeCurrent(this); };'
K2='"tiktok-7400000000000000002"'
# 6. like / unlike, repost / remove, save -> Edits / un-save, wrong clip refused, duplicate presses, missing collection, case-insensitive
#    name. TikTok's item props are stale here (they keep saying "not liked, not favourited"): our own results must carry the state.
page tiktok-act1 "$TTLOC" "$TTFEED" "$TTMEDIA
document.body.insertAdjacentHTML(\"beforeend\", TT_BAR); fakeTikTok({ staleProps: true });" '
setTimeout(() => fire(v2, "play"), 50);
(async () => {
  const R = {};
  await untilP(() => reports().length > 0, 3000);
  R.first = reports()[0].tt;
  R.like = await ttAct(1, "like");
  R.unlike = await ttAct(2, "like");
  R.repost = await ttAct(3, "repost");
  R.unrepost = await ttAct(4, "repost");
  R.save = await ttAct(5, "save");
  R.unsave = await ttAct(6, "save");
  let n = window.__tt.clicks.length;
  R.wrong = await ttAct(7, "like", { key: "tiktok-7400000000000000003" });
  R.wrongClicks = window.__tt.clicks.length - n;
  window.__tt.delay = 1500;   // a slow share panel: the next two presses arrive while it runs
  window.__actionQueue.push({ id: 8, key: '"$K2"', action: "repost", collection: "Edits" });
  R.busySeen = !!(await untilP(() => reports().some(x => x.tt && x.tt.busy === "repost"), 4000));
  const likes = window.__tt.clicks.filter(c => c === "like").length, shares = window.__tt.clicks.filter(c => c === "share").length;
  window.__actionQueue.push({ id: 8, key: '"$K2"', action: "repost", collection: "Edits" }, { id: 9, key: '"$K2"', action: "like", collection: "Edits" });
  const r9 = await untilP(() => resultOf(9), 6000);
  R.dup9 = r9 ? r9.tt.last : null;
  const r8 = await untilP(() => resultOf(8), 12000);
  R.dup8 = r8 ? r8.tt.last : null;
  R.dupLikeClicks = window.__tt.clicks.filter(c => c === "like").length - likes;
  R.dupShareClicks = window.__tt.clicks.filter(c => c === "share").length - shares;
  R.dupRepostClicks = window.__tt.clicks.filter(c => c === "repost").length;
  await waitMs(1700);   // the slow fake flips its state 1.5 s after the click
  window.__tt.delay = 150;
  R.undo8 = await ttAct(10, "repost");
  R.nocoll = await ttAct(11, "save", { collection: "Nope" });
  R.nocollUndo = await ttAct(12, "save");
  R.ci = await ttAct(13, "save", { collection: "edits" });
  R.ciUndo = await ttAct(14, "save");
  R.dom = window.__tt.snap();
  finish(R);
})();'
# 7. a paused clip still gets commands (1 s heartbeat while the daemon says poll), live props (starts liked + favourited),
#    un-save, the Manage toast never appears, a share panel Escape does not close, PiP off = quiet, logged out (no action column)
page tiktok-act2 "$TTLOC" "$TTFEED" "$TTMEDIA
document.body.insertAdjacentHTML(\"beforeend\", TT_BAR); fakeTikTok({ escCloses: false, liked: true, collected: true }); window.__poll = true;" '
setTimeout(() => fire(v2, "play"), 50);
(async () => {
  const R = {};
  await untilP(() => reports().length > 0, 3000);
  R.first = reports()[0].tt;
  v2.__st.paused = true; fire(v2, "pause");
  await waitMs(400);
  let n = reports().length;
  await waitMs(3000);
  R.pausedReports = reports().length - n;
  R.pausedLike = await ttAct(1, "like");
  R.unsave = await ttAct(2, "save");
  window.__tt.toast = false;
  R.notoast = await ttAct(3, "save");
  R.notoastUndo = await ttAct(4, "save");
  window.__tt.toast = true;
  R.repostClose = await ttAct(5, "repost");
  window.__poll = false;
  await waitMs(1500);
  n = reports().length;
  await waitMs(3000);
  R.quietAfterOff = reports().length - n;
  window.__poll = true;
  v2.__st.paused = false; fire(v2, "play");
  await waitMs(400);
  document.querySelector("[data-e2e=anchoring-engagement-vertical]").remove();
  await waitMs(1300);
  R.noBarTT = reports().slice(-1)[0].tt;
  R.noBar = await ttAct(6, "like");
  R.dom = window.__tt.snap();
  finish(R);
})();'
# 8. ⏮ / ⏭ (media-session previous / next track): the feed-navigation buttons first, the scroll path when they are disabled / gone
page tiktok-feed "$TTLOC" "$TTFEED
<button data-e2e=\"feed-navigation-prev\" aria-label=\"Go to previous video\"></button><button data-e2e=\"feed-navigation-next\" aria-label=\"Go to next video\"></button>" "$TTMEDIA
window.__H = {}; try { navigator.mediaSession.setActionHandler = (a, f) => { window.__H[a] = f; }; } catch (e) {}
window.__nav = []; for (const b of document.querySelectorAll(\"[data-e2e^=feed-navigation]\")) b.addEventListener(\"click\", () => window.__nav.push(b.getAttribute(\"data-e2e\")));" '
setTimeout(() => fire(v2, "play"), 50);
(async () => {
  const R = {};
  await waitMs(500);
  R.handlers = Object.keys(window.__H).sort();
  window.__H.nexttrack(); R.a = { nav: window.__nav.slice(), scrolls: window.__scrolls.slice() };
  window.__H.previoustrack(); R.b = { nav: window.__nav.slice(), scrolls: window.__scrolls.slice() };
  document.querySelector("[data-e2e=feed-navigation-next]").disabled = true;
  window.__H.nexttrack(); R.c = { nav: window.__nav.slice(), scrolls: window.__scrolls.slice() };
  for (const b of document.querySelectorAll("[data-e2e^=feed-navigation]")) b.remove();
  makeCurrent(document.getElementById("it2"));
  window.__H.previoustrack(); R.d = { nav: window.__nav.slice(), scrolls: window.__scrolls.slice() };
  finish(R);
})();'
# 9. the stall watchdog: the clip in view "plays" but its clock never moves -> scroll one item away and back after 7 s
page tiktok-stall "$TTLOC" "$TTFEED" "$TTMEDIA
v2.__st.readyState = 1; v2.__st.paused = false; v2.__st.paused = false;
Object.defineProperty(v2, \"currentTime\", { configurable: true, get: () => 5, set: x => {} });" '
setTimeout(() => finish({ scrolls: window.__scrolls.slice() }), 11500);'
# 10. ... but a clip the user paused (loaded, paused) is left alone
page tiktok-stall-paused "$TTLOC" "$TTFEED" "$TTMEDIA
v2.__st.paused = true; v2.__st.readyState = 4;" '
setTimeout(() => finish({ scrolls: window.__scrolls.slice() }), 11000);'
# 5. the template (no token baked in) stays idle
