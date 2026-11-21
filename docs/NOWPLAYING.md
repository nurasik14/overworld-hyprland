# Now Playing PiP — a floating mini-player that shows the video

A small painting that floats above every window (fullscreen ones too) and shows what you are listening to: the title, the
channel or artist, the cover, and **for YouTube and TikTok the video itself**, as a silent mirror that follows the browser
(play, pause, seek, speed). The sound always stays in the browser. Spotify and every other MPRIS player show cover + title.

It starts **off**. Turn it on in the widgets menu (the item-frame slot on the HUD → **Now Playing PiP**), with
**`SUPER+ALT+P`**, or `overworld nowplaying on`.

## Using it

- **Drag** it anywhere (the frame, the picture or the strip). It stays where you put it, per monitor, measured from the
  nearest corner, so a taller portrait clip grows away from the screen edge. **Double-click the strip** = back to the default
  place (bottom right, above the HUD) and size.
- **Resize** from the stepped grip in the bottom-right corner (on hover). The picture keeps its shape; 200–960 px.
- **Hover**: ⏮ ⏯ ⏭ (the shown source's controls), 󰏌 brings the source window to the front (it may switch
  workspace), ✕ turns the PiP off. With 2+ sources a **source chip** top left (next section). On TikTok also **♥ like, ⟲ repost,
  🔖 save**.
- **Shapes**: 16:9 videos are `width` wide (default 360 px); vertical clips (TikTok, Shorts) get a portrait frame
  0.9 × `width` tall; music covers a square.
- **Paused** = it stays, dimmed, with "Paused" over the picture. **Nothing playing** for `autoHideSec` (default 20 s) = it fades
  out, and fades back in when something plays. `overworld nowplaying reveal` shows it on the focused monitor right away.
- **Hidden while the source is fullscreen and focused** (watching the same video twice makes no sense; a merely maximized window
  does not count). Config switch.
- One surface on one monitor: the focused one when it appears; `reveal` moves it to the focused one.

## Several tabs or apps: choosing what the PiP shows

When more than one thing plays or is paused — two YouTube tabs, YouTube + TikTok, YouTube + Spotify — the PiP lists them and you
choose which one it shows.

- **The source chip**: hover the PiP; with 2+ sources a chip sits top left, e.g. **`YouTube 2/3`** (the shown source and its number;
  just `2/3` when the PiP is too narrow). A pin glyph 󰐃 in front = you pinned it.
  - **Click** it: a list opens **inside the PiP** (mouse only, the PiP never takes the keyboard): **Auto** first, then one row per
    source (▶ playing / ⏸ paused, the site, the title). A white frame marks the current choice. Click a row to choose it; moving the
    pointer off the PiP closes the list.
  - **Mouse wheel** over the chip: next / previous (Auto → 1 → 2 → … → Auto).
- **Auto** (the default) is the old behaviour: a playing browser tab wins (the newest one that started), else the MPRIS player
  (Spotify first), else a paused tab.
- **Pinned**: choosing a row pins that source: the PiP keeps showing it even when something else starts playing. The pin is
  **released by itself** when that source goes away (tab closed, its report expired, player quit — after 3 s), and the PiP falls
  back to Auto. A pin survives a shell reload (`PersistentProperties`), not a logout. A pinned tab is also pinned in the daemon, so
  its video is the one that gets fetched.
- **Controls act on the shown source**: a player source (Spotify, mpv, …) through its MPRIS. A tab through the browser's MPRIS **when
  that player follows the tab** (same title); otherwise — a pinned tab while another tab plays, or Auto with several tabs — ⏯ ⏮ ⏭ go
  **to that tab's own player** through the bridge (shell → daemon stdin → the tab's next report, ~1 s): play / pause its `<video>`,
  ⏭ = YouTube's next button / TikTok's feed step, ⏮ = the previous button or back to the start. A browser may refuse `play()` in a
  **background tab** (autoplay policy): the PiP then shows *"the browser refused to start a background tab: click the tab once"* and
  does not retry. A pinned tab whose userscript is older than **1.4.0** has no buttons (the tooltip says why).
- **Focus** (󰏌) brings the Zen **window** holding the source to the front. Switching to the exact **tab** is not possible from outside
  the browser.
- From a terminal: `overworld nowplaying sources` (one line per source, `0 = auto`, `*` = the current choice, `[shown]`) and
  `overworld nowplaying pick <n|next|prev|auto>`; IPC `qs -c overworld ipc call nowplaying sources` / `pick <n|next|prev|auto>`.

**What can be listed.** Zen exposes **one MPRIS player per browser instance** (`playerctl -l` shows only `firefox.instance_…`), and
Firefox's MPRIS follows one tab at a time. So separate **tabs** can only be told apart through the **bridge userscript**, which runs on
YouTube, YouTube Music and TikTok and reports each tab with its own random id. A tab on any other site (Twitch, a podcast page, …)
cannot be listed on its own: it appears only as the browser's single MPRIS row, and only while that player is not already showing a
listed tab (dedupe by title). Other players (Spotify, mpv, Chrome, …) are one row each.

**Bridge 1.4.0 needed** for the per-tab buttons and for paused tabs to show up reliably: reinstall with
`overworld nowplaying userscript --serve`. With an older userscript the list still works (from the reports it sends), but a pinned
tab that is not the one Zen's MPRIS follows gets no ⏯ ⏮ ⏭. What 1.4.0 adds: a paused tab reports every 2 s **while the PiP is on**
(the daemon's `keepalive`, so it can learn that it was pinned), every 1 s once pinned or while a command waits for it (`poll`), and
nothing at all when the PiP is off (after two reconnect checks 3 s and 10 s after the daemon disappears, so a shell reload does not
drop paused tabs).

**Maximized is not fullscreen.** Hyprland reports a maximized window with `fullscreen = 1` (a bit field: 1 = maximized,
2 = fullscreen). The PiP used to hide whenever the source window had any bit set, so it vanished on a maximized Zen; now only real
fullscreen (bit 2) hides it.

## TikTok: like, repost, save to a collection

While a **TikTok** clip plays in Zen (even in a background tab, even paused) the hover controls get a second row above
⏮ ⏯ ⏭: **󰋕 like**, **󰕇 repost**, **󰃃 save**. You never have to switch to the browser. Each one is a **toggle** and shows the
clip's state: a filled glyph in colour (red heart, green repost, gold bookmark, with a line under it) = on; an outline = off;
the hover tooltip says which, and what the click will do.

| button | press when off | press when on |
|---|---|---|
| like | likes the clip | unlikes it |
| repost | reposts it | removes the repost |
| save | favourites it **and** adds it to your collection `nowplaying.tiktokCollection` (default **"Edits"**) | un-favourites it. **TikTok then also removes it from every collection** (there is no "remove from one collection only") |

- **Needs** the bridge userscript **1.3.0** or newer (`overworld nowplaying userscript --serve`, then Install; reload the
  TikTok tab) and a **logged-in** TikTok tab on the For You feed or a video page. The row shows only when the PiP's source is
  that tab and the userscript sees TikTok's like / favourite / share column **for the very clip the PiP shows**. YouTube,
  Spotify and other players never get it.
- It clicks **TikTok's own buttons** in that tab, so TikTok does exactly what a click by hand does (its own requests, your
  session). Nothing calls TikTok's API from outside the page.
- **The clip you saw is the clip it acts on**: every press carries the clip id; the daemon refuses it when the tab shows another
  clip, and the userscript refuses it again when TikTok's action column belongs to another clip.
- **One at a time**: while a press is on its way (normally under 1.5 s; save can take a few seconds) all three are dimmed, the
  running one shows 󰔟, and presses are ignored.
- **Repost state is unknown** (plain glyph, "state unknown") until you use the button once for that clip: TikTok's page data
  has no repost flag; the share panel's "Repost" / "Remove repost" is the only signal.
- **Save** = favourite, then the toast's **Manage**, then your collection in the list (matched by name, case-insensitive). If
  the collection does not exist it is **not created**: the clip stays in Favorites only and the PiP says so. Same when TikTok
  shows no Manage toast.
- Failures (logged out, another clip, no such collection, no answer from the tab) show for a few seconds as a red `!` line on
  the picture and stay in that button's tooltip.
- Privacy: commands go from the shell to the daemon's **stdin** (not HTTP: a web page cannot send one even with the token), and
  from the daemon only to the tab, in its reply over **127.0.0.1 with the token**. The userscript reports only whether the shown
  clip is liked / favourited / reposted.

### Zen on another workspace
Hyprland "suspends" a window on a workspace you are not looking at; Firefox/Zen then marks the page hidden and stops laying
it out, so TikTok cannot move to another clip (⏮/⏭ from the PiP, the bridge's stall watchdog) until you look at it.
`hypr/rules.conf` gives Zen windows whose title shows TikTok `render_unfocused on`, which keeps them drawing in the
background (at `misc:render_unfocused_fps`, 15). A window that only starts showing TikTok later picks it up on its next
workspace change (moving it away and back is enough).

## Where the picture comes from

| source | title / cover | video |
|---|---|---|
| YouTube (watch, Shorts) in Zen | MPRIS, or the userscript | downloaded by the daemon with yt-dlp (video only, ≤ 480p, avc1 first) |
| YouTube without the userscript | MPRIS (Zen exports the page URL, so the id is known) | the same download; position from MPRIS (the existing position userscript makes that exact) |
| YouTube Music | the userscript / MPRIS | only for real music videos in Video mode; songs and art tracks show the cover |
| TikTok (For You, video pages, profiles, explore) | the userscript | the userscript hands the clip's file over (TikTok blocks yt-dlp on many networks, including this VPN) |
| Spotify, mpv, anything MPRIS | MPRIS | none (cover + title) |

Until the video is ready, and whenever it cannot be had (live streams, ads, a TikTok clip whose file the page does not expose,
a TikTok clip longer than `maxVideoMin`), the thumbnail is shown: fitted, with a blurred copy behind it for the bars (YouTube's
letterboxed 4:3 `hqdefault.jpg` is cropped to its 16:9 picture instead).

**Sync**: the browser is the clock. About once a second, and at once on play / pause / seek / speed, the mirror compares
its position with where the browser is now. 0.12–0.35 s off: it runs 5 % faster or slower for a moment (no stutter); more
than 0.35 s: one seek, then at least 2 s of rest (doubling, up to 8 s, if seeks do not hold); never while buffering; when
paused it seeks to the exact frame; while the browser buffers, the mirror holds too. A browser report older than 3.5 s is
not steered by (the mirror runs free). A paused report counts only while the browser still has an MPRIS player (a browser
that quit sends no "gone"). The rules
are `quickshell/NowPlaying/sync.js`, tested by `node tests/nowplaying-sync.test.js`.

### Long videos: the picture comes in parts

A YouTube video up to `maxVideoMin` (default 20 min) is still fetched as one file. A longer one (not live; there is no upper
limit) is fetched in **parts around where you are**, so the picture appears about a minute after you start, even in a 3-hour
video. `maxVideoMin` now only decides "whole file or parts".

- **First part**: `partFirstMin` (5 min) from the current position (2 s before it), so it is ready quickly.
- **Then** parts of `partMin` (40 min) that continue where the last one ends, each starting 8 s before that end.
  The next part is fetched when less than `partAheadMin` (5 min) of fetched video is left ahead of the position.
- **All parts at ≤ `partHeight` (360p).** The PiP is 360 px wide by default, so that is enough. Parts are video only.
- **Seeking** inside the fetched range changes nothing. A jump outside it starts again: a short part at the new position,
  then the 40-minute parts from there. A part still on its way that covers the new position is kept.
  Switching to another video stops the running fetch at once.
- **Playback**: the PiP has two hidden players. The second one loads the next part and waits on its first frame. When the
  browser reaches that part, it starts playing in sync. 1 s before the current part ends it is put on top, so there is no
  flash or jump. Sync works as for a whole file (below). While no part covers the position, the cover is shown with
  "Fetching video…".
- **Disk**: parts are normal cache files, `~/.cache/hypr-nowplaying/youtube-<id>.part-<startMs>-<endMs>.mp4`, under the same
  LRU and `cacheMB` cap. Parts that end more than 10 min behind the position are deleted. The part on screen and the next one
  are never deleted. After a shell reload or a daemon restart, the parts already on disk are used again.
  At 360p a part costs ≈ 1–2.5 MB per minute: a 40-min part ≈ 40–100 MB.
- **Status line**: `overworld nowplaying status` says e.g. `video parts 2/3 ready` (parts on disk / all, incl. the one being
  fetched; `ready` = a part covers the position). `hypr-nowplaying status` lists the ranges and
  `hypr-nowplaying cache list` lists the part files.

**Measured on the author's VPN** (ProtonVPN, 2026-11-15, `youtube-CeItO4-ARfk`, 1 h 46 min): the whole file never made it,
because each request is capped at 300 s and the VPN ran at ≈ 160 KB/s. A part costs about 40 s of fixed overhead
(extraction, the bot wall, the player JS) plus ≈ 1.3 s and ≈ 2.5 MB per minute of video at 360p. Measured parts:
1 min → 44–48 s, 5 min → 49 s. A part through the daemon itself took 85 s, because the first set of YouTube clients failed
with "ffmpeg exited with code 8" and the fallback set worked; that failure hit 2 of 3 cuts. A 40-min part should take
≈ 95–140 s (extrapolated), well inside the 300 s cap.

**Where a part really starts.** yt-dlp cuts without re-encoding, so a part begins at the **keyframe before** the asked
start. The extra frames are hidden in an MP4 edit list (measured: 3.707 s for a cut at 50:00, 3.175 s for one at 50:28).
The daemon reads the edit list, keeps the extra frames as real frames (`ffmpeg -ignore_editlist`, video only), and stores the
true timeline start in the file name. A frame-by-frame comparison with an exactly cut copy (`--force-keyframes-at-cuts`,
which re-encodes and took 57 s instead of 48 s) matched within one frame. The overlap between parts is therefore 8 s plus
that pre-roll.

## The browser bridge (Zen userscript)

`apps/zen/nowplaying-bridge.user.js` is a Violentmonkey userscript for `www.youtube.com`, `music.youtube.com` and
`www.tiktok.com`. The copy in the repo is a template that does nothing; install the copy with your token in it:

1. `overworld nowplaying userscript --serve` (or `hypr-nowplaying userscript --serve`). It writes
   `~/.cache/hypr-nowplaying/userscript/nowplaying-bridge.user.js` and serves it for up to 10 minutes on
   `http://127.0.0.1:<port+1>/<random>/nowplaying-bridge.user.js` (a random path, so no web page can fetch the token meanwhile).
2. Open the printed URL in Zen. Violentmonkey shows its install page: **Install**. It asks for permission to talk to
   `127.0.0.1` and TikTok's video hosts (`@connect`): that is the bridge.
3. Reload YouTube / TikTok tabs that were already open.

It keeps working next to the older `youtube-mpris-position.user.js` (that one feeds MPRIS; this one feeds the PiP).

**Google Chrome too (1.4.1+).** Chrome's MPRIS has no `xesam:url`, so without the bridge a Chrome YouTube tab shows only its
cover (the PiP cannot know which video it is). Install the same userscript in Chrome with **Tampermonkey** (Violentmonkey no longer
runs in current Chrome): Tampermonkey → chrome://extensions → Details → turn on **Allow User Scripts** (Chrome 138+; older Chrome:
Developer mode), then open the `--serve` URL in Chrome and press **Install**, and reload the YouTube tabs. The header
`@sandbox JavaScript` makes Tampermonkey run it in the page world, where YouTube's player object and the page's media session are
reachable (Violentmonkey ignores that line and keeps `@inject-into content`). Zen and Chrome tabs then show up side by side in the
source list. Videos longer than `maxVideoMin` (default 20) come in parts (next section), in either browser.
Changing `nowplaying.port` means installing the userscript again.

### Privacy

- Everything stays on this machine. The daemon listens on **127.0.0.1 only**, answers **nothing without the token**
  (`X-Hypr-Nowplaying-Token`, 256 random bits in `~/.local/share/hypr-nowplaying/token`, mode 0600) and only to the Host
  `127.0.0.1:<port>` / `localhost:<port>` (no DNS-rebinding tricks); CORS preflights are refused, so web pages cannot call it.
- **What the userscript sends**, only while something plays (once a second) and on play / pause / seek / speed changes:
  site, page URL (YouTube: only `?v=`; TikTok: no query), video id, title, channel / author, thumbnail URL, position,
  duration, paused, buffering, playback rate, live, ad, picture size, whether the tab is visible; on TikTok also
  `tt: {bar, clip, liked, saved, reposted, busy, last}` (the shown clip's like / favourite / repost state and the last
  button result). Nothing while nothing plays. A paused **TikTok** tab keeps reporting once a second **only while the daemon
  answers `poll: true`**, i.e. while the PiP is on (so a button press reaches a paused clip); with the PiP off nobody answers
  and it goes quiet.
- **TikTok file**: only when the daemon asks for it (`wantVideo`), which it does only while the PiP is on, once per clip.
  The userscript fetches the clip from TikTok's own CDN with that tab's cookies and posts it to the daemon (max 60 MB).
- The daemon fetches nothing but `https://www.youtube.com/watch?v=<11-char id>` through yt-dlp; thumbnails are shown only
  from YouTube / Google / TikTok / Spotify image hosts; anything else in a report is dropped.
- Videos are cached in `~/.cache/hypr-nowplaying/` (LRU, `cacheMB`, default 400 MB); `overworld nowplaying cache clear`
  empties it. The state is in `$XDG_RUNTIME_DIR` (RAM, gone at logout).

## The daemon: `hypr-nowplaying`

Shared by both themes (the same file in `overworld-hyprland` and `apothecary-hyprland`, linked as
`~/.local/bin/hypr-nowplaying`). Python 3, standard library only. The theme shell starts it as a child process **only
while the PiP is on**; it dies with the shell (`PR_SET_PDEATHSIG`, and EOF on its stdin).

```
hypr-nowplaying serve [--port 47833] [--cache-mb 400] [--max-min 20] [--upload-mb 60] [--stdin] [--keep] [-v]
hypr-nowplaying status [--json]          running?, what the browser reports, the video, the cache
hypr-nowplaying userscript [--port N] [--serve] [--print]
hypr-nowplaying cache [list|clear]
hypr-nowplaying want <youtube-url|id>    ask the running daemon to fetch one
hypr-nowplaying init | path | help
```

- `POST /state` (a report) → `{ok, key, wantVideo, actions, poll}` · `POST /video/<key>` (a TikTok clip it asked for) ·
  `POST /video-error/<key>` · `POST /want {site, id}` · `GET /ping`.
- State file `$XDG_RUNTIME_DIR/hypr-nowplaying/state.json`, rewritten in place (watchers keep the inode):
  `{v, server: {pid, port, started, version} | null, updated, bridge: {tab, site, key, videoId, pageUrl, title, author,
  thumbnail, position, duration, paused, rate, live, isVideo, ad, width, height, visible, ts, received} | null,
  videoFile, videoStatus: none|fetching|ready|failed|skipped, videos: {<key>: {status, file, reason, width, height,
  duration}}, fetching, action}`. Keys are `youtube-<id>` (YouTube and YouTube Music share them) and `tiktok-<id>`.
  TikTok reports also carry `bridge.tt` (sanitised: `liked`/`saved`/`reposted` are `true`/`false`/`null`; no state when the
  action column belongs to another clip).
- TikTok buttons: stdin `{"cmd": "action", "tab", "key": "tiktok-<id>", "action": "like"|"repost"|"save", "collection"}`.
  One command per tab (a second one while it is queued or running is ignored); it must name the clip the tab reports, or it is
  refused. It is handed to the tab in the reply to its next report (`actions: [{id, key, action, collection}]`), at most
  10 s after the press (else `expired`); the tab has 40 s to report `tt.last {id, ok, error}`. `action` in the state file =
  the newest command: `{id, tab, key, action, status: queued|sent|done|failed|expired|refused, error, t}`.
- Several tabs: the one that started playing last wins; a playing tab that has not reported for 5 s is dropped; a paused tab
  is kept (30 min). yt-dlp: one job at a time, a newer request kills the running one, 5 min timeout, live and too-long
  videos skipped by yt-dlp's own `--match-filter` (asked again after an hour: a live stream may have ended); a failure is not
  retried for 10 min; a "too long" from one browser report is re-judged on the next one. yt-dlp dies with the daemon.
- YouTube's bot wall ("Sign in to confirm you're not a bot", HTTP 429) hits yt-dlp from VPN / datacenter IPs. The daemon
  therefore hands yt-dlp every JS runtime it finds (`--js-runtimes`: deno, node, bun; yt-dlp enables only deno by itself)
  and tries the player-client chains in `YTDLP_CLIENTS` in order (`default,tv,mweb`, then `tv,mweb,web_embedded`). Those
  clients often return only the 360p progressive format, which has an audio track; the mirror never plays it. No cookies
  are used. If videos still fail: `yt-dlp -U` (needs the pip install) and check `hypr-nowplaying status`.

## Config (`~/.config/overworld/config.json` → `"nowplaying"`)

| key | default | |
|---|---|---|
| `layer` | `"overlay"` | `"overlay"`: above everything, fullscreen apps too. `"top"`: below fullscreen apps |
| `autoHideSec` | `20` | fade out after this long with nothing playing (paused does not count) |
| `maxVideoMin` | `20` | up to this length a YouTube video is fetched as one file; longer ones come in parts (no upper limit); TikTok clips longer than this: cover only |
| `hideWhenSourceFullscreen` | `true` | hide while the source window is the focused fullscreen window |
| `width` | `360` | default width of a 16:9 picture, px (resizing saves its own per monitor) |
| `cacheMB` | `400` | video cache cap (LRU) |
| `port` | `47833` | the bridge's localhost port (reinstall the userscript after changing it) |
| `video` | `true` | `false` = covers and thumbnails only, nothing downloaded |
| `tiktokCollection` | `"Edits"` | the TikTok collection the save button adds a clip to (matched by name, case-insensitive; never created) |
| `partFirstMin` | `5` | long videos: length of the first part (from the current position, also after a seek), min |
| `partMin` | `40` | long videos: length of every following part, min |
| `partAheadMin` | `5` | fetch the next part when less than this much fetched video is left ahead of the position, min |
| `partHeight` | `360` | long videos: the parts' maximum height, px |

State: `~/.config/overworld/nowplaying.json` `{"on": false, "positions": {"<monitor>": {"ax", "ay", "dx", "dy", "w"}}}`.

## Commands

- `overworld nowplaying on | off | toggle | status | reveal | reset | sources | pick <n|next|prev|auto> | userscript [--serve] |
  cache [list|clear] | bridge` (`on`/`off` also work while the shell is down: they edit the state file).
- IPC: `qs -c overworld ipc call nowplaying toggle | on | off | status | reveal | reset | sources | pick <n|next|prev|auto>`.
- Keybind `SUPER+ALT+P`; widgets menu row **Now Playing PiP** (not part of "All widgets" or the chip's middle-click: it is
  an overlay, not a desk card).

## Files

`quickshell/NowPlaying/`: `NowPlayingPip.qml` (the layer surface, entry in `shell.qml`), `NowPlayingView.qml` (the look),
`MirrorStack.qml` (two VideoMirrors: the shown part and the preloaded next one; a whole file is one part),
`VideoMirror.qml` (MediaPlayer with **no audio output** + VideoOutput), `sync.js` (sync rules + `partClock` / `pickPart` / `nextPart`), `NowPlayingService.qml` (merge, daemon,
state), `NowPlayingIpc.qml`, `preview/` (offscreen harnesses). Layer namespace `overworld-nowplaying` (no blur, no
animation: `hypr/decorations.conf`; layers never get the window opacity rules, the video is opaque). `scripts/hypr-nowplaying`,
`apps/zen/nowplaying-bridge.user.js`.

## Tests (all offscreen, temp dirs, silent)

- `bash tests/hypr-nowplaying.test.sh` — the daemon/CLI: token, Host and preflight checks, sanitising, tab choice, expiry,
  TikTok upload path (asked / not asked / junk / too big / error), the yt-dlp worker with a fake yt-dlp (newest wins,
  failures), LRU, single instance, SIGTERM, `--stdin` EOF, death with the parent, and the TikTok command queue (queue,
  deliver once, result, busy, bad token / action / tab / clip, refused over HTTP, clip changed, tab closed, 10 s expiry,
  `tt` sanitising), and several tabs (the `tabs` list and its sanitising, `pin` / unpin, select() honours the pin and the video
  fetch follows it, the pin released when the tab closes / expires / is never seen, `poll` for the pinned tab and `keepalive`,
  per-tab play / pause / next queued, delivered, done / failed, not bound to a clip, expired), and long videos in parts (the fake
  yt-dlp honours `--download-sections` and cuts a real 2 h test video the way yt-dlp does: the first part at the position, its
  true start = the keyframe before the cut, normalised video-only file, no next part while enough is ahead, the next part
  overlapping when < `partAheadMin` is left, a seek outside → a new short part, old parts dropped, parts found again after a
  restart, superseded on a video change, a short video still whole, the MPRIS `want` with a position, LRU keeps the shown
  video's parts, the per-request timeout). `NP_REAL=1` also downloads one real
  19 s YouTube video and checks it with ffprobe (video only, ≤ 480p, decodes).
- `bash tests/nowplaying-service.test.sh` — the service and IPC in a private qs instance with the real daemon as its child
  (`NP_WITH_MPRIS=0` also merges the real MPRIS players, read-only); several sources: the list and its order, `sources` / `pick`
  (number, next / prev wrap, auto, bad number), Auto vs pinned, the daemon pin, controls routed to the pinned tab (play / next
  reach that tab; an older bridge = no controls), a refused play shown, the pin released when the tab closes, MPRIS dedupe with
  stand-in players, maximized (1) shown vs fullscreen (2) hidden; a long video → parts mode, the first part asked at the position,
  the mirror gets it with its true start, the `video parts n/m ready` status line, and the MPRIS-only `want` (position, 5 s
  throttle, at once on a jump or a pause). A stand-in yt-dlp: nothing in it touches the network.
- `node tests/nowplaying-sync.test.js` — the sync rules and the part rules (position → part and offset, the overlap, the measured
  start offset, the swap SWAP s before a part's end, the preload, a gap → the cover, a simulated hand-over with one swap).
- `bash tests/nowplaying-bridge.test.sh` — the real userscript in a headless, muted, offline Chromium (driven over the DevTools
  protocol, `tests/nowplaying-bridge/`) on synthetic YouTube, YouTube Music and TikTok pages with a stub `GM_xmlhttpRequest`:
  which element it picks, every field, 1 Hz while playing and silence while paused, buffering, ads, art tracks, the TikTok
  item data / overlay / item-API fallback, the lightest file with cookies + Referer, the upload, the idle template; and on a
  fake **logged-in** TikTok page (`fakeTikTok()` in `harness.js`, the DOM seen on the real page): like / unlike, repost /
  remove, save → "Edits" / un-save, wrong clip refused, duplicate presses, missing collection, no Manage toast, a share panel
  Escape does not close, logged out, a paused clip reached within 1.5 s and quiet with the PiP off, ⏮ / ⏭ through
  `feed-navigation-*` with the scroll fallback, the stall watchdog (bounce, and none for a paused clip); 1.4.0: the version in
  each report, the paused `keepalive` and the pinned 1 s heartbeat, play / pause / toggle / next / previous on the tab's own
  player (YouTube and TikTok pages), a `play()` refused by the autoplay policy reported once and not retried, two reconnect checks
  then silence with the PiP off, a paused tab finding a restarted daemon, two tabs with their own ids.
- `qs -p quickshell/NowPlaying/preview/tt-act.qml` (`OW_MODE`) — the TikTok row under real pointer events.
- `qs -p quickshell/NowPlaying/preview/src-act.qml` (`OW_MODE`) — the source chip and list under real pointer events (click,
  row choice, wheel, pointer leaving, one source = no chip, the short chip at the smallest size).
- `qs -p quickshell/NowPlaying/preview/mirror-test.qml` (`OW_MIRROR_FILE=<video>`) — the real MediaPlayer steered by a fake
  browser clock: start, seek, pause on the frame, 1.5×.
- `qs -p quickshell/NowPlaying/preview/parts-test.qml` (`OW_PARTS='[{"start","dur","file"},…]'`, `OW_PARTS_FROM`, `OW_PARTS_SECS`) —
  MirrorStack with real part files across a boundary: the next part preloaded and in sync before it, exactly one swap, no
  dropout to the cover, |drift| < 0.35 s.
- `qs -p quickshell/NowPlaying/preview/render.qml` (`OW_NP_CASE=landscape|portrait|spotify|hover|paused|fetching|live|nothing|narrow`,
  TikTok row: `tt-off|tt-on|tt-busy|tt-unknown|tt-error|tt-min|tt-wide`,
  `OW_MODE`, `OW_NP_STILL` = a frame of a cached video as the stand-in for the VideoOutput, which offscreen grabs cannot capture).
