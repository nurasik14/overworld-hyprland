# now-playing-pip (follow-up): a floating, always-on-top "Now Playing" mini-player that shows the VIDEO (Overworld + shared bridge)

The user: "Make a floating window of the content I listen to, on top of every other window like a widget, toggled
from the widgets menu. It must display the current title and thumbnail, and if it's a video, the video itself. If
it's from TikTok, the video too."

This run builds the shared, theme-neutral parts (browser bridge, daemon/CLI, video cache) and the Overworld surface.
A second agent (`now-playing-pip-apothecary`) ports the surface to Apothecary right after you, using your report, so
write the report for it.

Read first: BRIEF.md (§1 rules), docs/WIDGETS.md, `quickshell/Widgets/Services/MusicService.qml` (MPRIS picking),
`quickshell/Widgets/Music/MusicCard.qml`, `quickshell/Bar/BossBar.qml`, `quickshell/Bar/WidgetsMenu.qml` and
`quickshell/Widgets/Services/WidgetsState.qml` (card on/off list, menu), `apps/zen/youtube-mpris-position.user.js`
(an existing userscript the user installed through Violentmonkey; keep it working), `scripts/hypr-notes` and
docs/agent-reports/sticky-notes.md (the precedent for a shared CLI kept byte-identical in both repos, install.sh
symlinks, `overworld <verb>` delegation, help pages, IPC, layerrules), `hypr/decorations.conf`, `scripts/install.sh`.

## THE USER IS AT THE DESK (hard rules)
No scripts/dev-shot.sh, no grim, no workspace switching, no on-screen previews/test windows, no
`overworld on/off/light/dark/gamemode`, no sound (anything you play must be muted / `--ao=null`), no git commits,
no sudo, no input injection, never control the user's players (no playerctl play/pause/next). `mpv` is deny-listed
for you; use ffprobe/ffmpeg (`-f null -`) or an offscreen qs harness to prove decoding. Visual checks = OFFSCREEN
renders (`QT_QPA_PLATFORM=offscreen` harness, grabToImage of a child Item → PNG, then Read the PNG). The live
`qs -c overworld` hot-reloads every QML save: keep each save valid, and check `~/.cache/overworld/qs.log` right after
for errors from your files. The new surface must NOT appear on the live screen while you build: its persisted
on/off state starts OFF, and you leave it OFF (the user turns it on). Don't start the daemon permanently from your
shell; the theme shell starts it (see Build 2) only while the surface is on.

## Facts already verified on this machine (2026-11-10)
- Quickshell 0.3.2, Qt 6.11; `qt6-qtmultimedia` is installed (QML `QtMultimedia`: MediaPlayer + VideoOutput, FFmpeg
  backend). No libmpv/mpvqt QML module.
- yt-dlp 2026.10.26 (pip --user, `~/.local/bin/yt-dlp`). YouTube works WITHOUT cookies:
  `yt-dlp -f 'bv*[height<=480][vcodec^=avc1]/bv*[height<=480]' <watch-url>` resolves; the direct googlevideo URL from
  `-g` 403s when fetched by another program (ANDROID client needs its headers), so DOWNLOAD with yt-dlp itself
  (`-o file`), don't hand `-g` URLs to a player.
- TikTok via yt-dlp FAILS here: "Your IP address is blocked from accessing this post" (the machine is behind a
  ProtonVPN datacenter IP, Singapore; also with Zen cookies). Don't rely on yt-dlp for TikTok (see Build 1).
- Browser = Zen (flatpak `app.zen_browser.zen`, MPRIS name `firefox.instance_*`), profile
  `~/.var/app/app.zen_browser.zen/.zen/pvdj5xcz.Default (release)`. Firefox MPRIS gives title/artist/artUrl but no
  page URL and (without the existing userscript) no position. Violentmonkey is installed in Zen. Installing a
  userscript needs the USER's click; serve it with `python3 -m http.server --bind 127.0.0.1` and put the exact
  steps in the report (don't launch Zen yourself).
- Spotify (desktop) may also play; it has no video: show cover art + title for it.

## Design (decide details yourself, record them)
- Sources: youtube.com (watch + Shorts), music.youtube.com, tiktok.com (For You feed, video pages, profile feeds),
  anything else MPRIS (Spotify, mpv, …) = art + title only.
- Video is a SILENT visual mirror of what the browser plays: the audio stays in the browser. The mirror player must
  be muted at all times, follow play/pause/rate, and stay in sync (seek when drift > ~0.35 s, check ~1 Hz; don't
  seek-thrash on buffering). Until the video is ready (or if it can't be fetched), show the thumbnail, scaled to
  fill with a soft blur behind for letterboxing. Live streams / very long videos (> config max, default 20 min):
  thumbnail only, unless it's the current tab's preview capture fallback below.
- Always on top: its own layer surface (namespace `overworld-nowplaying`), `WlrLayer.Overlay` (above fullscreen) by
  default; config `nowplaying.layer: "overlay"|"top"` ("top" stays below fullscreen apps). `keyboardFocus: None`,
  `exclusionMode: Ignore`, input mask = the window only (rest click-through). On every monitor? No: one surface on the
  focused/primary monitor, persisted per-monitor position.
- Mini-player look: PiP-sized (default ~360×(16:9) + title strip; vertical 9:16 sources like TikTok/Shorts get a
  portrait frame automatically), Minecraft-framed (e.g. a map / item-frame / painting border from the theme's
  texture helpers, the theme's font for title/artist/source), translucency like other panels but the VIDEO itself is
  opaque. Title + artist/channel + source icon (YouTube/TikTok/Spotify) on a strip; on hover: ⏮ ⏯ ⏭ (MPRIS of the
  source player), a "focus source" button (focus the browser window via hyprctl), close ✕ (= turn off), and a resize
  grip in a corner (keep aspect; min/max sizes; persist). Drag by the strip/frame (DragHandler pattern from the
  widget cards incl. the fast-drag mask trick; bounded to the screen; persisted). Double-click strip = reset position.
  Auto-hide when nothing is playing for N s (config, default 20 s; paused = stays, dimmed); smooth fade in/out,
  respect reduced motion. Don't collide with the BossBar/HUD at default position (default: bottom-right above any
  HUD, check layout constants).
- Hide automatically while the SOURCE browser window is the focused fullscreen window (pointless double video);
  config switch.
- Toggle: a row in the widgets menu (WidgetsMenu) like the cards (label "Now Playing PiP" or an in-world name),
  persisted with the other card states, plus IPC target `nowplaying` (`toggle`, `on`, `off`, `status`, `reveal`,
  `reset`), CLI `overworld nowplaying on|off|toggle|status|reset` + help page, and a free keybind (check
  `hyprctl binds -j` + JaKooLit Keybinds.conf/UserKeybinds.conf; document it in docs/KEYBINDS.md; no `hyprctl reload`
  unless needed, and then once at the end with `hyprctl configerrors` empty). Middle-click/"All" in the menu must not
  break (decide whether "All" includes it; it's not a desktop card).

## Build
1. Browser bridge userscript `apps/zen/nowplaying-bridge.user.js` (Violentmonkey; matches youtube.com,
   music.youtube.com, tiktok.com). Find the media element that is actually playing (TikTok feed has many <video>s:
   pick the one in view and not paused), and report at ~1 Hz + on play/pause/seeked/ratechange/src change:
   `{site, pageUrl, videoId (YouTube id / TikTok numeric id + author), title, author, thumbnail, position, duration,
   paused, rate, live, isVideo(not audio-only), visible(document.visibilityState), ts}` to the local daemon. Find
   the TikTok id/author/description from the playing item's DOM (data-e2e attributes, links) and the poster/cover.
   Transport: `GM_xmlhttpRequest` POST to `http://127.0.0.1:<port>/state` with a shared secret token header (token
   generated at install time into `~/.local/share/hypr-nowplaying/token`; the served .user.js gets it baked in by a
   `hypr-nowplaying userscript` command; never commit a real token). TikTok video bytes: since yt-dlp is IP-blocked,
   the userscript fetches the playing video's file itself (`GM_xmlhttpRequest` with `responseType: "blob"` on the
   video's currentSrc, or the item's play/download address if currentSrc is a blob: MSE URL) and uploads it to
   `POST /video/<id>` (size cap, e.g. 60 MB; only when the PiP is on: the daemon answers `/state` with
   `{wantVideo: true/false}`). If neither works for an item, the PiP shows the cover + title (documented fallback).
   Keep it light: no polling when no media is playing, no uploads when the PiP is off.
2. Daemon + CLI `scripts/hypr-nowplaying` (Python 3 stdlib only; theme-neutral; byte-identical in both repos;
   install.sh symlinks `~/.local/bin/hypr-nowplaying`). `serve` binds 127.0.0.1 only, checks the token on every
   request (reject otherwise), accepts `/state` and `/video/<id>`, writes the merged current state atomically-but-
   in-place for watchers to `$XDG_RUNTIME_DIR/hypr-nowplaying/state.json` (incl. `videoFile` when the cached file is
   ready, `videoStatus: none|fetching|ready|failed|skipped`), and fetches YouTube videos in the background with
   yt-dlp (video-only, ≤480p, avc1 preferred, to `~/.cache/hypr-nowplaying/<site>-<id>.mp4`, one job at a time,
   newest request wins, a timeout, skip live/too long). LRU cache cap (config, default 400 MB). Host allowlist for
   anything it downloads. Single instance (flock pid file, PR_SET_PDEATHSIG so it dies with the shell). Verbs:
   `serve`, `status [--json]`, `userscript` (writes the token-baked .user.js to the cache dir and prints a localhost
   URL + install steps), `cache [list|clear]`, `-h`. `overworld nowplaying …` delegates where it fits.
3. Service `NowPlayingService` singleton (Overworld): merges MPRIS (MusicService's chosen player; reuse it) with the
   bridge state (match by title/recency; bridge data wins for position/paused/rate/thumbnail of browser media; stale
   after ~3 s without a bridge update → MPRIS only). Runs the daemon as a child `Process` only while the PiP is on.
   Exposes title, artist, source, artUrl, videoFile, aspect, position/paused/rate, controls.
4. Surface `quickshell/NowPlaying/NowPlayingPip.qml` (or the dir that fits the repo layout), instantiated in
   shell.qml, IPC target, MediaPlayer(muted, audioOutput null or volume 0 + muted) + VideoOutput, sync logic, the
   look/behaviour above, Day + Night palettes. Layer rule in `hypr/decorations.conf` (no blur on the video; place
   after the catch-all), and an `opacity 1.0` guarantee.
5. Config keys under `nowplaying.*` in the theme's config.json via ConfigService (layer, autoHideSec, maxVideoMin,
   hideWhenSourceFullscreen, width, cacheMB, port), documented.
6. Verify: CLI/daemon tests with a temp runtime/cache dir and a temp token (curl POSTs of fake state, bad token
   rejected, video upload path, cache LRU); a REAL YouTube fetch of one short video into the temp cache (ffprobe
   it: video-only, ≤480p); sync logic unit-tested in a qs offscreen harness if feasible (mocked state); offscreen
   renders, Day and Night, all viewed: landscape video frame (if VideoOutput won't render offscreen, render a
   still from the cached file via ffmpeg as the stand-in and say so), portrait TikTok-style, thumbnail-only Spotify
   style, hover controls, paused/dimmed. Live: qs.log clean, `qs -c overworld ipc call nowplaying status` answers,
   the surface stays OFF.
7. Docs: docs/WIDGETS.md (or a new docs/NOWPLAYING.md) section incl. how the bridge works and privacy (localhost
   only, token, what's sent), README feature bullet + CLI table, docs/KEYBINDS.md, CHANGELOG.md entry.

Report in docs/agent-reports/now-playing-pip.md: changed files, decisions, verified vs not verified (real playback
in Zen needs the user), a "please try" list starting with the userscript install steps, and a "for the Apothecary
port" section (shared contract: daemon/CLI/state file/userscript; which QML to mirror; gotchas).
