// ==UserScript==
// @name         YouTube → MPRIS position (Overworld boss bar)
// @namespace    overworld-hyprland
// @version      1.0.0
// @description  YouTube / YouTube Music in Firefox/Zen report title+artist over MPRIS but no length and position 0. This feeds the real <video> duration/position into navigator.mediaSession.setPositionState, which Firefox exports as MPRIS Position + mpris:length — so desktop progress bars (Overworld's Now Playing boss bar, playerctl position) follow the song, including seeks.
// @match        https://www.youtube.com/*
// @match        https://music.youtube.com/*
// @grant        none
// @inject-into  page
// @run-at       document-idle
// ==/UserScript==

(function () {
  "use strict";
  if (!("mediaSession" in navigator) || typeof navigator.mediaSession.setPositionState !== "function") return;

  let video = null;
  let last = 0;

  function push(force) {
    if (!video) return;
    const d = video.duration;
    if (!isFinite(d) || d <= 0) return;             // live streams / not loaded yet
    const now = performance.now();
    if (!force && now - last < 1000) return;         // timeupdate fires ~4×/s; once a second is plenty
    last = now;
    try {
      navigator.mediaSession.setPositionState({
        duration: d,
        playbackRate: video.playbackRate || 1,
        position: Math.min(Math.max(0, video.currentTime), d),
      });
    } catch (e) { /* position > duration during a track change — ignore, next tick fixes it */ }
  }

  const onTime = () => push(false);
  const onJump = () => push(true);

  function attach(v) {
    if (v === video) return;
    if (video) {
      video.removeEventListener("timeupdate", onTime);
      for (const ev of ["seeked", "ratechange", "loadedmetadata", "durationchange", "play", "pause"])
        video.removeEventListener(ev, onJump);
    }
    video = v;
    video.addEventListener("timeupdate", onTime);
    for (const ev of ["seeked", "ratechange", "loadedmetadata", "durationchange", "play", "pause"])
      video.addEventListener(ev, onJump);
    push(true);
  }

  // YouTube is a single-page app and swaps/creates the <video> element; keep looking for the main one.
  function scan() {
    const v = document.querySelector("video.html5-main-video, video");
    if (v) attach(v);
  }
  scan();
  let pending = false;   // YouTube mutates the DOM constantly: rescan at most twice a second
  new MutationObserver(() => {
    if (pending) return;
    pending = true;
    setTimeout(() => { pending = false; scan(); }, 500);
  }).observe(document.documentElement, { childList: true, subtree: true });
  window.addEventListener("yt-navigate-finish", () => { scan(); push(true); });
})();
