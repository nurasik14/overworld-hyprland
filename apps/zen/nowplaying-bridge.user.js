// ==UserScript==
// @name         Now Playing bridge (hypr-nowplaying)
// @namespace    hypr-nowplaying
// @version      1.3.0
// @description  Tells the desktop's Now Playing mini-player (Overworld / Apothecary Hyprland) what this tab plays: video id, title, channel, thumbnail, position, paused, rate. Talks only to 127.0.0.1 with a private token. On TikTok it can also hand over the playing clip's file, because the desktop cannot download TikTok itself, and run the PiP's like / repost / save buttons on TikTok's own buttons.
// @match        https://www.youtube.com/*
// @match        https://m.youtube.com/*
// @match        https://music.youtube.com/*
// @match        https://www.tiktok.com/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      tiktok.com
// @connect      tiktokcdn.com
// @connect      tiktokcdn-us.com
// @connect      tiktokv.com
// @connect      tiktokv.us
// @connect      byteoversea.com
// @connect      ibytedtos.com
// @inject-into  content
// @run-at       document-idle
// @noframes
// ==/UserScript==

// Install it with `hypr-nowplaying userscript --serve` (that copy has your token and port baked in). This file in the repo is the
// template: with the placeholders left in it stays idle.
//
// What it sends (only to http://127.0.0.1:<port>, header X-Hypr-Nowplaying-Token): site, page URL (YouTube: only ?v=; TikTok: no
// query), video id, title, channel / author, thumbnail URL, position, duration, paused, buffering, playback rate, live, ad, picture
// size, whether the tab is visible; on TikTok also whether the clip is liked / favourited / reposted (read from TikTok's own action
// bar). Every second while something plays, at once on play / pause / seek / rate change / new video, nothing while nothing plays.
// The daemon answers {wantVideo}: only then (TikTok, the desktop's PiP is on) the clip's file is fetched from TikTok's own CDN with
// this tab's cookies and posted to the daemon (max 60 MB). It may also answer {actions: [{id, key, action, collection}]}: the PiP's
// like / repost / save buttons, run here by clicking TikTok's own buttons for that clip only (see "TikTok: like / repost / save"),
// and {poll: true} (a TikTok tab while the PiP is on): then a paused tab keeps reporting every second so those commands arrive.

(function () {
  "use strict";
  const TOKEN = "__HYPR_NOWPLAYING_TOKEN__";
  const PORT = "__HYPR_NOWPLAYING_PORT__";
  if (TOKEN.indexOf("__HYPR") === 0 || !/^\d+$/.test(PORT)) {
    console.info("[nowplaying] template copy without a token: idle. Install the copy from `hypr-nowplaying userscript --serve`.");
    return;
  }
  const BASE = "http://127.0.0.1:" + PORT;
  const TAB = (Math.random().toString(36).slice(2, 10) + Date.now().toString(36)).slice(0, 24);
  const HOST = location.hostname;
  const SITE = HOST === "music.youtube.com" ? "ytmusic" : /(^|\.)youtube\.com$/.test(HOST) ? "youtube" : "tiktok";
  const UPLOAD_CAP = 60 * 1024 * 1024;
  const VIDEO_HOSTS = /(^|\.)(tiktok\.com|tiktokcdn\.com|tiktokcdn-us\.com|tiktokv\.com|tiktokv\.us|byteoversea\.com|ibytedtos\.com)$/;

  let active = null;        // the media element we report
  let timer = 0;            // 1 Hz while it plays
  let pending = 0;          // debounce of event-driven reports
  let reported = false;     // the daemon knows this tab (send `gone` when it stops)
  let downUntil = 0;        // nobody listens: back off
  let lastKey = "";
  let pollWanted = false;   // the daemon (so the PiP is on) wants a 1 s heartbeat from this TikTok tab even while paused
  const tried = new Set();  // TikTok keys we already tried to hand over

  // ------------------------------------------------------------------ transport
  function request(method, path, data, contentType, onDone) {
    try {
      GM_xmlhttpRequest({
        method: method,
        url: BASE + path,
        headers: { "X-Hypr-Nowplaying-Token": TOKEN, "Content-Type": contentType || "application/json" },
        data: data,
        timeout: path.indexOf("/video/") === 0 ? 60000 : 4000,
        responseType: "json",
        onload: r => {
          downUntil = 0;
          if (onDone) onDone(r.status, r.response);
        },
        onerror: () => { downUntil = Date.now() + 15000; if (onDone) onDone(0, null); },
        ontimeout: () => { downUntil = Date.now() + 15000; if (onDone) onDone(0, null); },
      });
    } catch (e) { /* the extension is updating / reloading */ }
  }

  // ------------------------------------------------------------------ which element plays
  const isMedia = n => n && (n.tagName === "VIDEO" || n.tagName === "AUDIO");
  function visibleArea(el) {
    const r = el.getBoundingClientRect();
    const w = Math.max(0, Math.min(r.right, innerWidth) - Math.max(r.left, 0));
    const h = Math.max(0, Math.min(r.bottom, innerHeight) - Math.max(r.top, 0));
    return w * h;
  }
  function isPreview(m) {   // YouTube's muted hover previews on the home / search pages
    return SITE !== "tiktok" && !!m.closest("ytd-video-preview, #inline-preview-player, #video-preview, ytd-thumbnail");
  }
  function pick() {
    const all = Array.prototype.filter.call(document.querySelectorAll("video, audio"),
      m => m.isConnected && (m.currentSrc || m.src) && !isPreview(m));
    const playing = all.filter(m => !m.paused && !m.ended && m.readyState > 1);
    if (playing.length) {
      playing.sort((a, b) => (b.muted ? 0 : 1) - (a.muted ? 0 : 1) || visibleArea(b) - visibleArea(a));
      return playing[0];
    }
    if (active && active.isConnected && !isPreview(active)) return active;   // keep reporting the paused one
    return null;
  }

  // ------------------------------------------------------------------ what it is
  function sessionMeta() {
    try {
      const md = navigator.mediaSession && navigator.mediaSession.metadata;
      if (!md) return null;
      const art = Array.prototype.slice.call(md.artwork || []);
      art.sort((a, b) => (parseInt((b.sizes || "0").split("x")[0], 10) || 0) - (parseInt((a.sizes || "0").split("x")[0], 10) || 0));
      return { title: md.title || "", artist: md.artist || "", art: art.length ? art[0].src : "" };
    } catch (e) { return null; }
  }
  function ytPlayerData() {   // the page's own player object (works from the content world in Firefox through wrappedJSObject)
    try {
      const p = document.getElementById("movie_player");
      const raw = p && (p.wrappedJSObject || p);
      const d = raw && typeof raw.getVideoData === "function" ? raw.getVideoData() : null;
      if (!d) return null;
      let type = "";
      try { const pr = raw.getPlayerResponse && raw.getPlayerResponse(); type = String((pr && pr.videoDetails && pr.videoDetails.musicVideoType) || ""); } catch (e) { /* older player */ }
      return { id: String(d.video_id || ""), title: String(d.title || ""), author: String(d.author || ""), live: !!d.isLive, musicType: type };
    } catch (e) { return null; }
  }
  function ytIdFromUrl() {
    const u = new URL(location.href);
    const v = u.searchParams.get("v");
    if (v) return v;
    const m = u.pathname.match(/^\/(shorts|live)\/([A-Za-z0-9_-]{11})/);
    return m ? m[2] : "";
  }
  function describeYouTube(m) {
    const pd = ytPlayerData();
    const inMain = !!m.closest("#movie_player, ytmusic-player, #player");
    const shorts = !!m.closest("ytd-reel-video-renderer, ytd-shorts");
    let id = shorts ? ytIdFromUrl() : (inMain && pd && pd.id) || ytIdFromUrl();
    if (!/^[A-Za-z0-9_-]{11}$/.test(id)) id = "";
    const ms = sessionMeta();
    const title = (ms && ms.title) || (pd && pd.title) || document.title.replace(/ - YouTube( Music)?$/, "");
    const author = (ms && ms.artist) || (pd && pd.author) || "";
    let thumb = id ? "https://i.ytimg.com/vi/" + id + "/hqdefault.jpg" : "";
    if (SITE === "ytmusic" && ms && /^https:\/\/[^/]*googleusercontent\.com\//.test(ms.art)) thumb = ms.art;   // the album cover
    const playerEl = m.closest(".html5-video-player");   // this element's own player (not a hidden watch player behind Shorts)
    return {
      videoId: id, title: title, author: author, thumbnail: thumb,
      pageUrl: id ? location.origin + (shorts ? "/shorts/" + id : "/watch?v=" + id) : location.origin + "/",
      live: !isFinite(m.duration) || !!(pd && pd.live && !shorts),
      ad: !!(playerEl && (playerEl.classList.contains("ad-showing") || playerEl.classList.contains("ad-interrupting")))
        || !!document.querySelector("ytmusic-player-bar[is-advertisement]"),
      // YouTube Music: an art track (ATV) is a still picture, and "Song" mode streams audio only (videoWidth 0)
      artTrack: SITE === "ytmusic" && !!pd && pd.musicType === "MUSIC_VIDEO_TYPE_ATV",
    };
  }
  const textOf = (root, sel) => { const n = root && root.querySelector(sel); return n ? n.textContent.trim().replace(/\s+/g, " ") : ""; };
  // TikTok (2026): every <video> sits in div.tiktok-web-player#xgwrapper-<n>-<id> and plays a blob: MediaSource stream. The item's data
  // (desc, author, cover, play addresses) is in the page JSON for the first items and a detail page, else in the React props of the
  // player element; the For You feed shows desc/author in one overlay for the current item.
  const itemCache = new Map();
  function findItem(obj, id, depth, budget) {
    if (!obj || typeof obj !== "object" || depth > 4 || budget.n++ > 4000) return null;
    try {
      const v = obj.video;
      if (v && typeof v === "object" && (v.playAddr || v.downloadAddr || v.bitrateInfo) && (!id || String(obj.id) === id)) return obj;
      for (const k of Object.keys(obj)) {
        if (k === "return" || k === "child" || k === "sibling" || k === "_owner" || k === "stateNode" || k.charAt(0) === "_") continue;
        const r = findItem(obj[k], id, depth + 1, budget);
        if (r) return r;
      }
    } catch (e) { /* a getter that throws, a dead wrapper */ }
    return null;
  }
  function jsonItem(id) {
    try {
      const el = document.getElementById("__UNIVERSAL_DATA_FOR_REHYDRATION__");
      if (!el) return null;
      const scope = JSON.parse(el.textContent).__DEFAULT_SCOPE__ || {};
      const detail = scope["webapp.video-detail"];
      const it = detail && detail.itemInfo && detail.itemInfo.itemStruct;
      if (it && String(it.id) === id) return it;
      return findItem(scope["webapp.updated-items"], id, 0, { n: 0 });
    } catch (e) { return null; }
  }
  function fiberItem(wrap, id) {
    try {
      const raw = wrap.wrappedJSObject || wrap;   // page world (Firefox content scripts)
      const key = Object.keys(raw).find(k => k.indexOf("__reactFiber$") === 0 || k.indexOf("__reactInternalInstance$") === 0);
      let f = key ? raw[key] : null;
      for (let i = 0; f && i < 25; i++, f = f.return) {
        const r = findItem(f.memoizedProps, id, 0, { n: 0 });
        if (r) return r;
      }
    } catch (e) { /* not React any more */ }
    return null;
  }
  function tiktokData(id, wrap) {
    if (!id) return null;
    if (itemCache.has(id)) return itemCache.get(id);
    const it = jsonItem(id) || (wrap ? fiberItem(wrap, id) : null);
    if (!it) return null;
    let d = null;
    try {   // copy what we need out of the page world
      const v = it.video || {};
      const rates = Array.prototype.slice.call(v.bitrateInfo || []).map(b => ({ bitrate: Number(b.Bitrate) || 0,
        urls: Array.prototype.slice.call((b.PlayAddr && b.PlayAddr.UrlList) || []).map(String) }));
      rates.sort((a, b) => a.bitrate - b.bitrate);   // the PiP is small: the lightest file first
      d = {
        desc: String(it.desc || ""), author: String((it.author && (it.author.uniqueId || it.author)) || ""),
        music: String((it.music && it.music.title) || ""), cover: String(v.cover || v.originCover || ""),
        urls: [].concat(...rates.map(r => r.urls), [String(v.playAddr || ""), String(v.downloadAddr || "")]).filter(Boolean),
      };
    } catch (e) { d = null; }
    if (d) { itemCache.set(id, d); if (itemCache.size > 60) itemCache.delete(itemCache.keys().next().value); }
    return d;
  }
  function tiktokItem(m) {
    return m.closest('[data-e2e="recommend-list-item-container"], [data-e2e="user-post-item"], [data-e2e="explore-item"],'
      + ' [data-e2e="search_top-item"], [data-e2e="search-card-video"], article, [class*="DivItemContainer"],'
      + ' [class*="DivBrowserModeContainer"], [class*="DivVideoDetailContainer"]');
  }
  function biggestPlaying(m) {   // is m the item the page's overlay (desc / author / more-menu) describes?
    const vids = Array.prototype.filter.call(document.querySelectorAll("video"), v => !v.paused);
    return vids.every(v => v === m || visibleArea(v) <= visibleArea(m));
  }
  function describeTikTok(m) {
    let id = "", author = "";
    const wrap = m.closest('[id^="xgwrapper-"]');
    if (wrap) { const x = wrap.id.match(/^xgwrapper-\d+-(\d{8,25})$/) || wrap.id.match(/(\d{15,25})/); if (x) id = x[1]; }
    const item = tiktokItem(m);
    if (!id && item) {
      const a = item.querySelector('a[href*="/video/"]');
      const x = a && a.getAttribute("href").match(/\/@([^/?#]+)\/video\/(\d{8,25})/);
      if (x) { id = x[2]; author = decodeURIComponent(x[1]); }
    }
    const urlMatch = location.pathname.match(/^\/@([^/]+)\/video\/(\d{8,25})/);
    const main = biggestPlaying(m);
    if (!id && urlMatch && main) { id = urlMatch[2]; author = decodeURIComponent(urlMatch[1]); }
    const overlay = main ? document.querySelector('[data-e2e="anchoring-description-layer"]') : null;
    if (!id && main) {
      const mm = document.querySelector('[data-e2e="more-menu-icon"][data-more-menu-item-id]');
      if (mm && /^\d{8,25}$/.test(mm.getAttribute("data-more-menu-item-id"))) id = mm.getAttribute("data-more-menu-item-id");
    }
    const data = tiktokData(id, wrap);
    const scopes = [item, overlay, main ? document : null].filter(Boolean);
    const first = sel => { for (const sc of scopes) { const t = textOf(sc, sel); if (t) return t; } return ""; };
    const href = sel => {
      for (const sc of scopes) { const a = sc.querySelector(sel); const x = a && a.getAttribute("href").match(/^\/@([^/?#]+)/); if (x) return decodeURIComponent(x[1]); }
      return "";
    };
    author = (data && data.author) || author || href('a[data-e2e="video-author-avatar"][href^="/@"]')
      || first('[data-e2e="video-author-uniqueid"], [data-e2e="browse-username"]') || href('a[href^="/@"]');
    const desc = (data && data.desc) || first('[data-e2e="video-desc"], [data-e2e="browse-video-desc"]');
    const music = (data && data.music) || first('[data-e2e="video-music"], [data-e2e="browse-music"], [data-e2e="browse-music-title"]');
    let cover = (data && data.cover) || (/^https:/.test(m.poster || "") ? m.poster : "");
    if (!cover) {
      const host = item || (wrap && wrap.parentElement);
      const imgs = host ? Array.prototype.filter.call(host.querySelectorAll("picture img, img"),
        i => /tiktokcdn/.test(i.src || "") && !i.closest('[data-e2e*="avatar"], [class*="Avatar"]')) : [];
      cover = imgs.length ? imgs[0].src : "";
    }
    author = author.replace(/^@/, "");
    return {
      videoId: id, author: author, title: desc || music || document.title.replace(/ \| TikTok$/, ""), thumbnail: cover,
      pageUrl: id && author ? "https://www.tiktok.com/@" + encodeURIComponent(author) + "/video/" + id : location.origin + location.pathname,
      live: !isFinite(m.duration) || /^\/@[^/]+\/live/.test(location.pathname), ad: false,
    };
  }
  function payload(m) {
    const d = SITE === "tiktok" ? describeTikTok(m) : describeYouTube(m);
    d.pageUrl = String(d.pageUrl || "").slice(0, 500);
    const out = Object.assign({}, d, {
      tab: TAB, site: SITE,
      position: isFinite(m.currentTime) ? m.currentTime : 0,
      duration: isFinite(m.duration) ? m.duration : 0,
      paused: m.paused || m.ended, rate: m.playbackRate || 1,
      buffering: !m.paused && !m.ended && m.readyState < 3,   // stalled: the mirror must hold, not run ahead
      isVideo: m.tagName === "VIDEO" && m.videoWidth > 0 && !d.artTrack,
      width: m.videoWidth || 0, height: m.videoHeight || 0,
      visible: document.visibilityState === "visible",
      ts: Date.now(),
    });
    delete out.artTrack;
    if (SITE === "tiktok") out.tt = ttState(out.videoId);
    return out;
  }

  // ------------------------------------------------------------------ reporting
  function send() {
    pending = 0;
    const m = pick();
    if (!m) {
      if (reported) request("POST", "/state", JSON.stringify({ tab: TAB, gone: true }));
      reported = false;
      stopTimer();
      return;
    }
    active = m;
    if (Date.now() < downUntil) { syncTimer(m); return; }
    const p = payload(m);
    reported = true;
    request("POST", "/state", JSON.stringify(p), null, (status, r) => {
      const was = pollWanted;
      pollWanted = status === 200 && !!r && r.poll === true && SITE === "tiktok";   // nobody answers (PiP off): go quiet
      if (status === 200 && r && Array.isArray(r.actions)) r.actions.forEach(runAction);
      if (status === 200 && r && r.wantVideo && r.key && !tried.has(r.key) && SITE === "tiktok") {
        tried.add(r.key);
        handOver(r.key, m, p.videoId);
      }
      if (was !== pollWanted) syncTimer(active);
    });
    if (p.videoId !== lastKey) lastKey = p.videoId;
    syncTimer(m);
  }
  function syncTimer(m) {   // every second while it plays; while paused only when the daemon asked for it (TikTok + the PiP is on)
    if (m && ((!m.paused && !m.ended) || pollWanted)) { if (!timer) timer = setInterval(send, 1000); }
    else stopTimer();
  }
  function stopTimer() { if (timer) { clearInterval(timer); timer = 0; } }
  function soon() { if (!pending) pending = setTimeout(send, 150); }

  function onMedia(e) {
    const m = e.target;
    if (!isMedia(m) || isPreview(m)) return;
    if (e.type === "play" || e.type === "playing") active = m;
    soon();
  }
  for (const t of ["play", "playing", "pause", "seeked", "ratechange", "loadedmetadata", "durationchange", "emptied", "ended", "waiting", "stalled", "canplay"])
    document.addEventListener(t, onMedia, true);   // media events do not bubble; capture sees every element, new ones too
  document.addEventListener("visibilitychange", () => { if (reported) soon(); });
  window.addEventListener("yt-navigate-finish", () => { if (reported || pick()) soon(); });
  window.addEventListener("pagehide", () => { if (reported) request("POST", "/state", JSON.stringify({ tab: TAB, gone: true })); });
  if (pick() && !pick().paused) soon();

  // ------------------------------------------------------------------ TikTok: ⏮ / ⏭ (MPRIS previous / next) scroll the feed
  // TikTok registers no media-session track actions, so the browser tells MPRIS CanGoNext=false and the PiP's / media keys'
  // previous / next do nothing. Registering them here makes Zen expose them; they scroll the feed one item, like the wheel does
  // (a synthetic ArrowDown is ignored by TikTok; scrolling the next item into the snap container is what loads and plays it).
  const FEED_ITEM = '[data-e2e="recommend-list-item-container"], article';
  function currentItem() {   // the feed item across the middle of the viewport
    return Array.prototype.find.call(document.querySelectorAll(FEED_ITEM),
      it => { const r = it.getBoundingClientRect(); return r.height > 0 && r.bottom > innerHeight / 2 && r.top < innerHeight / 2; });
  }
  function siblingItem(cur, dir) {
    let to = cur && (dir > 0 ? cur.nextElementSibling : cur.previousElementSibling);
    while (to && !(to.getBoundingClientRect().height > 0)) to = dir > 0 ? to.nextElementSibling : to.previousElementSibling;
    return to;
  }
  function scrollToItem(el, smooth) { el.scrollIntoView({ behavior: smooth ? "smooth" : "instant", block: "start" }); }
  function feedStep(dir) {
    // the logged-in For You feed has its own ˄ / ˅ buttons beside the clip ("Go to previous / next video"; prev is disabled on the
    // first clip): what a click on them does is exactly the step we want
    const nav = document.querySelector(dir > 0 ? '[data-e2e="feed-navigation-next"]' : '[data-e2e="feed-navigation-prev"]');
    const navBtn = nav && (nav.closest('button, [role="button"]') || nav);
    if (navBtn && !navBtn.disabled && navBtn.getAttribute("aria-disabled") !== "true") { navBtn.click(); return; }
    const m = pick();
    const cur = (m && tiktokItem(m)) || currentItem();
    const to = siblingItem(cur, dir);
    if (to) { scrollToItem(to, document.visibilityState === "visible"); return; }
    // no item list (a detail page, another layout): TikTok's own arrow buttons, if any
    const btn = document.querySelector(dir > 0
      ? '[data-e2e="arrow-right"], button[aria-label*="next" i]' : '[data-e2e="arrow-left"], button[aria-label*="previous" i]');
    if (btn && !btn.disabled) btn.click();
  }
  function trackActions() {
    const next = () => feedStep(1), prev = () => feedStep(-1);
    try {   // Firefox content script: the page's own media session, with handlers it may call
      const pageMs = window.wrappedJSObject && window.wrappedJSObject.navigator.mediaSession;
      if (pageMs && typeof exportFunction === "function") {
        pageMs.setActionHandler("nexttrack", exportFunction(next, window));
        pageMs.setActionHandler("previoustrack", exportFunction(prev, window));
        return;
      }
    } catch (e) { /* fall through */ }
    try {
      if (!navigator.mediaSession) return;
      navigator.mediaSession.setActionHandler("nexttrack", next);
      navigator.mediaSession.setActionHandler("previoustrack", prev);
    } catch (e) { /* no media session here */ }
  }
  if (SITE === "tiktok") {
    trackActions();
    document.addEventListener("playing", trackActions, true);   // again after a clip starts, in case the page reset them
    setInterval(watchdog, 1000);
  }

  // ------------------------------------------------------------------ TikTok: un-stick a stalled clip
  // Behind a VPN TikTok's CDN sometimes stops feeding the current clip: it sits frozen / loading, or never starts. Scrolling one
  // item away and back makes TikTok tear the player down and fetch the clip again, which is what un-sticks it by hand. This does
  // that by itself when the clip in view has made no progress for STALL_MS: twice per clip, then it skips to the next clip.
  // A clip the user paused (loaded, not playing) is left alone. Works in a background tab too (you listen from another window).
  const STALL_MS = 7000, GRACE_MS = 6000, BOUNCES = 2;
  const wd = { item: null, t: -1, since: 0, tries: 0, busyUntil: 0 };
  function watchdog() {
    const now = Date.now();
    if (now < wd.busyUntil) return;
    if (acting) { wd.since = now; return; }   // a like / repost / save is clicking this clip's buttons: do not scroll it away
    const cur = currentItem();
    if (!cur) { wd.item = null; return; }
    const v = cur.querySelector("video");
    if (!v) { wd.item = null; return; }   // a photo post (or not mounted yet): nothing to judge
    const t = v.currentTime;
    if (cur !== wd.item) { Object.assign(wd, { item: cur, t: t, since: now, tries: 0 }); return; }
    const userPaused = v.paused && !v.error && v.readyState >= 2;   // a picture is there and it is paused: the user's pause
    if (t !== wd.t || userPaused || v.ended) { wd.t = t; wd.since = now; return; }
    if (now - wd.since < STALL_MS) return;
    wd.tries += 1;
    wd.since = now;
    if (wd.tries > BOUNCES) {          // reloading did not help: move on
      const next = siblingItem(cur, 1);
      if (next) { wd.busyUntil = now + GRACE_MS; scrollToItem(next, false); }
      return;
    }
    const away = siblingItem(cur, -1) || siblingItem(cur, 1);
    if (!away) return;
    const bounce = document.visibilityState === "visible" ? 1200 : 2500;   // a background tab lays out ~1/s: give it time to notice
    wd.busyUntil = now + bounce + GRACE_MS;   // leave the reloaded clip time to start before judging it again
    scrollToItem(away, false);
    setTimeout(() => { if (currentItem() === away) scrollToItem(cur, false); }, bounce);   // unless the user scrolled meanwhile
  }

  // ------------------------------------------------------------------ TikTok: like / repost / save (the PiP's buttons)
  // Logged in, the For You feed shows ONE action column for the current clip ([data-e2e="anchoring-engagement-vertical"]: like-icon,
  // comment-icon, favorite-icon, share-icon, more-menu-icon with data-more-menu-item-id = that clip's id). A command from the daemon
  // names the clip the PiP showed; it runs only while this column belongs to that clip, one at a time, by clicking TikTok's own
  // buttons (TikTok then calls its own API with the user's session; this script never calls it):
  //   like    toggle like-icon; the new state is its aria-pressed
  //   repost  open the share panel, click share-repost ("Repost" / "Remove repost"), close the panel
  //   save    not favourited: favourite, then the toast's "Manage" button, then the named collection in the list, close the list;
  //           favourited: un-favourite (TikTok also takes it out of every collection; there is no "remove from one collection")
  const ACT_WAIT = 4000;      // ms to wait for TikTok's panel / toast / list (a background tab polls about once a second)
  let acting = null;          // {id, action} while a command runs
  let lastDone = null;        // the newest finished command {id, action, ok, error}, reported until a newer one
  const known = new Map();    // clip id -> {saved, savedFlag, reposted}: our own results (TikTok's props can lag behind a click)

  const sleep = ms => new Promise(r => setTimeout(r, ms));
  function waitFor(fn, ms) {   // poll every 100 ms (about 1 s in a background tab) until fn() is truthy or ms passed -> its value / null
    const until = Date.now() + ms;
    return new Promise(res => {
      (function tick() {
        let v = null;
        try { v = fn(); } catch (e) { v = null; }
        if (v) return res(v);
        if (Date.now() >= until) return res(null);
        setTimeout(tick, 100);
      })();
    });
  }
  function actionBar() { return document.querySelector('[data-e2e="anchoring-engagement-vertical"]'); }
  function barClip(bar) {   // the clip the action column belongs to
    let mm = bar ? bar.querySelector("[data-more-menu-item-id]") : null;
    if (!mm && bar) {   // not inside the column: only if the page has exactly one
      const all = document.querySelectorAll('[data-e2e="more-menu-icon"][data-more-menu-item-id]');
      if (all.length === 1) mm = all[0];
    }
    const id = mm ? String(mm.getAttribute("data-more-menu-item-id") || "") : "";
    return /^\d{8,25}$/.test(id) ? id : "";
  }
  function barButton(bar, name) {   // div[role=button][data-e2e=<name>] (or a button around it), inside the column
    const el = bar ? bar.querySelector('[data-e2e="' + name + '"]') : null;
    if (!el) return null;
    const b = el.closest('[role="button"], button');
    return b && bar.contains(b) ? b : el;
  }
  function currentBar(id) { const bar = actionBar(); return bar && barClip(bar) === id ? bar : null; }
  function pressed(el) { const v = el ? el.getAttribute("aria-pressed") : null; return v === "true" ? true : v === "false" ? false : null; }
  function findFlags(obj, id, depth, budget) {   // TikTok's item props: {digged (liked), collected (favourited)}
    if (!obj || typeof obj !== "object" || depth > 3 || budget.n++ > 3000) return null;
    try {
      if (String(obj.id) === id && (typeof obj.digged === "boolean" || typeof obj.collected === "boolean"))
        return { digged: typeof obj.digged === "boolean" ? obj.digged : null, collected: typeof obj.collected === "boolean" ? obj.collected : null };
      for (const k of Object.keys(obj)) {
        if (k === "return" || k === "child" || k === "sibling" || k === "_owner" || k === "stateNode" || k.charAt(0) === "_") continue;
        const r = findFlags(obj[k], id, depth + 1, budget);
        if (r) return r;
      }
    } catch (e) { /* a getter that throws, a dead wrapper */ }
    return null;
  }
  function barFlags(bar, id) {
    try {
      const raw = bar.wrappedJSObject || bar;   // page world (Firefox content scripts)
      const k = Object.keys(raw).find(x => x.indexOf("__reactFiber$") === 0 || x.indexOf("__reactInternalInstance$") === 0);
      let f = k ? raw[k] : null;
      for (let i = 0; f && i < 30; i++, f = f.return) {
        const r = findFlags(f.memoizedProps, id, 0, { n: 0 });
        if (r) return r;
      }
    } catch (e) { /* not React any more */ }
    return null;
  }
  function savedState(bar, id) {   // our own result while TikTok's prop still says what it said then; else TikTok's prop
    const k = known.get(id) || {};
    const flag = (barFlags(bar, id) || {}).collected;
    const f = typeof flag === "boolean" ? flag : null;
    if (typeof k.saved === "boolean" && f === k.savedFlag) return k.saved;
    return f !== null ? f : typeof k.saved === "boolean" ? k.saved : null;
  }
  function ttState(id) {   // what the PiP shows for the reported clip
    const bar = actionBar();
    const clip = barClip(bar);
    const out = { bar: false, clip: clip, liked: null, saved: null, reposted: null, busy: acting ? acting.action : "", last: lastDone };
    if (!bar || !id || clip !== id || !barButton(bar, "like-icon")) return out;
    let liked = pressed(barButton(bar, "like-icon"));
    if (liked === null) { const f = barFlags(bar, id); if (f && typeof f.digged === "boolean") liked = f.digged; }
    const k = known.get(id) || {};
    return Object.assign(out, { bar: true, liked: liked, saved: savedState(bar, id),
      reposted: typeof k.reposted === "boolean" ? k.reposted : null });   // TikTok's item data has no repost flag: only our result
  }
  function remember(id, o) { known.set(id, Object.assign(known.get(id) || {}, o)); if (known.size > 200) known.delete(known.keys().next().value); }

  function finishAction(a, ok, error) {
    lastDone = { id: a.id, action: a.action, ok: !!ok, error: String(error || "").slice(0, 160) };
    if (acting && acting.id === a.id) acting = null;
    if (!pending) pending = setTimeout(send, 50);   // tell the daemon now
  }
  function runAction(a) {
    if (!a || typeof a.id !== "number" || !/^(like|repost|save)$/.test(a.action) || !/^tiktok-\d{8,25}$/.test(String(a.key))) return;
    if ((lastDone && lastDone.id === a.id) || (acting && acting.id === a.id)) return;   // handed over twice
    if (acting) return finishAction(a, false, "busy with the last " + acting.action);
    const id = a.key.slice(7);
    const bar = actionBar();
    if (!bar || !barButton(bar, "like-icon")) return finishAction(a, false, "TikTok shows no like / save buttons here (logged out?)");
    if (barClip(bar) !== id) return finishAction(a, false, "refused: TikTok shows another clip now");
    acting = { id: a.id, action: a.action };
    if (!pending) pending = setTimeout(send, 50);   // report "busy" at once
    const run = a.action === "like" ? doLike : a.action === "repost" ? doRepost : doSave;
    let r;
    try { r = run(bar, id, a); } catch (e) { r = Promise.reject(e); }
    Promise.resolve(r).then(res => finishAction(a, res.ok, res.error),
      e => finishAction(a, false, "error: " + String((e && e.message) || e)));
  }

  async function doLike(bar, id) {
    const btn = barButton(bar, "like-icon");
    const before = pressed(btn);
    btn.click();
    if (before === null) { await sleep(500); return { ok: true, error: "" }; }   // no aria-pressed: the state comes from TikTok's props
    const after = await waitFor(() => { const b = currentBar(id); const v = b ? pressed(barButton(b, "like-icon")) : null; return v !== null && v !== before; }, ACT_WAIT);
    return after ? { ok: true, error: "" } : { ok: false, error: "TikTok did not toggle the like (logged out?)" };
  }

  function escapeKey() {   // what closes TikTok's panels and pop-overs by hand
    const t = document.activeElement && document.activeElement !== document.documentElement ? document.activeElement : document.body;
    for (const type of ["keydown", "keyup"])
      t.dispatchEvent(new KeyboardEvent(type, { key: "Escape", code: "Escape", keyCode: 27, which: 27, bubbles: true, cancelable: true, composed: true }));
  }
  function closeNear(el) {   // a [aria-label="close"] in the panel around el
    for (let p = el, i = 0; p && p !== document.body && i < 10; p = p.parentElement, i++) {
      const x = p.querySelector('[aria-label="close" i], [aria-label="Close" i]');
      if (x) { x.click(); return true; }
    }
    return false;
  }
  async function closeShare(share) {
    const panel = () => document.querySelector('[data-e2e="share-repost"]');
    const open = () => (share.isConnected && share.getAttribute("aria-expanded") === "true") || !!panel();
    if (!open()) return true;
    escapeKey();
    if (await waitFor(() => !open(), 800)) return true;
    const rp = panel();
    if (rp && closeNear(rp) && await waitFor(() => !open(), 800)) return true;
    if (share.isConnected && share.getAttribute("aria-expanded") === "true") share.click();   // the share button toggles it
    return !!(await waitFor(() => !open(), 1200));
  }
  async function doRepost(bar, id) {
    const share = barButton(bar, "share-icon");
    if (!share) return { ok: false, error: "TikTok shows no share button here" };
    if (share.getAttribute("aria-expanded") !== "true") share.click();
    const rp = await waitFor(() => document.querySelector('[data-e2e="share-repost"]'), ACT_WAIT);
    if (!rp) { await closeShare(share); return { ok: false, error: "the share panel has no Repost button" }; }
    const text = (rp.textContent || "").trim().replace(/\s+/g, " ");
    const was = /^remove repost/i.test(text) ? true : /^repost/i.test(text) ? false : null;
    if (was === null) { await closeShare(share); return { ok: false, error: "unknown repost button: " + text.slice(0, 40) }; }
    if (!currentBar(id)) { await closeShare(share); return { ok: false, error: "refused: the clip changed" }; }
    rp.click();
    remember(id, { reposted: !was });
    await sleep(300);
    const closed = await closeShare(share);
    return { ok: true, error: closed ? "" : "reposting worked, but the share panel stayed open" };
  }

  function collectionName(el) {   // "Edits 395 videos" -> "Edits"
    const t = String(el.innerText || el.textContent || "").replace(/\s+/g, " ").trim();
    return t.replace(/\s+[\d.,]+\s*[KkMm]?\s+(videos?|posts?)$/i, "").trim();
  }
  function manageButton() {
    return Array.prototype.find.call(document.querySelectorAll('button, [role="button"]'), b => (b.textContent || "").trim() === "Manage");
  }
  function collectionList() {   // the open pop-over with collection-<id> items
    const open = Array.prototype.filter.call(document.querySelectorAll('[role="dialog"]'), d => d.querySelector('[data-e2e^="collection-"]'));
    return open.find(d => /TUXPopover-popover--open/.test(d.className || "")) || open[0] || null;
  }
  async function closeList(list) {
    const isOpen = () => list.isConnected && /TUXPopover-popover--open/.test(list.className || "") && !!list.querySelector('[data-e2e^="collection-"]');
    if (!isOpen()) return true;
    escapeKey();
    if (await waitFor(() => !isOpen(), 800)) return true;
    if (closeNear(list.querySelector('[data-e2e^="collection-"]')) && await waitFor(() => !isOpen(), 800)) return true;
    for (const type of ["pointerdown", "mousedown", "mouseup", "click"])   // a click outside closes a pop-over
      document.body.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, clientX: 1, clientY: 1 }));
    return !!(await waitFor(() => !isOpen(), 800));
  }
  async function doSave(bar, id, a) {
    const fav = barButton(bar, "favorite-icon");
    if (!fav) return { ok: false, error: "TikTok shows no Favorites button here" };
    const was = savedState(bar, id);
    if (was === null) return { ok: false, error: "cannot tell whether it is saved: nothing done" };
    const flag = (barFlags(bar, id) || {}).collected;
    const f = typeof flag === "boolean" ? flag : null;
    fav.click();
    remember(id, { saved: !was, savedFlag: f });
    if (was) { await sleep(400); return { ok: true, error: "" }; }   // un-favourited: TikTok takes it out of its collections too
    const name = String(a.collection || "Edits").trim() || "Edits";
    const manage = await waitFor(manageButton, ACT_WAIT);
    if (!manage) return { ok: false, error: "saved to Favorites only (TikTok showed no Manage button)" };
    manage.click();
    const list = await waitFor(collectionList, ACT_WAIT);
    if (!list) return { ok: false, error: "saved to Favorites only (the collection list did not open)" };
    const items = Array.prototype.filter.call(list.querySelectorAll('[data-e2e^="collection-"]'),
      e => /^collection-\d+$/.test(e.getAttribute("data-e2e")));
    const item = items.find(e => collectionName(e).toLowerCase() === name.toLowerCase());
    if (!item) { await closeList(list); return { ok: false, error: 'saved to Favorites only: no collection named "' + name + '"' }; }
    const before = String(item.innerText || item.textContent || "");
    item.click();
    await waitFor(() => !item.isConnected || String(item.innerText || item.textContent || "") !== before
      || !/TUXPopover-popover--open/.test(list.className || ""), 2000);   // the count goes up (or the list closes by itself)
    const closed = await closeList(list);
    return { ok: true, error: closed ? "" : "saved, but the collection list stayed open" };
  }

  // ------------------------------------------------------------------ TikTok: hand the clip's file to the daemon
  function candidates(m, id) {
    const out = [];
    const add = u => {
      if (!u || typeof u !== "string" || u.indexOf("https://") !== 0) return;   // no blob:, no "" (that would resolve to the page itself)
      try {
        const x = new URL(u);
        // www.tiktok.com serves pages; only its /aweme/ play path is a file
        if (/(^|\.)www\.tiktok\.com$/.test(x.hostname) && x.pathname.indexOf("/aweme/") !== 0) return;
        if (VIDEO_HOSTS.test(x.hostname) && out.indexOf(x.href) < 0) out.push(x.href);
      } catch (e) { /* not a URL */ }
    };
    add(m.currentSrc); add(m.src);    // a plain file on older layouts; blob: on the 2026 feed (skipped by add)
    m.querySelectorAll("source[src]").forEach(s => add(s.src));
    const d = tiktokData(id, m.closest('[id^="xgwrapper-"]'));
    if (d) d.urls.forEach(add);
    return out;
  }
  function detailUrls(id, done) {   // last resort: TikTok's own item API with this tab's cookies
    GM_xmlhttpRequest({
      method: "GET", url: "https://www.tiktok.com/api/item/detail/?aid=1988&itemId=" + id, responseType: "json", anonymous: false, timeout: 15000,
      headers: { Referer: location.href },
      onload: r => {
        try {
          const v = r.response.itemInfo.itemStruct.video;
          done([v.playAddr, v.downloadAddr].filter(u => typeof u === "string" && u));
        } catch (e) { done([]); }
      },
      onerror: () => done([]), ontimeout: () => done([]),
    });
  }
  function handOver(key, m, id) {
    const fail = why => { tried.delete(key); request("POST", "/video-error/" + key, JSON.stringify({ reason: why })); };
    const allowed = u => { try { const x = new URL(u); return x.protocol === "https:" && VIDEO_HOSTS.test(x.hostname); } catch (e) { return false; } };
    const own = candidates(m, id);
    if (own.length) fetchFirst(own, 0);
    else detailUrls(id, urls => fetchFirst(urls.filter(allowed), 0));

    function fetchFirst(urls, i) {   // the file URLs need this tab's cookies (tt_chain_token) and a tiktok.com Referer
      if (!urls.length) return fail(String(m.currentSrc || "").indexOf("blob:") === 0 ? "the page streams it (blob:) and its item data has no file URL" : "no file URL");
      if (i >= urls.length) return fail("TikTok refused the file");
      let aborted = false;
      const req = GM_xmlhttpRequest({
        method: "GET", url: urls[i], responseType: "blob", anonymous: false, timeout: 60000,
        headers: { Referer: "https://www.tiktok.com/" },
        onprogress: ev => {
          if (ev.loaded > UPLOAD_CAP && !aborted) { aborted = true; try { req.abort(); } catch (e) { /* gone */ } fail("larger than 60 MB"); }
        },
        onload: r => {
          if (aborted) return;
          const blob = r.response;
          if (r.status >= 200 && r.status < 300 && blob && blob.size > 1024 && blob.size <= UPLOAD_CAP)
            request("POST", "/video/" + key, blob, "video/mp4", status => { if (status !== 200) tried.delete(key); });
          else fetchFirst(urls, i + 1);
        },
        onerror: () => { if (!aborted) fetchFirst(urls, i + 1); },
        ontimeout: () => { if (!aborted) fetchFirst(urls, i + 1); },
      });
    }
  }
})();
