// Loaded before the userscript: a stub GM_xmlhttpRequest that records calls and answers like the daemon / TikTok's CDN,
// helpers to fake playing media elements, and a step runner that writes the results into <pre id="out">.
window.__calls = [];
// a running setInterval keeps headless Chromium from ever dumping the DOM: remember them, finish() clears them
window.__intervals = [];
const __setInterval = window.setInterval.bind(window);
window.setInterval = (f, ms) => { const id = __setInterval(f, ms); window.__intervals.push(id); return id; };
window.__done = false;
window.__wantVideo = false;
window.__actionQueue = [];   // TikTok commands for the next /state reply (like the daemon: handed out once)
window.__poll = false;       // the daemon's "poll" (a TikTok tab while the PiP is on): keep reporting while paused
function GM_xmlhttpRequest(o) {
  if (window.__done) return { abort() {} };
  let data = o.data;
  if (data && typeof data !== "string") data = "[binary " + (data.size || data.byteLength || 0) + "]";
  window.__calls.push({ method: o.method, url: o.url, headers: o.headers || {}, data: data, responseType: o.responseType, anonymous: o.anonymous });
  setTimeout(() => {
    let r = { status: 200, response: { ok: true } };
    if (/\/state$/.test(o.url)) {
      let key = "";
      try { const d = JSON.parse(o.data); key = d.videoId ? (d.site === "tiktok" ? "tiktok-" : "youtube-") + d.videoId : ""; } catch (e) {}
      const tt = /^tiktok-/.test(key);
      r.response = { ok: true, key: key, wantVideo: window.__wantVideo && tt, actions: tt ? window.__actionQueue.splice(0) : [], poll: window.__poll && tt };
    } else if (o.method === "GET" && /video_slow|v16-webapp-prime/.test(o.url)) {
      r = { status: /bad/.test(o.url) ? 403 : 200, response: new Blob([new Uint8Array(4096)], { type: "video/mp4" }) };
    }
    if (o.onload) o.onload(r);
  }, 5);
  return { abort() {} };
}
function fakeMedia(v, o) {
  const st = Object.assign({ paused: false, readyState: 4, currentTime: 12.5, duration: 30, videoWidth: 1280, videoHeight: 720,
                             currentSrc: "blob:https://example/1", playbackRate: 1, muted: false, ended: false }, o || {});
  for (const k of Object.keys(st)) Object.defineProperty(v, k, { configurable: true, get: () => st[k], set: x => { st[k] = x; } });
  v.__st = st;
  return st;
}
function fire(v, type) { v.dispatchEvent(new Event(type)); }
function finish(extra) {
  window.__done = true;
  window.__intervals.forEach(id => clearInterval(id));
  const out = document.getElementById("out") || document.body.appendChild(document.createElement("pre"));
  out.id = "out";
  window.__result = JSON.stringify({ calls: window.__calls, extra: extra || {} });
  out.textContent = window.__result;
}

// ------------------------------------------------------------------ the logged-in TikTok page (fixture for like / repost / save)
// Reproduces what was seen on the real page (2026-11-10): one action column [data-e2e="anchoring-engagement-vertical"] for the
// current clip (like-icon with aria-pressed, favorite-icon without, share-icon with aria-expanded, more-menu-icon with the clip id),
// React props with {id, digged, collected}, the "Manage" toast after favouriting, the collection pop-over
// (div[role=dialog].TUXPopover-popover--open, collection-<id> items "<name> <n> videos"), the share panel with share-repost
// ("Repost" / "Remove repost"). The handlers change state like TikTok does; window.__tt records every click and "API call".
function fakeTikTok(o) {
  o = Object.assign({ clip: "7400000000000000002", liked: false, collected: false, reposted: false, delay: 150, toast: true,
    escCloses: true, staleProps: false,
    collections: [["7264957855126899462", "Edits", 395], ["7264957855126899463", "Edits old", 12], ["7264957855126899464", "Recipes", 3]] }, o || {});
  const S = window.__tt = { clicks: [], clickAt: [], delay: o.delay, api: [], liked: o.liked, collected: o.collected, reposted: o.reposted, toast: o.toast,
    escCloses: o.escCloses, colls: o.collections.map(c => ({ id: c[0], name: c[1], n: c[2] })), inColl: new Set() };
  const $ = sel => document.querySelector(sel);
  const bar = $('[data-e2e="anchoring-engagement-vertical"]');
  const portal = document.body.appendChild(document.createElement("div"));
  const later = f => setTimeout(f, S.delay);
  const frozen = { digged: o.liked, collected: o.collected };
  const item = { id: o.clip, desc: "x",
    get digged() { return o.staleProps ? frozen.digged : S.liked; }, get collected() { return o.staleProps ? frozen.collected : S.collected; } };
  bar.__reactFiber$fake = { memoizedProps: { className: "x" }, return: { memoizedProps: { item: item, index: 1 }, return: null } };
  S.setClip = id => { $('[data-e2e="more-menu-icon"]').setAttribute("data-more-menu-item-id", id); item.id = id; };
  const like = bar.querySelector('[data-e2e="like-icon"]'), fav = bar.querySelector('[data-e2e="favorite-icon"]'), share = bar.querySelector('[data-e2e="share-icon"]');
  like.setAttribute("aria-pressed", String(!!o.liked));
  const origPush = S.clicks.push.bind(S.clicks);
  S.clicks.push = what => { S.clickAt.push({ what: what, t: Date.now() }); return origPush(what); };
  like.addEventListener("click", () => {
    S.clicks.push("like");
    later(() => { S.liked = !S.liked; like.setAttribute("aria-pressed", String(S.liked)); S.api.push("digg " + (S.liked ? 1 : 0)); });
  });
  function toast(html) {
    const t = portal.appendChild(document.createElement("div"));
    t.className = "toast"; t.innerHTML = html;
    setTimeout(() => t.remove(), 3000);
    return t;
  }
  fav.addEventListener("click", () => {
    S.clicks.push("favorite");
    later(() => {
      S.collected = !S.collected;
      S.api.push("collect action=" + (S.collected ? 1 : 2));
      if (!S.collected) { S.colls.forEach(c => { if (S.inColl.has(c.id)) c.n--; }); S.inColl.clear(); return; }
      if (S.toast) toast('<span>Added to Favorites</span><button type="button">Manage</button>').querySelector("button").addEventListener("click", () => {
        S.clicks.push("manage");
        later(openList);
      });
    });
  });
  function openList() {
    const d = portal.appendChild(document.createElement("div"));
    d.setAttribute("role", "dialog"); d.className = "TUXPopover-popover TUXPopover-popover--open"; d.id = "colllist";
    d.innerHTML = S.colls.map(c => '<div data-e2e="collection-' + c.id + '"><div class="n">' + c.name + '</div><div class="c">' + c.n + ' videos</div></div>').join("")
      + '<div data-e2e="collection-action-create">Create new collection</div>';
    S.colls.forEach(c => d.querySelector('[data-e2e="collection-' + c.id + '"]').addEventListener("click", ev => {
      S.clicks.push("collection " + c.name);
      later(() => {
        S.inColl.add(c.id); c.n++; S.api.push("modify_items collectionId=" + c.id);
        const el = d.querySelector('[data-e2e="collection-' + c.id + '"] .c'); if (el) el.textContent = c.n + " videos";
      });
    }));
    d.querySelector('[data-e2e="collection-action-create"]').addEventListener("click", () => S.clicks.push("create collection"));
  }
  share.addEventListener("click", () => {
    S.clicks.push("share");
    if (share.getAttribute("aria-expanded") === "true") { closePanel(); return; }
    later(() => {
      share.setAttribute("aria-expanded", "true");
      const p = portal.appendChild(document.createElement("div"));
      p.id = "sharepanel";
      p.innerHTML = '<div><div data-e2e="share-repost"><span>' + (S.reposted ? "Remove repost" : "Repost") + '</span></div></div><div aria-label="close">x</div>';
      p.querySelector('[data-e2e="share-repost"]').addEventListener("click", () => {
        S.clicks.push("repost");
        later(() => { S.reposted = !S.reposted; S.api.push(S.reposted ? "repost" : "repost delete"); toast(S.reposted ? "Reposted" : "Repost removed"); });
      });
      p.querySelector('[aria-label="close"]').addEventListener("click", () => { S.clicks.push("panel close"); closePanel(); });
    });
  });
  function closePanel() { const p = $("#sharepanel"); if (p) p.remove(); share.setAttribute("aria-expanded", "false"); }
  document.addEventListener("keydown", e => {
    if (e.key !== "Escape") return;
    S.clicks.push("escape");
    if (!S.escCloses) return;
    closePanel();
    const d = $("#colllist"); if (d) d.remove();
  });
  S.panelOpen = () => !!$("#sharepanel") || share.getAttribute("aria-expanded") === "true";
  S.listOpen = () => !!$("#colllist");
  S.snap = () => ({ clicks: S.clicks.slice(), api: S.api.slice(), liked: S.liked, collected: S.collected, reposted: S.reposted,
    panel: S.panelOpen(), list: S.listOpen(), edits: S.colls[0].n, inEdits: S.inColl.has(S.colls[0].id) });
  return S;
}
const TT_BAR = '<div data-e2e="anchoring-engagement-vertical">'
  + '<div role="button" data-e2e="like-icon" data-key-interaction="action_like" aria-pressed="false" aria-label="Like video\n9836 likes"></div>'
  + '<div role="button" data-e2e="comment-icon"></div>'
  + '<div role="button" data-e2e="favorite-icon" data-key-interaction="action_favorite" aria-label="Add to Favorites. 2374 added to Favorites"></div>'
  + '<div role="button" data-e2e="share-icon" aria-expanded="false"></div>'
  + '<button data-e2e="more-menu-icon" data-more-menu-item-id="7400000000000000002"></button></div>';
// helpers for the step scripts
function reports() { return window.__calls.filter(c => /\/state$/.test(c.url)).map(c => { try { return JSON.parse(c.data); } catch (e) { return {}; } }); }
function untilP(fn, ms) {
  return new Promise(res => { const t0 = Date.now(); (function tick() { let v = null; try { v = fn(); } catch (e) {} if (v) return res(v); if (Date.now() - t0 > ms) return res(null); setTimeout(tick, 50); })(); });
}
const waitMs = ms => new Promise(r => setTimeout(r, ms));
function resultOf(id) { return reports().find(x => x.tt && x.tt.last && x.tt.last.id === id) || null; }
async function ttAct(id, action, extra) {   // hand a command to the tab, wait for its result report; -> {last, tt, dom, ms}
  const t0 = Date.now();
  window.__actionQueue.push(Object.assign({ id: id, key: "tiktok-7400000000000000002", action: action, collection: "Edits" }, extra || {}));
  const r = await untilP(() => resultOf(id), 12000);
  await waitMs(250);   // let the fake page settle (toasts, panels)
  const first = window.__tt ? window.__tt.clickAt.find(c => c.t >= t0) : null;   // when the tab acted on it
  return { last: r ? r.tt.last : null, tt: r ? r.tt : null, dom: window.__tt ? window.__tt.snap() : null, ms: Date.now() - t0,
           firstClickMs: first ? first.t - t0 : -1 };
}
