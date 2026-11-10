# now-playing-pip report — the floating Now Playing mini-player (Overworld) + the shared bridge

2026-11-10. The user was at the desk: no dev-shot/grim, no workspace switch, no on-screen windows, no theme switch, no sound,
no commits, no sudo, no player control. Visual checks are offscreen renders, all viewed. **The PiP is OFF on the live desktop**
(`~/.config/overworld/nowplaying.json` does not exist yet; `qs -c overworld ipc call nowplaying status` → `off, daemon stopped, nothing playing`).

## Delivered

| what | where |
|---|---|
| Shared daemon/CLI (Python stdlib): `serve` (127.0.0.1, token + Host check, `/state`, `/video/<key>`, `/video-error/<key>`, `/want`, `/ping`), `status [--json]`, `userscript [--serve] [--print]`, `cache [list\|clear]`, `want`, `init`, `path`, `help`. State file in place, yt-dlp worker (one job, newest wins, 5 min timeout, `--match-filter` for live/too long), LRU, flock single instance, PR_SET_PDEATHSIG, `--stdin` control with EOF = exit | `scripts/hypr-nowplaying`, `~/.local/bin/hypr-nowplaying` (symlink, made by hand; install.sh does it from now on) |
| Token (created now with `hypr-nowplaying init`, 0600 in a 0700 dir) | `~/.local/share/hypr-nowplaying/token` (never in the repo) |
| Zen bridge userscript (template: idle without a baked token) | `apps/zen/nowplaying-bridge.user.js` |
| Service: MPRIS + bridge merge, daemon as child only while on, persisted on/off + per-monitor positions, auto-hide, source-fullscreen hide, controls, focus | `quickshell/NowPlaying/NowPlayingService.qml` |
| Surface: full-screen Overlay layer with input mask = the player (whole monitor while dragging/resizing), edge-anchored position | `quickshell/NowPlaying/NowPlayingPip.qml` |
| Look: McPanel + oak painting frame + picture (mirror video over a thumbnail with blurred letterbox), XP-bar progress, title / glyph + artist / time, hover ⏮ ⏯ ⏭ 󰏌 ✕, stepped resize grip, Paused/Stopped dim, LIVE/Ad badges, "Fetching video…" | `quickshell/NowPlaying/NowPlayingView.qml` |
| Mirror: MediaPlayer with `audioOutput: null` + VideoOutput, steered by `sync.js` | `quickshell/NowPlaying/VideoMirror.qml`, `sync.js` |
| IPC target `nowplaying`: `toggle on off status reveal reset` | `quickshell/NowPlaying/NowPlayingIpc.qml` |
| Wiring | `quickshell/shell.qml` (`NowPlayingPip {}`), `quickshell/Bar/WidgetsMenu.qml` (row "Now Playing PiP", painting icon), `quickshell/Services/ConfigService.qml` (defaults `nowplaying.*`) |
| CLI `overworld nowplaying on\|off\|toggle\|status\|reveal\|reset\|userscript\|cache\|bridge` + `overworld help nowplaying` (on/off edit the state file when the shell is down) | `scripts/overworld` |
| Keybind SUPER+ALT+P → `$qs nowplaying toggle` | `hypr/keybinds.conf` |
| Layer rule `overworld-nowplaying`: blur off, ignore_alpha 0 (after the catch-all, which gives no_anim) | `hypr/decorations.conf` |
| install / uninstall: link + `init`; uninstall hands the link to Apothecary's copy if there is one, keeps the token | `scripts/install.sh`, `scripts/uninstall.sh` |
| Tests | `tests/hypr-nowplaying.test.sh`, `tests/nowplaying-service.test.sh`, `tests/nowplaying-sync.test.js`, `tests/nowplaying-bridge.test.sh` + `tests/nowplaying-bridge/` (headless Chromium), `quickshell/NowPlaying/preview/{mirror-test,render,service-test}.qml` |
| Docs | `docs/NOWPLAYING.md` (new), `docs/WIDGETS.md`, `docs/QUICKSHELL.md`, `docs/KEYBINDS.md`, `README.md` (feature, CLI table, config table, IPC targets), `CHANGELOG.md` |

## Decisions
- **Zen's MPRIS has `xesam:url`** (verified with `playerctl metadata`: the full watch URL) and a local `mpris:artUrl` copy of the
  artwork, contrary to the brief's fact sheet. So YouTube works **without** the new userscript: the service takes the id from the URL,
  sends `want` to the daemon over stdin, and steers by MPRIS position (exact thanks to the existing `youtube-mpris-position.user.js`).
  Seen live in the service test: the user's real track went `fetching` → `ready` (into a temp cache, since deleted).
- **TikTok (research, 2026)**: the feed `<video>` is a `blob:` MediaSource stream, no `<source>`, no poster; each sits in
  `div#xgwrapper-<n>-<id>`. The clip's URL comes from the page JSON (`webapp.video-detail`, `webapp.updated-items`) or the React props of
  the player element (read through `wrappedJSObject` from the content world), lightest bitrate first, else TikTok's
  `/api/item/detail/` with the tab's cookies. The CDN wants the `tt_chain_token` cookie **and** a tiktok.com Referer (tested by the
  research agent: every other combination 403s), hence `anonymous: false` + Referer. Feed desc/author come from the
  `anchoring-description-layer` overlay for the main video; cover from `picture img` (avatars skipped).
- **`@inject-into content`**: the userscript runs in the isolated world so page scripts cannot hook it to read the token.
- **Transport is light**: media events are caught at `document` in the capture phase (they do not bubble), a 1 s interval runs only while
  something plays, a paused tab reports once (the daemon keeps a paused tab 30 min, a playing one 5 s), `gone` on pagehide, 15 s back-off
  when the daemon is down. YouTube's muted hover previews are ignored.
- **Daemon decisions on a report**: nothing is decided during an ad, before the picture has loaded, or for audio-only (so an ad never marks
  a video "skipped"); live/too long → `skipped`; TikTok → `wantVideo` (once per key, retried after 10 min if failed); YouTube → yt-dlp.
  Uploads are accepted only for keys it asked for, checked for an mp4/webm signature, written to a temp file in the cache and renamed.
- **`videos` map in the state file** (not only the current key), so the shell can find a video it asked for over MPRIS while the bridge
  reports something else.
- **Merge rule**: a playing browser report wins (it has the picture); else MusicService's player (Spotify-first as on the Jukebox), merged
  with the bridge when it is the browser and the titles match (static fields from the bridge, the clock from MPRIS when the report is
  stale or disagrees on paused); else a paused report. A playing report older than 3.5 s is stale.
- **Sync**: 0.12–0.35 s drift = ±5 % rate nudge, > 0.35 s = seek with an 80 ms lead, cooldown 2 s doubling to 8 s when seeks do not hold,
  never while buffering, exact-frame seek when paused, hold the last frame when the browser is past the mirror's end, free run on a stale clock.
- **No audio by construction**: `audioOutput: null` (not just muted): no PipeWire stream is even created. YouTube downloads are video-only anyway.
- **Placement**: a full-screen Overlay surface with an input mask (the widget layer's pattern, so dragging is smooth and the fast-drag
  trick works) rather than a small surface moved by margins. Position is stored as distances from the nearest two edges (per monitor), so a
  portrait clip replacing a landscape one grows away from the corner. Default: bottom-right, 6 GUI px from the edge, above the HUD's 40 GUI px.
  It covers the bottom of the right card column (Sign) there; the cards are on the bottom layer, so that is expected.
- **One monitor**: the focused one when it appears; `reveal` moves it to the focused monitor.
- **"All widgets" and the chip's middle-click do not include the PiP** (it is an overlay, not a desk card), and its on/off is its own file
  `~/.config/overworld/nowplaying.json` rather than `widgets-hidden.json`, because its default is the opposite (off).
- **Dim** to 72 % when paused or stopped (60 % made Day text too faint in the renders), full on hover.
- **Keybind SUPER+ALT+P**: free in `hyprctl binds -j`; JaKooLit has it only commented out (passthru submap). No `hyprctl reload` from me:
  Hyprland picked the file change up itself; `hyprctl configerrors` empty, the bind is listed.
- **Layer rule**: Hyprland has no opacity rule for layers, and `decoration:active_opacity` only applies to windows, so the video is at full
  opacity by construction; the rule turns blur off (`ignore_alpha 0`); the catch-all's `no_anim` stays (the fade is in QML).
- Config keys added to `ConfigService.defaults` (`nowplaying.*`), plus `nowplaying.video` (false = no downloads).

## Independent review (fresh read-only reviewer, then fixed, each with a regression test where testable)
12 findings, none high; all fixed:
1. *Browser buffering made the mirror seek every 2 s* (the report said "playing" while YouTube stalled) → the userscript reports
   `buffering` (and listens to `waiting`/`stalled`/`canplay`), the service turns a buffering clock into a paused one.
2. *A paused tab of a browser that quit stayed "Paused" for 30 min* → a paused report counts only while a browser MPRIS player exists.
3. *"skipped" was final* (one report with a stale 1 h duration during YouTube navigation would block a short video forever) → a skip
   from a report is soft and re-judged on the next report; yt-dlp's own skip is retried after an hour; the label now also says "or larger than 300 MB".
4. *yt-dlp could outlive the daemon* (own session) → `PR_SET_PDEATHSIG` in the child, and killed in the daemon's `finally`.
5. *Restart vs the single-instance lock* (old instance still exiting) → `serve` waits up to 3 s for the lock; the shell retries exit 3 after 2 s twice, then 30 s.
6. *ffprobe under the daemon lock* → probes in a background thread.
7. *A failed TikTok hand-over was never retried in the same page* → the key leaves `tried` on failure / non-200 / network error.
8. *The fetch worker could die on an exception* (stuck "fetching") → loop body guarded; failure recorded.
9. *Ad flag from the first player on the page* → `m.closest(".html5-video-player")`.
10. *`userscript --serve` served the token at a guessable URL* → a random path.
11. *An empty token file crashed `serve`* → replaced via temp file + rename.
12. *No socket timeout* → 30 s.
Also from the review: the mirror's "did the seek hold" check now waits ≥ 0.9 s, and it steers at once only when the browser's
clock really changed (paused / rate / validity / a jump > 0.25 s), not on every service update.
My own headless browser test then found one more real bug: **an element without `src` made `new URL("", page)` resolve to the page
itself, so on TikTok the "clip" fetched would have been the For You page**; now only `https://` file hosts (and `www.tiktok.com/aweme/…`) count.

## Verified (and how)
- **Daemon/CLI** `bash tests/hypr-nowplaying.test.sh` → **95 passed, 0 failed** (after the review fixes): token file modes,
  403 without/with a wrong token, foreign Host, OPTIONS preflight, bad JSON / unknown site / oversized body 400, sanitising (thumbnail host,
  page URL scheme, control chars, clamps, bad ids), in-place rewrite (same inode), tab choice (playing beats paused, newest playing wins,
  `gone`, 5 s expiry), TikTok path (409 before asked, wantVideo, bad token, bad key, junk refused and not left in the cache, accepted upload →
  ready, not asked again, video-error, live skipped, 413 oversize), yt-dlp worker with a fake yt-dlp (ready, canonical URL only, no second
  download, newest request wins and the superseded job leaves nothing, failure reason, no immediate retry), LRU at start-up and after an upload
  (oldest first, new kept, ≤ cap), single instance exit 3, SIGTERM writes a stopped state and removes the pid file, `--stdin` EOF exits,
  **PR_SET_PDEATHSIG** (killing the parent kills it); and the fixes: empty token file replaced, the install URL has a random path
  (guessable path 404, real one serves the token), buffering passes through, a soft "too long" re-judged and fetched, the worker
  survives an exception and keeps working, a restart overlapping the old instance gets the lock, **yt-dlp dies with a SIGKILLed daemon**.
  `NP_REAL=1` → **99 passed** (also after the fixes).
- **Real YouTube fetch** (`NP_REAL=1`, "Me at the zoo", into the temp cache): ffprobe `h264, 240p, no audio stream`, 424 KB, `ffmpeg -f null`
  decodes cleanly.
- **Real mirror playback in qs** (`preview/mirror-test.qml`, offscreen, the real MediaPlayer + FFmpeg/VA-API, no audio output): **10 PASS, 0 FAIL**:
  loaded and playing, `audioOutput === null`, in sync after start (7.93 vs 8.00 s), follows a browser seek (14.00 vs 14.00), pauses on the
  exact frame (9.500), follows 1.5× and stays in sync (7.20 vs 7.25).
- **The userscript in a real browser engine** `bash tests/nowplaying-bridge.test.sh` → **33 passed, 0 failed**: headless Chromium
  (no window, muted, every host name unresolvable) driven over the DevTools protocol, synthetic pages, stub `GM_xmlhttpRequest`:
  YouTube picks the main player over a muted hover preview, id / mediaSession title / author / hqdefault thumbnail / clean page URL /
  every field, only 127.0.0.1 with the token, 1 Hz while playing, buffering reported and cleared, pause reported then **silence while
  paused**, ad flagged; YouTube Music art track = not a video, biggest cover; TikTok feed with three items picks the playing visible
  one, desc / author / cover / page URL from the page JSON, portrait, on `wantVideo` fetches the **lightest bitrate first with cookies
  and a tiktok.com Referer** and uploads it once; an item without data takes id from `xgwrapper`, desc / author from the overlay,
  falls back to the item API, reports the failure; the template without a token stays idle. (Chromium is not Zen/Firefox: the
  `wrappedJSObject` path and Violentmonkey's real GM implementation are not exercised.)
- **Sync rules** `node tests/nowplaying-sync.test.js` → **25 passed**, incl. a simulated minute with a 3 % slow mirror and a 1.5 s stall:
  2 seeks, drift at decisions ≤ 0.15 s.
- **Service + IPC** `bash tests/nowplaying-service.test.sh` (private offscreen qs, real daemon child on a random port, temp everything)
  → **29 passed, 0 failed**: starts OFF, no daemon while off, `on` persists and starts the daemon as the shell's child on the configured
  port, TikTok report shown (title, author, portrait 0.563 before the file), daemon asks for the file, upload → videoFile ready, aspect from
  the real 270×480 file, extrapolated position, paused follows, status line, `reset`/`reveal`, tab gone → lingering then **auto-hide after
  autoHideSec**, `reveal` shows it idle, `off` stops the daemon and persists, toggle, no daemon left after the shell exits.
  `NP_WITH_MPRIS=0` (real players merged, read-only) → 25 passed, 4 skipped by design (the user's playing Zen wins over a paused fake tab);
  the MPRIS-only YouTube path reached `ready` for the real track.
- **Renders** (offscreen, `preview/render.qml`, mock model, over a world wallpaper; all viewed), Day and Night:
  `qa/screenshots/now-playing-pip-{landscape,portrait,spotify,hover,paused,fetching,live,nothing,narrow}-{light,dark}.png`.
  **The "video" in landscape/portrait/hover/paused/live/narrow is a still frame of the real cached YouTube file made with ffmpeg**: VideoOutput
  cannot be captured offscreen (tried the default, OpenGL and Vulkan RHI: the grab is fully transparent), while decoding and sync are proven by
  mirror-test. `fetching` shows a letterboxed 4:3 `hqdefault`-style thumbnail correctly cropped to 16:9; `spotify`/`nothing` use a Minecraft
  painting as cover (now drawn crisp, not blurred).
- **Live**: after each QML save `qs.log` had no line from my files (the only warning, `TimeService.qml[15:5]`, is pre-existing: 27 earlier
  occurrences, one per reload). `qs -c overworld ipc call nowplaying status` → `off, daemon stopped, nothing playing`; `ipc show` lists the
  target; `widgets status` still answers; no daemon process; no runtime dir. `overworld nowplaying status`, `help nowplaying`, an unknown verb.
  `hyprctl configerrors` empty after the keybind and layer rule; SUPER+ALT+P listed in `hyprctl binds -j`. `bash -n` on overworld, install.sh,
  uninstall.sh; `node --check` on the userscript; `py_compile` on the daemon. The token never appears in the repo (test checks it).

## Not verified
- **Anything in the real Zen with real sites**: the userscript ran only in headless Chromium on synthetic pages (above); in Zen it needs
  the user's install click. The real TikTok DOM, React props through `wrappedJSObject`, and the CDN fetch with Referer through
  Violentmonkey's GM API are built on 2026 research, not observed. YouTube does not depend on the userscript (MPRIS URL path).
- **The PiP on the real screen**: the layer surface, the input mask, dragging/resizing with a real pointer, the Overlay layer over a
  fullscreen window, the hover state, the fade, the source-fullscreen hide, the focus button (`focuswindow address:`), the MPRIS buttons
  (never pressed: they would control the user's player). The widgets-menu row was not rendered (it lives in a PanelWindow).
- `install.sh` / `uninstall.sh` were not run (they reload Hyprland); only `bash -n`.

## Please try (user)
1. **Install the bridge**: in a terminal run `overworld nowplaying userscript --serve`. Copy the URL it prints
   (`http://127.0.0.1:47834/<random>/nowplaying-bridge.user.js`) into Zen's address bar, press **Install** on Violentmonkey's page
   (allow 127.0.0.1 and the TikTok hosts it asks for), then reload your YouTube / TikTok tabs. The little server stops by itself
   20 s after the download (or after 10 min).
2. **Turn it on**: SUPER+ALT+P (or the widgets menu → *Now Playing PiP*). With a YouTube video playing it shows the thumbnail, then
   "Fetching video…", then the silent video in sync. Seek, pause, change speed in the browser: it follows.
3. Drag it, resize it from the bottom-right grip, double-click the strip (back to the corner). Hover: ⏮ ⏯ ⏭, 󰏌 (jumps to Zen), ✕ (off).
4. TikTok For You: scroll a few clips; each should switch the PiP to a portrait frame, the cover, then the clip. **If TikTok clips stay
   on the cover**, run `hypr-nowplaying status` and tell me the `video:` line (the reason is in `videos[…].reason` of
   `$XDG_RUNTIME_DIR/hypr-nowplaying/state.json`).
5. Put the YouTube video in fullscreen: the PiP should hide, and come back when you leave fullscreen.
6. Play Spotify: cover + title only. Pause: it dims. Stop everything: it fades out after 20 s.
7. `overworld nowplaying status`, `overworld nowplaying cache list`, `overworld help nowplaying`.

## For the Apothecary port
**Shared contract (do not fork it)**
- Copy `scripts/hypr-nowplaying` **byte-identical** into `apothecary-hyprland/scripts/`, link `~/.local/bin/hypr-nowplaying` from its
  install.sh and run `hypr-nowplaying init` there; mirror the uninstall hand-over. Run Overworld's `bash tests/hypr-nowplaying.test.sh
  <apothecary copy>` against it (the test takes the script path as `$1`).
- The userscript template is found **relative to the script**: `<repo>/apps/zen/nowplaying-bridge.user.js` (or `HYPR_NOWPLAYING_USERSCRIPT`).
  So Apothecary needs a byte-identical copy at `apps/zen/nowplaying-bridge.user.js` too, or `userscript` fails there. One installed
  userscript serves both themes (same token in `~/.local/share/hypr-nowplaying/token`, same default port 47833).
- Start the daemon from QML exactly like `NowPlayingService.qml` does: `[<repo>/scripts/hypr-nowplaying, serve, --stdin, --port, P,
  --cache-mb, N, --max-min, M]`, `stdinEnabled: true`, running only while the PiP is on; exit code 3 = another instance owns the port
  (retry after 30 s, others after 10 s). stdin lines: `{"cmd":"want","site":"youtube","id":"<id>","duration":s}` and
  `{"cmd":"active","key":"youtube-<id>"}`. Never write to the daemon after it exited.
- Read `$XDG_RUNTIME_DIR/hypr-nowplaying/state.json` with a watching FileView (it is rewritten in place; a torn read is possible for an
  instant: ignore parse errors and wait for the next change; while it is missing, poll). Schema in docs/NOWPLAYING.md.

**QML to mirror**
- `NowPlayingService.qml` almost as is: theme-specific are only `ConfigService` (Apothecary's config service and file), `ShellState.preview`,
  `Theme.repoDir`, the state path `~/.config/apothecary/nowplaying.json`, and `MusicService` (Apothecary's own MPRIS service; it needs
  `players`, `player`, `fmt`). Keep the merge, the `videos[key]` lookup, `_wanted`/`_active`, lingering, `sourceFullscreen`, `focusSource`.
- `sync.js` and `VideoMirror.qml` as is (no theme code). `NowPlayingIpc.qml` as is. `NowPlayingPip.qml` nearly as is (namespace
  `apothecary-nowplaying`, its HUD/bar reserve instead of `Theme.px(40)`: Apothecary has a top bar, so the bottom-right default can sit
  closer to the bottom edge).
- `NowPlayingView.qml` is the part to restyle (McPanel, the oak frame, McText, McButton, McProgressBar, McItemIcon are Overworld's). Keep its
  API: `np`, `boxW`, `forceHover`, `frameStill`, `mirrorEnabled`, `interacting`, `gripActive`, signals `dragFinished`, `resizeFinished`,
  `resetRequested`, `closeRequested`, and the geometry rules (`aspect` → landscape / portrait / square, `clampBox`).
- `tests/hypr-nowplaying.test.sh <path to Apothecary's copy>` and `tests/nowplaying-bridge.test.sh` (the userscript) need no change.
- Stand-in stills and a real 19 s cached clip for renders are in `~/.hermes/cache/scratch/np/` (`zoo.mp4`, `still-169.png`,
  `still-916.png`, `hqdefault.jpg`).
- Tests port directly: `tests/nowplaying-service.test.sh` (change the QML path; it uses `OW_CONFIG`, so give Apothecary's config service a
  test override too), `preview/render.qml` (its mock object lists every property the view reads), `preview/mirror-test.qml`.

**Gotchas I hit**
- `PanelWindow` cannot load under `QT_QPA_PLATFORM=offscreen` ("No PanelWindow backend loaded"): that is why the IpcHandler is its own file
  and the screen choice lives in the service; the service test loads `NowPlayingIpc` alone.
- VideoOutput is not captured by offscreen `grabToImage` (any RHI backend): render a still from the cached file with ffmpeg for screenshots.
  MediaPlayer itself does play offscreen (position, seek, rate all testable).
- An `Image` with `sourceSize` larger than the picture **upscales smoothly at load**, so `smooth: false` alone does not keep pixel art crisp;
  and deciding `sourceSize` from `implicitWidth` is a binding loop. I decide by URL (theme textures).
- `\p{L}` regex escapes: not trusted in the QML JS engine; `norm()` uses explicit Unicode ranges.
- `qs -c overworld ipc call` answers "Not ready to accept queries yet" for a few seconds after each hot reload: retry, do not conclude.
- `pgrep -f hypr-nowplaying` matches your own shell's command line; use `ps` and filter.
- Headless Chromium `--dump-dom` never returns for a page whose markup holds a `<video>` (and is flaky with timers): drive it over the
  DevTools protocol instead (`tests/nowplaying-bridge/run.js`, Node 22's built-in WebSocket), create videos with `createElement`.
- Writing a Python file that contains a `<<'EOF'` heredoc from a shell heredoc delimited `EOF` cuts it short: use another delimiter.
- A real player that is playing beats a paused fake browser tab in the merge, so service tests need `OW_NOWPLAYING_NOMPRIS=1` to be
  deterministic.

## Requests filed
None needed: every file outside my area that I touched (shell.qml, WidgetsMenu, ConfigService, scripts/overworld, install/uninstall,
hypr/keybinds.conf, hypr/decorations.conf, docs) was named in my prompt.
