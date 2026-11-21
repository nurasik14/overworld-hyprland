# nowplaying-chunks report: long YouTube videos get their picture in parts (both themes)

2026-11-15 23:37 → 2026-11-16 ~00:40 HKT. The user was at the desk.

Not done in this run:
- no dev-shot, grim, workspace switches, visible windows or sound;
- no commits, sudo or input injection;
- no player control, and the browsers were never touched;
- the PiP was not toggled, and no `~/.config/overworld/*.json` was edited.

All QML was developed in scratch copies (`/tmp/npc/{ow,apo}`), except two early saves noted below.

## Changed files
**`~/Projects/overworld-hyprland`**
| what | where |
|---|---|
| Daemon (shared). The parts planner:<br>• `update_parts` / `plan_part` / `coverage` / `drop_behind` / `parts_video`, `fetch_part` + `run_ytdlp`<br>• part pre-roll from the MP4 edit list (`video_edit_start`, `part_preroll`) and `normalise_part`<br>• `cache_entries` / `scan_parts` know part files; LRU keeps the shown video's parts<br>• `want` with `position`; `fetchingPart` in state.json<br>• serve options `--part-first-min/--part-min/--part-ahead-min/--part-height`<br>• `status` prints the part ranges, `cache list` the part files<br>• env `HYPR_NOWPLAYING_YTDLP_TIMEOUT` (tests only) | `scripts/hypr-nowplaying` |
| New: the two-player mirror (front = the part at the position, back = the next part preloaded, swap 1 s before the end; a whole file is one part) | `quickshell/NowPlaying/MirrorStack.qml` |
| Part rules: `partClock`, `pickPart`, `nextPart` (the old rules are untouched) | `quickshell/NowPlaying/sync.js` |
| Service:<br>• config `partFirstMin/partMin/partAheadMin/partHeight` → daemon args<br>• `mirrorParts` / `videoInParts` / `partsText`, status line `video parts n/m ready`<br>• `longWant()`: an MPRIS-only long video sends `want` with its position every 5 s, and at once on a jump > 3 s or on pause / play | `quickshell/NowPlaying/NowPlayingService.qml` |
| View: `VideoMirror` → `MirrorStack` (one block) | `quickshell/NowPlaying/NowPlayingView.qml` |
| Defaults + comment for the four new keys | `quickshell/Services/ConfigService.qml` |
| Harnesses: `service-test.qml` (`nptest want`, STATE `inParts/partsText/mirrorParts`); new `parts-test.qml` (real parts across a boundary) | `quickshell/NowPlaying/preview/` |
| Tests:<br>• daemon: the fake yt-dlp honours `--download-sections` and cuts a real 2 h fixture like yt-dlp; 21 new checks, 3 old checks updated for the new behaviour<br>• service: stand-in yt-dlp, 8 new checks<br>• sync: 19 new checks | `tests/hypr-nowplaying.test.sh`, `tests/nowplaying-service.test.sh`, `tests/nowplaying-sync.test.js` |
| Docs: new *Long videos: the picture comes in parts* section (how it works, measurements, where a part starts, disk), config table, files and tests | `docs/NOWPLAYING.md`, `docs/WIDGETS.md`, `CHANGELOG.md` |

**`~/Projects/apothecary-hyprland`**
| what | where |
|---|---|
| Shared copies:<br>• `scripts/hypr-nowplaying` (byte-identical with Overworld's)<br>• `MirrorStack.qml` and `sync.js` (identical with Overworld's) | `scripts/`, `quickshell/NowPlaying/` |
| Service: the same changes. Under the usual theme substitutions (`APO_`→`OW_`, `apothecary`→`overworld`) it differs from Overworld's only in the known theme bindings. | `quickshell/NowPlaying/NowPlayingService.qml` |
| View: `VideoMirror` → `MirrorStack` (`fadeMs: root.dur(Theme.durBase)`, the scroll's own fade) | `quickshell/NowPlaying/NowPlayingView.qml` |
| ConfigService comment (this ConfigService has no defaults object; the service passes the fallbacks) | `quickshell/Services/ConfigService.qml` |
| Harnesses and test: `service-test.qml`; `parts-test.qml` (`APO_PARTS…`); the same 8 service checks | `quickshell/NowPlaying/preview/`, `tests/nowplaying-service.test.sh` |
| Docs | `docs/WIDGETS.md`, `CHANGELOG.md` |

**Not changed:**
- The userscript is still 1.4.1. No change was needed: the daemon gets the position from the reports it already receives.
- NowPlayingPip, the IPC, and the theme CLIs.
  - The CLIs' `nowplaying status` forwards to the IPC status line, which now says `video parts n/m ready`.

## Measurements (live, read-only, 2026-11-15, ProtonVPN on, `CeItO4-ARfk`, 1 h 46 min)
Network budget: 4 fetches into `~/.hermes/cache/scratch/npchunks/`, which is deleted now.
1. `*50:00-51:00`, the daemon's flags at 360p: 48.1 s, 2.5 MB, format with audio (progressive).
   - The file starts at the keyframe **3.74 s before** the cut.
   - An MP4 edit list hides those frames: ffprobe `start_time` is 0, packets start at pts −3.737.
2. The same with `--force-keyframes-at-cuts` (the exact reference): 57.2 s, 2.6 MB.
   - It re-encodes to mpeg4 here (no libx264 in yt-dlp's path), so it costs +9 s and lower quality. Not used.
3. `*50:30-51:30`: **failed**, `ERROR: ffmpeg exited with code 8` (first client set).
4. One real part through the new daemon (temp dirs, random port, `want` at 3030 with `--part-first-min 1`):
   - asked `3028-3088`; ready after **84.9 s**, 1.1 MB, 640×360 H.264, video only, decodes without errors;
   - the first client set failed again with ffmpeg code 8, and `tv,mweb,web_embedded` worked;
   - the daemon then started the next (40-min) part, which was killed within ~1 s when I closed its stdin.

**The cut offsets (frame-hash alignment, 32×18 grey frames, `/tmp/npc/align.py`):**
- Uncut 50:00 part, decoded with its edit list, vs the exact reference: **−0.033 s** (one frame).
  - So the edit-list start is the asked cut, ±1 frame.
- The same part normalised (`-ignore_editlist`, video only): the reference + **3.737 s**.
- The real daemon part (asked 3028): its true start is **3024.825**, i.e. a **3.175 s** pre-roll.
  - The daemon's first method (the earliest packet in the edit-list view) said 3026.866, **2.04 s wrong**.
  - Cause: that file has two keyframes before the cut (at 0.033 and 2.068 s). ffmpeg's edit-list view starts at the nearer one and hides the rest.
- **Fix:** the pre-roll is now the edit list's `media_time` minus the raw pts of the file's first frame (box parser, no full read).
  - 50:00 sample: 3.707 s (the alignment said 3.737: one frame apart).
  - Fixtures: exact (1.0 / 2.0 / 1.3 s; the old method gave 1.5 for the last).
  - The real 50:28 part could not be re-checked with the new method: its original was already normalised, and a 5th fetch would break the 4-fetch budget.
  - Its keyframe layout matches the explanation exactly, and the new method uses the file's first frame by definition.
- **Qt position semantics (offscreen, QtMultimedia 6.11.2):** a file with `start_time` 5.0 reports position ≈ 1.03 s after 1.2 s of play, i.e. Qt subtracts the container start time.
  - So `part.start = asked start − pre-roll` maps a player position q to timeline `start + q` with no further term.

## Decisions (**DEVIATION** where the design said otherwise)
- **Overlap 8 s plus the pre-roll.** The next part is asked from `end − 8 s`; yt-dlp adds the keyframe pre-roll (2–4 s measured) on top. The first part starts 2 s before the position.
- **Normalised parts** (addition): every part is remuxed with `ffmpeg -ignore_editlist -map 0:v:0 -c copy -avoid_negative_ts make_zero +faststart`.
  - Video only and no edit list, so the frame for a position does not depend on how a player treats edit lists.
  - Measured 40 % smaller (the progressive 360p format carries audio).
- **The true start is stored in the file name** (`youtube-<id>.part-<startMs>-<endMs>.mp4`), so a restart needs no probe.
- **Planning is stateless:** each report, `want` and once-a-second housekeeping tick recompute "what is due" from the position and the parts on disk.
  - A part already on its way that covers what is needed is kept, not restarted.
  - Contiguous means ≥ 1 s of overlap. The status is `ready` when a part covers the position with ≥ 1 s left.
- **Failed parts** wait 60 s before a retry (doubling, max 10 min). A timeout is per request (300 s, as before).
- **No `--max-filesize` and no duration match-filter for parts** (**DEVIATION**, required): yt-dlp judges `--max-filesize` on the whole format, so a 3-hour video would be refused. Only `!is_live`.
- **A whole file already in the cache wins** over parts (e.g. one fetched while `maxVideoMin` was 120).
- **Shell swap rule** (sync.js `SWAP` = 1 s):
  - The front player keeps its part until 1 s before its end. Then the preloaded part, already in sync since the browser reached its start, goes on top. The old one stays visible underneath for 600 ms.
  - With no current part (start, seek), the covering part that reaches furthest is chosen.
  - A jump outside the front part loads the right part straight into the front; the cover shows until its first frame.
- **MPRIS-only:** `want` gains `position / paused / rate`. The daemon's housekeeping re-plans the shell's `active` key once a second.
- **TikTok** is unchanged: clips longer than `maxVideoMin` still show the cover.
- **Old checks updated, with their meaning changed by design:**
  - "too long → skipped" is now "too long → parts, not the whole file";
  - "too long in one report → skipped (soft)" is now "→ parts";
  - "no second download" now ignores part lines.

## Verified (and how)
- **Daemon** `bash tests/hypr-nowplaying.test.sh`: **165 passed, 0 failed** (144 old + 21 new). The same suite against Apothecary's copy: **165 passed**.
  - The new checks run with a fake yt-dlp that cuts a real 2 h libx264 test video with `ffmpeg -ss … -c copy` (as yt-dlp does, edit list included):
  - the first part at the position and short, with no whole-file fetch;
  - the true start = the keyframe before the cut (2995 for a cut at 2999); the file is named after its range, video only, and decodes;
  - no next part while > 30 s is ahead; the next part when < 30 s is left (starting 8 s before the end, contiguous with ≥ 1 s overlap);
  - `status` shows the ranges; paused inside the range → nothing new;
  - a seek outside → a new short part, and parts > 10 min behind are deleted;
  - parts survive a restart (ready at once, no fetch);
  - a slow part is killed when the tab switches video, and the short video is fetched whole;
  - an MPRIS `want` with a position → its first part;
  - LRU over the cap keeps the shown video's parts (even the oldest file) and deletes others;
  - a part over the per-request timeout → `failed: timed out`, not retried at once.
- **Service** `bash tests/nowplaying-service.test.sh`:
  - **80 passed, 0 failed** in Overworld (72 + 8), run from the scratch copy before installing;
  - **80 passed** in Apothecary.
  - New: a long video → parts mode with the first part asked at the position; the mirror gets the part with start 2995 (the keyframe) and `videoFile` stays empty; the status line `video parts n/m ready`; `longWant` carries position / duration / paused / rate, stays quiet within 5 s, and sends at once after a jump or on pause, then again after 5 s.
  - The service test now has a stand-in yt-dlp, so it never touches the network. Before, a made-up YouTube id reached the real yt-dlp.
- **Sync** `node tests/nowplaying-sync.test.js`: **44 passed** (25 + 19).
  - partClock: with the measured pre-roll, before the part (paused on frame 0), a whole file.
  - pickPart: inside the overlap, the swap point, a gap → −1, a seek.
  - nextPart, and a simulated 100 s hand-over: exactly one swap, never without a part.
- **Playback offscreen** (`preview/parts-test.qml`, real QtMultimedia, no window on screen, no audio output):
  - **Real 360p parts** (the 50:00 sample normalised + the daemon's 50:28 part with its frame-verified start), from 3021 across the boundary at 3060.05:
    - the next part preloaded and ready behind;
    - **exactly one swap at 3059.3**, **no dropout** to the cover;
    - drift ≈ 0.05 s before and after (worst 0.22 s on one sample at start-up).
  - **Fixture parts:** the same 6/6 PASS in Overworld and in Apothecary.
  - **ffmpeg decode check** of the real part: 0 errors.
- **Pointer harnesses with the new view:**
  - Overworld (scratch) `act` 14/14, `src-act` 17/17, `tt-act` 11/11, in Day and Night;
  - Apothecary `render.sh <dir> act src-act tt-act`: all `ok` in both modes.
- **Bridge** `bash tests/nowplaying-bridge.test.sh`: **91 passed, 0 failed** (the userscript is unchanged).
- **`cmp`:**
  - `scripts/hypr-nowplaying`: **identical** in both repos;
  - `apps/zen/nowplaying-bridge.user.js`: **identical** (unchanged);
  - `MirrorStack.qml` and `sync.js`: identical in both repos.
- `py_compile` passes on the daemon; `bash -n` passes on the three test scripts. `__pycache__` was removed.
- **Live, read-only:**
  - All final Overworld QML went in with one `cp` burst at 00:25:30. The log shows **one** "Reloading configuration… / Configuration Loaded".
  - `ipc call nowplaying status` → `off, daemon stopped, nothing playing`. The PiP is **off** in `nowplaying.json` now; I never toggled it (the brief said it was on, so someone changed it).
  - The daemon gets the new `--part-*` arguments the next time the PiP is turned on.
  - Apothecary is not running live; its files were copied after they passed in scratch.

## Live reloads I caused (for the orchestrator)
1. **Two early saves of `quickshell/NowPlaying/sync.js` straight into the live tree (~00:05).** The live shell imports it via VideoMirror, so they most likely caused the two reloads at log lines 54017 / 54158. Both loaded cleanly, but they reset the brew timer.
   - After that I moved to scratch copies.
   - The change was additive: VideoMirror's rules were untouched.
2. **The final install (00:25:30):** one reload.
   - It logged three one-time warnings: `NowPlayingService.qml[457:5]` / `[531:5]: Unable to assign [undefined] to bool`.
   - These are reload-time initialisation order: the line numbers do not point at bool bindings in the new file, and fresh offscreen starts (service suite, harnesses) print no such warning.
   - Listed under open issues.

## NOT verified
- **Real playback on screen** (the user's check): the swap is invisible offscreen by construction, but not seen with eyes.
- **A real long session:**
  - a 40-min part (its time is extrapolated: ≈ 95 s, or ≈ 135 s when the first client set fails, as it did for 2 of 3 cuts);
  - the next part arriving while you watch;
  - a real seek in the browser.
- **The edit-list pre-roll method on the real 50:28 part itself:** its original was gone, see above. It is verified on the real 50:00 sample and on fixtures, and the keyframe layout of the 50:28 file matches.
- **The MPRIS-only path with a real player:** it is covered by the `longWant` checks and the daemon's `want` checks only.
- **Disk-use numbers for 40-min parts:** extrapolated from 1-min parts (1.1–1.5 MB per minute video-only, measured).

## Open issues
- **"ffmpeg exited with code 8"** with the `default,tv,mweb` clients on 2 of 3 cuts (50:30, 50:28; 50:00 worked); the fallback clients worked.
  - Each such part pays ~40 s extra. If it keeps happening, try `tv,mweb,web_embedded` first for parts.
  - I left the order as is (too few samples).
- The three reload-time "Unable to assign [undefined] to bool" warnings (above).
- A killed daemon leaves its yt-dlp work dir (`.ytdlp-*`). This was already so for whole files; `prune` removes them after an hour.

## Please try (user)
1. Turn the PiP on (SUPER+ALT+P). The daemon restarts with the new options.
2. Play a YouTube video longer than 20 min (with your `maxVideoMin 120`: longer than 2 h; or set it back to 20) and jump into the middle.
   - After about a minute (up to ~2 min on the VPN) the picture should appear and follow the browser.
   - `overworld nowplaying status` says `video parts 1/2 ready` (the next part on its way).
3. Keep watching past the first 5 minutes: the picture should go on without a flash. `hypr-nowplaying status` lists the ranges.
4. Seek far ahead: the cover with "Fetching video…", then the picture again after ~1 min.
5. `hypr-nowplaying cache list` shows the part files. Parts more than 10 min behind disappear as you watch.
