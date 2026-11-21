# nowplaying-sources report — choose which tab / app the Now Playing PiP shows (both themes)

2026-11-15. The user was at the desk. Not done: dev-shot or grim, workspace switches, on-screen windows, sound, commits, sudo,
input injection, player control. Zen was never opened or driven, and the PiP was never turned on.
All QML was developed in a scratch copy (`/tmp/nps/{ow,apo}`, deleted at the end). The live Overworld QML was copied in with **one
`cp`** at 22:33:28. That caused **exactly one live reload**, and `~/.cache/overworld/qs.log` shows no new error (only the old
`TimeService.qml[15:5]` warning). The PiP is still **off** (`~/.config/overworld/nowplaying.json` `on:false`; the live
`ipc call nowplaying status` gives `off, daemon stopped, nothing playing`). Apothecary is not running live; its files were
copied in after they passed in scratch.

## Changed files
**`~/Projects/overworld-hyprland`**
| what | where |
|---|---|
| Daemon, shared:<br>• `tabs` list in state.json (every fresh tab, same cleaning as `bridge`, plus `received`, `pinned`, `bv`, `done`; newest/playing first, max 12)<br>• `pin` in state.json; stdin `{"cmd":"pin","tab":id\|null}`; `select()` prefers the pin<br>• The pin is released when the tab sends `gone`, expires, or is never seen within 10 s<br>• Media actions `play\|pause\|toggle\|next\|previous` go through the per-tab queue. They work for any site and are not bound to a clip.<br>• `done` result for any site; `poll` for the pinned tab and for a tab with a command waiting; `keepalive: 2` in every reply<br>• `status` lists the tabs; help and privacy text updated | `scripts/hypr-nowplaying` |
| Userscript **1.4.0**, shared:<br>• `bv` + `done` in every report<br>• poll for any site; `keepalive` slow heartbeat while paused<br>• `runMedia`: play/pause on its own `<video>`. Next/previous = YouTube `.ytp-next/prev-button`, YT Music `.next/.previous-button`, TikTok `feedStep`. Previous with no button = back to the start.<br>• A `play()` refused by autoplay (NotAllowedError) is reported and not retried<br>• Two reconnect checks (3 s, 10 s) after a linked daemon disappears | `apps/zen/nowplaying-bridge.user.js` |
| Service:<br>• `sources` (`buildSources`), stable order<br>• `pinnedId` / `auto`, `choose(id)`, `pick(n\|next\|prev\|auto)`, `sourcesText()`, `restorePin()`<br>• Pin release (3 s gone, 20 s after the daemon starts)<br>• Daemon `pin` sync<br>• `route` (mpris / tab / none), `tabMedia`, `controlsNote`<br>• `fromMpris()`, `siteLabel()`, `versionAtLeast()`<br>• `testToplevel` test hook; status line `source auto\|pinned i/n` | `quickshell/NowPlaying/NowPlayingService.qml` |
| IPC `sources` / `pick`. Now a `Scope` that holds the `PersistentProperties` for the pin. | `quickshell/NowPlaying/NowPlayingIpc.qml` |
| View:<br>• source chip (McButton, top left; pin glyph; short `i/n` when narrow; wheel)<br>• the list inside the picture (dark game-list fill, white frame = choice, ▶/⏸, site colour, title elided, McScrollbar)<br>• LIVE/Ad badge hidden under the chip<br>• error line also for tab-routed commands<br>• transport tooltips show `controlsNote` | `quickshell/NowPlaying/NowPlayingView.qml` |
| Harnesses:<br>• `render.qml`: `src-*` cases<br>• `service-test.qml`: `nptest fullscreen`, `control`, `sourcesWith`, new STATE fields<br>• new pointer test `src-act.qml` | `quickshell/NowPlaying/preview/` |
| Tests | `tests/hypr-nowplaying.test.sh`, `tests/nowplaying-service.test.sh`, `tests/nowplaying-bridge.test.sh`, `tests/nowplaying-bridge/{harness.js,make-pages.sh}` |
| CLI `overworld nowplaying sources` / `pick <n\|next\|prev\|auto>` + help | `scripts/overworld` |
| Docs: new *Several tabs or apps* section (chip, list, wheel, IPC/CLI, Auto vs pinned, the one-MPRIS-per-browser limit, bridge 1.4.0, maximized vs fullscreen); Commands and Tests sections updated | `docs/NOWPLAYING.md`, `docs/WIDGETS.md`, `CHANGELOG.md` |
| Renders | `qa/screenshots/nowplaying-sources-src-{chip,list,one,min-chip,min-list,wide-list}-{light,dark}.png` |

**`~/Projects/apothecary-hyprland`**
| what | where |
|---|---|
| Shared files, byte-identical copies | `scripts/hypr-nowplaying`, `apps/zen/nowplaying-bridge.user.js` |
| Service and IPC. They are generated from Overworld's with the same theme-binding substitutions as before: applying those substitutions to the *old* Overworld service reproduces the *old* Apothecary one exactly, so nothing Apothecary-specific was lost. | `quickshell/NowPlaying/NowPlayingService.qml`, `NowPlayingIpc.qml` |
| View in its own look:<br>• paper chip with a vermilion pin and border when pinned<br>• a paper-slip list inside the picture, vermilion rule on the chosen row, ink scroll line<br>• the transport tooltip says "Needs the bridge userscript 1.4.0" (its tooltips are one short line) | `quickshell/NowPlaying/NowPlayingView.qml` |
| Harnesses: `src-*` cases and an `src-act` case in render.sh; new `src-act.qml` | `quickshell/NowPlaying/preview/{render.qml,render.sh,service-test.qml,src-act.qml}` |
| Tests (the Overworld test with `APO_` names, as before) | `tests/nowplaying-service.test.sh` |
| CLI `apothecary nowplaying sources` / `pick` + help + overview line | `scripts/apothecary` |
| Docs | `docs/WIDGETS.md` (Now Playing → *Several tabs or apps*), `CHANGELOG.md` |
| Renders | `qa/screenshots/nowplaying-src-{chip,list,one,min-chip,min-list,wide-list}-{light,dark}.png` |

## Decisions (deviations from the orchestrator's design marked **DEVIATION**)
- **Source ids** are `tab:<tab>` and `mpris:<dbusName>`.
  - Rows keep their **order of first appearance**, so numbers and the wheel stay stable. The daemon's own order changes every
    time play/pause changes.
  - An MPRIS player is skipped when it is Stopped or has neither a title nor art.
  - A browser player whose title matches a listed tab is that tab (the existing `sameTitle`).
  - A paused tab is listed only while some browser MPRIS player exists (the old "browser quit" rule).
- **Wheel / `next` / `prev` cycle Auto → 1 → … → n → Auto.** Auto is part of the cycle, so the wheel alone can get you back to it.
- **The chip is shown with 2+ sources, or while pinned.** That way you can always get back to Auto, even when only the pinned
  source is left.
- **Pin release: gone for 3 s, but only once the daemon has run for 20 s** (**DEVIATION**, an addition).
  - A shell reload restarts the daemon with an empty tab list. Without this grace, a reload would drop every pin.
  - Measured in scratch: a pin survives the reload, comes back in the list, and is re-sent to the new daemon.
- **`PersistentProperties` live in `NowPlayingIpc` (now a `Scope`), not in the service singleton** (**DEVIATION**, required).
  - A minimal test showed that `PersistentProperties` inside a `Singleton` do **not** survive a reload. The singleton is created
    lazily, after the restore pass. In a `Scope` they do.
  - `NowPlayingIpc` already sits in NowPlayingPip and in the test harness, so no other file needed a change.
- **Controls route:**
  - **mpris** when the source is a player, or when the browser player's title matches the shown tab.
  - **tab** (through the daemon) when it does not match and either the tab is pinned, or Auto has 2+ tabs, or there is no browser
    player. This needs the report's `bv` ≥ 1.4.0.
  - Otherwise, Auto keeps **today's MPRIS behaviour**. That covers one TikTok tab, whose MPRIS title differs from its description,
    and older bridges.
  - A **pinned** tab with an older bridge gets **no** controls, with a tooltip that says why. Controlling Zen's player would hit
    the wrong tab.
  - ⏯ sends an explicit `play` or `pause` (from the shown state), not `toggle`, so a stale state cannot invert it.
- **Media commands are not bound to a clip** (TikTok actions still are): "pause what this tab plays" is still right after
  autoplay moves to the next video. They share the one-command-per-tab queue with like / repost / save.
- **Heartbeat** (the design asked for "a paused pinned tab gets commands within ~1.5 s"):
  - The daemon's reply has `poll` (1 s heartbeat while paused) for TikTok tabs, the pinned tab, and a tab with a command waiting.
  - **`keepalive: 2`** (**DEVIATION**, an addition): every paused tab reports every 2 s while the PiP is on. A paused tab is
    otherwise silent and would never learn that it was pinned.
  - So the first command after pinning a tab that had gone quiet takes ≤ 2 s to reach it; after that, ≤ ~1.5 s (tested: 1.5 s).
  - With the PiP off nobody answers, so nothing is sent. The exception is **two reconnect checks 3 s and 10 s after a linked
    daemon disappears**. Without them, a shell reload would drop paused tabs from the list until they play again.
  - The old harness stub sends no `keepalive`, so the existing "nothing while paused" tests keep their meaning.
- **`bv`** (userscript version) is in each report, so the shell knows whether per-tab buttons work.
- **Focus** focuses the Zen **window** of the source (the existing title / activated / first match). The exact tab cannot be
  selected from outside the browser (documented).
- **Not changed**: NowPlayingPip.qml, ConfigService (no new config keys), keybinds.

## Verified (and how)
- **Daemon** `bash tests/hypr-nowplaying.test.sh`: **144 passed, 0 failed** (119 old + 25 new). The same suite against
  Apothecary's copy: **144 passed**.
  - New checks: the tabs list in order; cleaning (control characters, a foreign thumbnail, `bv` junk dropped); keepalive and no
    poll for an unpinned paused tab; pin → `state.pin` and the pinned paused tab is `bridge`; poll for the pinned tab; the video
    fetch follows the pin; a playing other tab does not take over; a bad pin id is ignored.
  - Media commands: queued, delivered without a collection, `done` → done, a failed `next` → failed with a cleaned error,
    delivered after the video changed, poll for an unpinned tab with a command waiting, unknown tab / action refused.
  - Pin lifecycle: status lists the tabs with the pin marked; unpin → automatic; the pin is released on `gone`, on expiry of a
    playing tab, and for a tab never seen (10 s); a media command expires after 10 s and is never delivered; stdin EOF → stopped
    state with `tabs: []`, `pin: null`.
- **Userscript** `bash tests/nowplaying-bridge.test.sh` (headless Chromium, fixtures): **91 passed, 0 failed** (72 old + 19 new).
  - Two new fixture tabs: `yt-media` and `tiktok-media`, with different tab ids.
  - Reports carry `bv`; the paused keepalive (2–3 reports in 4.5 s); the pinned 1 s heartbeat (2–4 in 3 s).
  - **Play reaches the paused pinned tab within 1.5 s**; pause; toggle; next → the player's next button; previous without a visible
    button → back to the start.
  - **A refused `play()` (NotAllowedError) → an "autoplay" error, play() called once (no retry)**.
  - PiP off → the failing report + ≤ 2 reconnect checks, then **0 requests in 3 s**.
  - A paused tab finds a restarted daemon by itself and the keepalive resumes.
  - TikTok: play, next = the feed button, like still works next to them.
  - Only 127.0.0.1 is contacted.
- **Service** `bash tests/nowplaying-service.test.sh` (private offscreen qs, real daemon child, temp everything, dry-run MPRIS):
  **72 passed, 0 failed** (45 old + 27 new) in Overworld, **72 passed** in Apothecary.
  - One source → one row.
  - Two tabs → two ordered rows, Auto shows the playing one; `ipc sources` format.
  - `ipc pick 2` → pinned, the paused tab shown; the daemon got the pin; status line `source pinned 2/2`.
  - Controls: route = tab, ⏯ → `play` queued for **that** tab, delivered in its reply, done → the PiP shows playing; ⏭ → `next`
    for that tab; a refused command shows its reason.
  - Older bridge pinned → no controls.
  - pick: next from the last row → auto, prev from auto → last, wrap, auto, a bad number refused; the daemon pin returns to null.
  - **The pinned tab closes → Auto within ~3 s**.
  - **Dedupe with stand-in MPRIS players** (Zen with a matching title folded into the tab; Spotify and Chromium as their own rows;
    no browser player → paused tabs dropped).
  - **Maximized (fullscreen 1) → shown, fullscreen (2) → hidden**, 3 → hidden, back to normal → shown.
  - `NP_WITH_MPRIS=0` (the user's real players merged, read-only, controls dry-run) → **47 passed, 0 failed, 25 skipped by design**:
    the exact-list checks are `det`, like the existing ones, because a real playing player adds rows.
- **Pin across a reload** (scratch, offscreen, a real content change to the loaded QML → "Reloading configuration…"): after the
  reload `pinned` was still `tab:tabAA`; once the tabs reported to the new daemon it was shown again and the daemon's `pin` was
  re-sent. The first attempt (PersistentProperties in the singleton) failed this check, which led to the move into `NowPlayingIpc`.
- **Pointer tests** (QtTest events into an offscreen window):
  - Overworld `preview/src-act.qml` **17/17 PASS** in Day and Night: chip text `YouTube 1/3`; click opens the list (not a drag,
    inside the PiP, 4 rows); a row → `choose("tab:b")` and the list closes; pin glyph; Auto row → `choose("")`; wheel down/up →
    `pick next/prev` without moving the PiP; pointer leaving closes the list; one source → no chip; at the smallest portrait size
    the chip is `1/2` and ends before the focus button.
  - Existing `act.qml` and `tt-act.qml`: 0 failed in both modes.
  - Apothecary `render.sh <dir> src-act act tt-act`: all `ok` in both modes.
  - These ran from both repos, not only from scratch.
- **Renders** (offscreen, Day + Night, all viewed): chip with 3 sources, the open list, chip hidden with 1 source, and the minimum
  sizes (portrait chip, portrait list, landscape list with scrollbar). Nothing overflows; titles elide.
  - Overworld: `qa/screenshots/nowplaying-sources-src-*-{light,dark}.png`.
  - Apothecary: `~/Projects/apothecary-hyprland/qa/screenshots/nowplaying-src-*-{light,dark}.png`.
  - The "video" in them is a crop of a cherry-grove world wallpaper (`/tmp/nps/np/still-{169,916}.png`, made with magick). The
    earlier cached stills in `~/.hermes/cache/scratch/np/` were gone, and VideoOutput cannot be captured offscreen anyway.
- **Shared files**: `cmp scripts/hypr-nowplaying ~/Projects/apothecary-hyprland/scripts/hypr-nowplaying` and
  `cmp apps/zen/nowplaying-bridge.user.js …` → **identical**. `node --check` userscript, `py_compile` daemon, `bash -n` on both
  CLIs.
- **Live (read-only)**: one reload, no new log errors. `ipc call nowplaying sources` → `the PiP is off (nowplaying on)`;
  `ipc show` lists `sources` and `pick`; `overworld nowplaying sources` answers the same; the PiP stays off. `pick` was never
  called live.
- `node tests/nowplaying-sync.test.js` → 25 passed (unchanged).

## NOT verified
- **Real Zen tabs**: the userscript ran only in headless Chromium on fixtures. Not checked on real pages:
  - multiple real YouTube / TikTok tabs reporting at once;
  - YouTube's real `.ytp-next-button` / `.ytp-prev-button` and YT Music's `.next-button` / `.previous-button`;
  - Violentmonkey's GM API.
- **Background-tab `video.play()` in Zen**: whether Firefox's autoplay policy allows it for a tab that already played (usually it
  does after a user gesture on that page) is **not verified**. A refusal is reported ("click the tab once") and not retried.
- The chip and list on the real screen: the layer, a real pointer, the tooltip, and the wheel on a real mouse / touchpad.
- Apothecary's live shell (not running).

## Live PiP state at the end (for the orchestrator)
At the final check (22:42) `~/.config/overworld/nowplaying.json` read `on: true`, and its position had been moved to the top-right
corner (`dx 0, dy 0`). The file was written at 22:41:29–30, and the live `qs -c overworld` (pid 4144) started its daemon child at
22:41:29. None of my commands could do that:
- every test used a temp `OW_NOWPLAYING_STATE` / `HOME` and private `qs -p` instances;
- the only live IPC calls were `status` / `sources` / `ipc show`, at about 22:35;
- `pick` was never sent live.

An on/off switch followed within a second by a drag means a person at the PiP: most likely the user pressed SUPER+ALT+P or used
the widgets menu, then dragged it. **I left it as it is** (rule: never toggle it). The live shell log has no new NowPlaying line
since my one reload. The live daemon reports `tabs: 0`, because the installed userscript is still 1.3.0.

## Open issues
- **Paused tabs before the PiP is on**: a tab that paused while the PiP was off stays silent. It appears in the list only after it
  plays, pauses, seeks, or the page becomes visible. Same as before for the single-source PiP; documented.
- Zen tabs on sites the userscript does not match can only appear as Zen's one MPRIS row (documented limit).
- The Apothecary list scroll line at the smallest landscape size is thin and hard to see in the render (the list scrolls with the
  wheel; Overworld's McScrollbar is clearly visible).
- I removed a `scripts/__pycache__` that `py_compile` created (it was a cache; nothing tracked).

## Please try (user)
1. Reinstall the bridge (it is **1.4.0** now): `overworld nowplaying userscript --serve`, open the printed URL in Zen, press
   **Install**, reload your YouTube / TikTok tabs.
2. Turn the PiP on (SUPER+ALT+P). Play YouTube in one tab, open another YouTube (or TikTok) tab, play it, then pause it.
3. Hover the PiP: a chip like `YouTube 1/2`. Click it, pick the other tab: the PiP shows it (paused) and stays on it.
   ⏯ should start **that** tab (within ~1 s). If it says the browser refused, click that tab once and try again.
4. Wheel over the chip: Auto → 1 → 2 → Auto. Close the pinned tab: after ~3 s it goes back to Auto by itself.
5. Spotify + YouTube at once: both are listed; pick Spotify, and ⏯ controls Spotify.
6. Terminal: `overworld nowplaying sources`, `overworld nowplaying pick 2`, `overworld nowplaying pick auto`.
7. Maximize Zen (not fullscreen): the PiP should stay visible; real fullscreen still hides it.

## Requests filed
None. Every file I changed is in the NowPlaying module, the shared daemon / userscript and their tests, the theme CLIs' nowplaying
verbs, or the docs named in my prompt.
