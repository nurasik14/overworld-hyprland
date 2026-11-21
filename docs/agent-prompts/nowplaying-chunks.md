# nowplaying-chunks: stream long YouTube videos into the PiP in parts (both themes)

The user: long videos never get a moving picture in the PiP. His idea (decided with the orchestrator, final): download the
mirror in PARTS around the playback position instead of one whole file — "download the first 40 minutes, and when 5 minutes
are left start downloading the next 40".

BOTH themes: Overworld (this repo) and Apothecary (`~/Projects/apothecary-hyprland`). `scripts/hypr-nowplaying` and
`apps/zen/nowplaying-bridge.user.js` are SHARED and must stay byte-identical (`cmp` at the end).

Read first: BRIEF.md (§1 rules), docs/agent-reports/now-playing-pip.md, docs/agent-reports/nowplaying-sources.md (newest
design: sources, pins, per-tab commands), docs/NOWPLAYING.md, `scripts/hypr-nowplaying` (fetch worker ~L800-900: `want`,
`YTDLP_FORMAT`, `YTDLP_CLIENTS`, `YTDLP_TIMEOUT`, `js_runtime_args`, cache/LRU, `video_info`, `set_video`, `on_state`),
`quickshell/NowPlaying/{NowPlayingService,VideoMirror,NowPlayingView}.qml`, `quickshell/NowPlaying/sync.js`, the tests in
`tests/` (hypr-nowplaying, nowplaying-service, nowplaying-sync, nowplaying-bridge), and the Apothecary copies.

## Facts already verified by the orchestrator (2026-11-15, live, this machine, ProtonVPN on)
- Today's whole-file fetch of a 1 h 46 min video (`youtube-CeItO4-ARfk`, duration 6377.9 s) FAILED with "timed out": every
  fetch is capped by `YTDLP_TIMEOUT = 300` s, and it ran ~160 KB/s. So long videos can never get a mirror today.
- Partial downloads work with the daemon's own flags plus `--download-sections`:
  `yt-dlp --ignore-config --no-playlist --no-progress --quiet --no-warnings --socket-timeout 20
   -f "bv*[height<=360][vcodec^=avc1]/bv*[height<=360][ext=mp4]/bv*[height<=360]" --remux-video mp4
   --download-sections "*50:00-55:00" -o "s.%(ext)s" <js runtimes> --extractor-args youtube:player_client=default,tv,mweb <url>`
  Results: `*50:00-51:00` → 43.9 s, 2.6 MB, 60.12 s long, 360p. `*50:00-55:00` → 49.1 s, 12.4 MB, 300.06 s long, 360p.
  So ≈ 40 s fixed cost per request (extraction / bot wall / JS) + ≈ 1.3 s and ≈ 2.5 MB per minute of video at 360p.
  A 40-min part ≈ 95 s / ≈ 100 MB (extrapolated, not measured).
- NOT measured: where exactly each part starts on the video's timeline. Without `--force-keyframes-at-cuts`, the cut may land on
  the nearest keyframe (the 1-min part was 60.12 s). You must measure the true offset (e.g. download two overlapping parts and
  align by frame hashes with ffmpeg, or compare ffprobe `start_time` / packet pts) and handle it — the mirror must stay within
  the existing drift tolerance (~0.35 s). `--force-keyframes-at-cuts` re-encodes: measure its cost if you consider it.
- Cached whole-file mirrors today are 0.2–4 MB per minute (mostly 360p). The PiP's default width is 360 px, so 360p is enough.
- The user's live config now has `nowplaying.maxVideoMin 120`, `cacheMB 2000` (raised today while experimenting). Do NOT edit
  `~/.config/overworld/*.json`; the orchestrator restores it afterwards.
- Bridge 1.4.1 is installed in Chrome (Tampermonkey) and reports exact position; Zen still has 1.3.0. Do NOT change the
  userscript unless it is truly needed (a change means the user reinstalls it in two browsers); if you must, bump to 1.5.0.
- The PiP is ON in the live session — leave on/off alone.

## Design (decided; record any deviation and why)
1. When: videos up to `maxVideoMin` (default 20) keep today's whole-file fetch. Longer YouTube videos (not live) use PARTS.
   No upper length limit for parts.
2. Parts, all at ≤360p (new `YTDLP_PART_FORMAT`): the first part starts at the CURRENT position (not 0:00) and is short
   (`nowplaying.partFirstMin`, default 5) so the picture appears in about a minute; then contiguous parts of
   `nowplaying.partMin` (default 40). The next part is fetched when the contiguous buffered range ahead of the position is below
   `nowplaying.partAheadMin` (default 5). A jump (seek) outside the buffered range → drop the plan, new short part at the new
   position, then continue. Overlap parts by a few seconds so a keyframe-aligned cut never leaves a gap.
3. The daemon owns the plan (it already gets positions from bridge reports; for MPRIS-only sources extend the shell's `want`
   with the position and duration). One yt-dlp at a time as today; a part fetch is superseded when the active key changes.
   Per-request timeout stays 300 s (a 40-min part is ~95 s).
4. State: `videos[key]` gains `parts: [{start, dur, file, status}]` (true timeline start after your offset measurement) +
   `mode: "parts"`; status `ready` once the part covering the position is there. Keep `file` for whole-file videos as today.
5. Shell: the mirror maps browser position → (part, offset in part). Preload the next part in a second hidden player before the
   boundary and swap without a visible flash; seek correction as today (`sync.js`). Cover/thumbnail while nothing covers the
   position. Status line e.g. `video parts 2/3 ready`.
6. Disk: parts are cache files under the existing cache dir and LRU (`cacheMB`); drop parts more than ~10 min behind the
   position for the active key; never delete the part being played or preloaded.
7. Config keys (both themes' ConfigService defaults + docs): `nowplaying.partFirstMin 5`, `partMin 40`, `partAheadMin 5`,
   `partHeight 360`.

## Tests (keep ALL existing ones passing: daemon 144, bridge 91, service 72 in each theme, sync 25 today)
- Daemon (fake yt-dlp that honours `--download-sections` and writes fixture mp4s of the right length; extend the existing fake):
  first part at the position, next part triggered at <5 min ahead, contiguous + overlap, seek outside → new plan, superseded
  on key change, LRU/prune keeps current + preload, parts survive a daemon restart (cache scan), whole-file path unchanged for
  short videos, timeout per part.
- sync/node: position → (part, offset) incl. overlap and the measured start offset; boundary preload/swap decisions.
- Service: parts mode chosen for long videos, status line, MPRIS-only `want` carries position.
- ONE live check (network, read-only, ≤ 4 small fetches of `CeItO4-ARfk` or a similar public long video into a scratch dir under
  `~/.hermes/cache/scratch/`, deleted afterwards): the offset measurement above + one real part played through your code path
  offscreen (ffmpeg decode check, no window, no sound).

## THE USER IS AT THE DESK (hard rules)
No scripts/dev-shot.sh, no grim, no workspace switching, no visible test windows, no sound (no mpv/ffplay/pw-play), no git
commits, no sudo, no input injection, never control his players, never open/drive his browsers, never toggle the PiP or edit
~/.config/overworld/*.json. Visual checks = OFFSCREEN renders only. The live `qs -c overworld` hot-reloads on EVERY QML save
(resets the brew timer): develop in a scratch copy, write each live QML file's final version in as few saves as possible,
every save valid; check `~/.cache/overworld/qs.log` after saves. The live daemon is a child of the shell: it restarts when its
command line changes; do not kill it yourself. Do NOT run `hypr-nowplaying userscript --serve`. No independent review subagent;
aim to finish within ~60 min of work.

## Docs
docs/NOWPLAYING.md + docs/WIDGETS.md (both repos): long videos in parts (how it works, the numbers above as "measured on the
author's VPN", the config keys, seeking, disk use), and that `maxVideoMin` now only decides whole file vs parts. CHANGELOG both.

Report in docs/agent-reports/nowplaying-chunks.md: changed files (both repos), decisions + deviations, the measured cut offsets,
verified vs NOT verified (real playback on screen is the user's check), `cmp` results, test counts, and a short "please try" list.
