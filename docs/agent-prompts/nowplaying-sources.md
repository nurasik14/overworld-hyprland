# nowplaying-sources: choose WHICH tab / app the Now Playing PiP shows (both themes)

The user: "re make now playing widget to be able to choose the tab to display if I have several playing instances like
tabs or several apps." Today the PiP always shows ONE automatically chosen source (the bridge's newest playing tab, else
MusicService's MPRIS pick). With two YouTube tabs, or YouTube + Spotify, he cannot switch what it shows.

BOTH themes: Overworld (this repo) and Apothecary (`~/Projects/apothecary-hyprland`, same NowPlaying files with its own
bindings/look). `scripts/hypr-nowplaying` and `apps/zen/nowplaying-bridge.user.js` are SHARED and must stay
byte-identical in both repos (`cmp` at the end).

Read first: BRIEF.md (§1 rules), docs/agent-reports/now-playing-pip.md and docs/agent-reports/tiktok-actions.md (the whole
bridge/daemon/service design + the per-tab command channel you will reuse), `scripts/hypr-nowplaying` (Daemon.select,
snapshot, on_state, queue_action/tab_actions, on_control via --stdin), `apps/zen/nowplaying-bridge.user.js` (READ FULLY:
feedStep, watchdog, TikTok actions, heartbeat), `quickshell/NowPlaying/*.qml`, `quickshell/Widgets/Services/MusicService.qml`,
and the Apothecary copies. Also the existing tests in `tests/` (hypr-nowplaying, nowplaying-bridge, nowplaying-service).

## Facts already verified by the orchestrator (2026-11-15)
- Zen exposes ONE MPRIS player per browser instance (`playerctl -l` → `firefox.instance_1_642` only). As far as we know
  Firefox's MPRIS follows one tab at a time, so separate TABS can only be told apart through the bridge (it reports
  per tab with a random `tab` id; the daemon already keeps `self.tabs` but publishes only `select()`'s pick as `bridge`).
  Tabs on sites the userscript does not match can never be listed individually — they appear only as the browser's
  single MPRIS player. Say so in the docs.
- Already fixed by the orchestrator, keep it: `sourceFullscreen` in NowPlayingService.qml (both themes) now treats only
  Hyprland fullscreen bit 2 as fullscreen. Measured live: a MAXIMIZED Zen reports `lastIpcObject.fullscreen = 1`,
  `wayland.fullscreen = false`, `wayland.maximized = true`; the old `> 0` check hid the PiP on maximized Zen (the user's
  "it disappears on the Zen page" complaint). Add a service test: maximized (1) → shown, fullscreen (2) → hidden.
- The PiP is persisted OFF right now (`~/.config/overworld/nowplaying.json` on:false). It must stay OFF; never toggle it.
- Claude login is the user's Max plan; no API key.

## Design (decided by the orchestrator; implement these, record anything you change and why)
1. Source list (service, both themes): every fresh bridge tab (YouTube / YT Music / TikTok) + every MPRIS player that is
   not already represented by a bridge tab (Spotify, mpv, Chrome, Zen's own MPRIS while it plays a non-bridged site).
   Dedupe Zen's MPRIS against bridge tabs by title (existing `sameTitle`). Each entry: stable id (`tab:<id>` /
   `mpris:<dbusName>`), site label, title, artist, playing/paused, art.
2. Daemon: publish ALL fresh tabs in state.json (e.g. `tabs: [{tab, site, key, title, author, paused, thumbnail,
   received, ...}]`, same sanitising as `bridge`), keep `bridge` = the selected one for compatibility. New stdin control
   `{"cmd":"pin","tab":"<id>"|null}`: `select()` prefers the pinned tab while it exists (video fetch / `active` follow it);
   pin auto-clears when that tab goes away.
3. Choice semantics: default **Auto** = today's behaviour. Picking a source PINS it; the pin is released automatically when
   that source disappears (tab closed/expired, player gone), falling back to Auto. A pin survives shell hot reloads
   (PersistentProperties) but not a logout. "Auto" is always the first entry.
4. View (both themes, each in its own look): a small source chip in the PiP's hover controls, e.g. "YouTube · 2/3 ▾",
   visible only when there are 2+ sources. Click → a compact list INSIDE the PiP (mouse only; the PiP layer has no
   keyboard focus): Auto + one row per source (site label, title, ▶/⏸ state), current one marked. Mouse wheel over the
   chip cycles sources. Must fit at the PiP's minimum width (truncate/elide, never overflow).
5. Controls act on the SHOWN source: MPRIS sources via MPRIS as now. A pinned bridge tab that is not the one Zen's MPRIS
   follows gets ⏯ / ⏮ / ⏭ through the existing per-tab command channel (daemon queue → reply to that tab's next POST →
   userscript plays/pauses its own `<video>` or runs `feedStep`/next for that tab). Extend the heartbeat rule so a paused
   pinned tab still receives commands within ~1.5 s while the PiP is on. Background-tab `video.play()` may be refused
   by autoplay policy: report that as an error in the payload, don't retry in a loop. Mark it NOT VERIFIED in Zen.
6. Focus button: focuses the Zen WINDOW holding the source (switching to the exact tab is not possible from outside; note it).
7. IPC + CLI, both themes: `qs -c <theme> ipc call nowplaying sources` (one line per source, current marked) and
   `pick <n|next|prev|auto>`; matching `<theme> nowplaying sources|pick …` CLI verbs if the theme CLI already has
   nowplaying verbs (check `scripts/overworld` / Apothecary's CLI and their `help` pages).
8. Userscript `@version` 1.4.0. Do NOT run `hypr-nowplaying userscript --serve` (the orchestrator gives the user the
   install link afterwards).

## Tests (keep ALL existing tests passing)
- Daemon: multi-tab publish, sanitising, pin/unpin, pin cleared when the tab goes, select() honours pin, per-tab
  play/pause/next commands queued + delivered + expired.
- Bridge (Chromium harness + fixtures): two fixture tabs/pages, play/pause/next command handling, paused-tab heartbeat
  while PiP on, nothing sent when PiP off.
- Service: source list building + dedupe, Auto vs pinned, pin released when source vanishes, controls routed to the right
  player/tab, maximized vs fullscreen visibility (see facts), chip hidden with one source.

## THE USER IS AT THE DESK (hard rules)
No scripts/dev-shot.sh, no grim, no workspace switching, no on-screen previews/test windows, no sound, no git commits,
no sudo, no input injection, never control the user's players (no playerctl play/pause/next, no MPRIS method calls on
real players), never open or drive his Zen browser, never turn the PiP on. Visual checks = OFFSCREEN renders only
(`QT_QPA_PLATFORM=offscreen` harness → PNG → Read it), Day + Night, both themes: chip with 3 sources, open list, chip
hidden with 1 source, minimum width. The live `qs -c overworld` hot-reloads on EVERY QML save and a reload resets the
user's running brew timer: develop in a scratch copy / the offscreen harness and write each live QML file's final version
in as few saves as possible, every save valid; check `~/.cache/overworld/qs.log` after saves for errors from your files.
Apothecary is not running live, but keep it valid. No independent review subagent at the end; finish within ~60 min of work.

## Docs
The NowPlaying section of docs/WIDGETS.md (or the doc the earlier agents used) in both repos: choosing a source (chip,
list, wheel, IPC/CLI), Auto vs pinned, the one-MPRIS-per-browser limit, bridge 1.4.0 needed for per-tab control, the
maximized-vs-fullscreen fix. CHANGELOG entries in both repos.

Report in docs/agent-reports/nowplaying-sources.md: changed files (both repos), decisions (mark any deviation from the
design above), verified vs NOT verified (real Zen tabs, background play() — say so), `cmp` results for the shared files,
test counts, offscreen PNG paths, and a short "please try" list for the user.
