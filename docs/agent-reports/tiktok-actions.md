# tiktok-actions report — Like / Repost / Save-to-collection buttons on the Now Playing PiP (both themes)

2026-11-10. The user was at the desk: no dev-shot/grim, no workspace switch, no on-screen windows, no sound, no commits, no sudo,
no player control, never opened or drove Zen, never touched TikTok. Visual checks are offscreen renders (viewed). Both repos' QML was
developed in a scratch copy (`/tmp/tta/{ow,apo}`, deleted at the end) and copied in once: **the live `qs -c overworld` reloaded exactly
once** (18:52), with no new log line from NowPlaying (only the old `TimeService.qml[15:5]` warning). The live PiP is on; the user's
installed userscript is still 1.2.0, so the buttons stay hidden until the 1.3.0 install.

## Changed files
**`~/Projects/overworld-hyprland`**
| what | where |
|---|---|
| Daemon (shared): stdin `action` command, per-tab queue (one at a time), delivery in the `/state` reply (`actions`, `poll`), `tt` sanitising (`clean_tt`), `action` record in state.json, expiry (10 s queued / 40 s running), refusal records, `status` lines, help/privacy text | `scripts/hypr-nowplaying` |
| Userscript **1.3.0** (shared): like / repost / save runner on TikTok's own buttons, clip-id check, `tt` state in reports, heartbeat while paused only while the daemon says `poll`, `feedStep` uses `feed-navigation-prev/next` first, watchdog pauses while a command runs | `apps/zen/nowplaying-bridge.user.js` |
| Service: `tt`, `canLike`, `liked/saved/reposted`, `busy`, `actionError(For/Fresh)`, `actionRecord`, `tiktokCollection`, `act("like"\|"repost"\|"save")` → `tiktokAct`, status line | `quickshell/NowPlaying/NowPlayingService.qml` |
| View: second hover row (`TtButton` = McButton) above ⏮ ⏯ ⏭, taller bottom gradient, red `!` error line above the row | `quickshell/NowPlaying/NowPlayingView.qml` |
| Harnesses: TikTok render cases, `nptest` IPC hook + new STATE fields, new pointer test | `quickshell/NowPlaying/preview/{render,service-test,tt-act}.qml` |
| Tests | `tests/hypr-nowplaying.test.sh`, `tests/nowplaying-service.test.sh`, `tests/nowplaying-bridge.test.sh`, `tests/nowplaying-bridge/{harness.js,make-pages.sh,run.js}` |
| Docs | `docs/NOWPLAYING.md` (new section *TikTok: like, repost, save to a collection*, privacy, API, config, tests), `docs/WIDGETS.md`, `CHANGELOG.md`, this report |

**`~/Projects/apothecary-hyprland`**
| what | where |
|---|---|
| Shared files, byte-identical copies | `scripts/hypr-nowplaying`, `apps/zen/nowplaying-bridge.user.js` |
| Service: the same TikTok block as Overworld (only theme bindings differ, as before) | `quickshell/NowPlaying/NowPlayingService.qml` |
| View: `Chip` gains `fill` (filled = on, like the seal chip), TikTok chip row above ⏮ ⏯ ⏭, error slip | `quickshell/NowPlaying/NowPlayingView.qml` |
| Harnesses / tests | `quickshell/NowPlaying/preview/{render.qml,render.sh,service-test.qml,tt-act.qml}`, `tests/nowplaying-service.test.sh` |
| Docs | `docs/WIDGETS.md` (Now Playing → TikTok bullet, config key, tests), `CHANGELOG.md` |

## Decisions
- **Placement**: a second row directly above ⏮ ⏯ ⏭, same button width. Three more buttons in the transport row would not fit at the
  minimum portrait width (140 px Overworld, 120 px Apothecary); the stacked row fits every shape at the minimum size (renders `tt-min`, `tt-wide`).
- **State display**: Overworld = filled glyph (󰋑 heart, 󰃀 bookmark) in the game's colour codes (§c red, §a green, §6 gold) + a 1-GUI-px
  line under it; off = outline glyph (󰋕, 󰃃), white. Repost has no filled glyph (󰕇 both ways): colour + line. Apothecary = filled chip
  (seal vermilion / `success` / `gold`) with cream glyph. Unknown = the off look, tooltip says "unknown". Busy = all three disabled, the
  running one shows 󰔟.
- **Errors**: tooltip of that button (Overworld description line / Apothecary tip) **and** a short line on the picture for 8 s
  (`actionErrorFresh`), because the user may move the pointer away right after the click.
- **One command per tab, stricter than "one per tab+action"**: a second press while one is queued or running is ignored (daemon) and
  refused "busy" (userscript); the buttons are disabled meanwhile anyway.
- **Commands only on stdin**, never over HTTP (`/want` forces `cmd=want`): a page that somehow had the token still cannot like anything.
- **Two clip checks**: the daemon refuses a key the tab does not currently report; the userscript refuses when
  `more-menu-icon[data-more-menu-item-id]` ≠ the command's clip, right before each click (the clip can change during a save).
- **`tt` only counts for the reported clip**: the daemon blanks `bar/liked/saved/reposted` when `tt.clip ≠ videoId`, so the buttons
  never show another clip's state.
- **Saved state**: TikTok's `collected` prop, but our own result wins while the prop still says what it said at our click (props may be
  stale, verified fact); if the prop changes later (the user un-favourited in the browser), the prop wins. If neither is known, save
  refuses ("cannot tell whether it is saved") rather than risk an un-favourite that empties collections.
- **Liked**: live `aria-pressed` (verified), props only as a fallback. **Reposted**: our last result only, else `null`.
- **Heartbeat**: the reply carries `poll: true` for TikTok tabs; the daemon only runs while the PiP is on, so with the PiP off the
  request fails, `poll` drops to false and a paused tab goes quiet (tested). One report per second while paused, like while playing.
- **Closing TikTok's panels**: Escape (keydown/keyup on the focused element), then the panel's `[aria-label="close"]`, then the share
  button again (share panel) or an outside click (collection list), each a bounded wait. A panel that stays open is reported in the result.
- **`nowplaying.tiktokCollection`** is read with a fallback in the service; I did **not** add it to `ConfigService.defaults` (Overworld
  `quickshell/Services/ConfigService.qml`): that would have been another live reload for a key that already defaults correctly.

## Verified (and how)
- **Daemon** `bash tests/hypr-nowplaying.test.sh` → **119 passed, 0 failed** (95 old + 24 new: `tt` sanitising, the other-clip blanking,
  `poll` true/false, queued → state, duplicate ignored, bad token gets nothing, delivered in the reply and only once, busy while sent,
  result done / failed with a cleaned error, bad action / unknown tab / other clip / YouTube key refused, not accepted over HTTP, clip
  changed before delivery, tab closed, `status` lines, 10 s expiry, never delivered after expiry, stdin EOF → stopped state `action: null`).
  The same suite against Apothecary's copy → **119 passed**.
- **Userscript** `bash tests/nowplaying-bridge.test.sh` → **72 passed, 0 failed** (33 old + 39 new; run twice, both 72). New pages on a fake
  logged-in TikTok For You page that reproduces the probed DOM (`fakeTikTok()` in `harness.js`): like/unlike (aria-pressed, `digg 1,digg 0`),
  repost/remove (panel closed after), save → Manage → "Edits" 395 → 396 and list closed, un-save (395, `collect action=2`), wrong clip
  refused with zero clicks, busy reported, a second press while busy refused, the same command handed over twice runs once, missing
  collection (no "Create" click, Favorites only), case-insensitive name and not "Edits old", no Manage toast, Escape that does not close
  the panel (close button used), logged out (no column → `bar:false`, command fails with a reason), stale and live props, **a paused clip
  reached within 1.5 s** via the heartbeat, **quiet after the PiP goes off**, only 127.0.0.1 contacted. v1.1/v1.2: ⏭/⏮ media-session
  handlers press `feed-navigation-next/prev`, a disabled button / no buttons fall back to scrolling; the **watchdog bounces a stuck clip
  away and back** (`["it1","it2"]`) and **leaves a paused clip alone**.
- **Sync** `node tests/nowplaying-sync.test.js` → 25 passed (unchanged).
- **Service** `bash tests/nowplaying-service.test.sh` (private offscreen qs, real daemon child, temp everything) → **45 passed, 0 failed**
  (29 + 16: no `tt` = no buttons, press refused; `tt` → state; press → **the command reaches the daemon over stdin** (queued, right
  tab/key), busy, second press refused, the tab gets it in its reply with the **collection from config**, still busy while running,
  result → liked/not busy, status line, failed save → error + fresh, other clip → hidden, **YouTube (even claiming `tt`) → no buttons**
  and press refused, back to TikTok → buttons). `NP_WITH_MPRIS=0` → 41 passed, the 4 old by-design skips.
  Apothecary's port → **45 passed, 0 failed**.
- **Pointer tests** (QtTest events into an offscreen window): Overworld `preview/tt-act.qml` **11/11 PASS** Day and Night; Apothecary
  `render.sh <dir> tt-act` **12/12 PASS** each mode (row shown only with canLike, glyphs per state, each button → `act(name)`, not a drag,
  busy disables all and blocks clicks, hourglass, error in that button's tooltip and on the picture, YouTube → no row). The existing
  `act.qml` still **0 failed** in both themes and both modes.
- **Renders** (offscreen, viewed; zoomed crops of the button rows checked), Day + Night:
  Overworld `qa/screenshots/tiktok-actions-{tt-off,tt-on,tt-busy,tt-unknown,tt-error,tt-min,tt-wide,youtube-hover}-{light,dark}.png`;
  Apothecary `~/Projects/apothecary-hyprland/qa/screenshots/nowplaying-{tt-off,tt-on,tt-busy,tt-unknown,tt-error,tt-min,tt-wide,tt-youtube-hover}-{light,dark}.png`.
  (off / on / busy / unknown repost / error / smallest portrait / smallest landscape / YouTube = no row; the "video" is the still frame of
  the cached test clip, as in the earlier reports.) Overworld renders were made with
  `OW_MODE=<m> OW_NP_CASE=<case> OW_NP_STILL=… OW_NP_STILL169=… OW_RENDER_OUT=… QT_QPA_PLATFORM=offscreen qs -p quickshell/NowPlaying/preview/render.qml`.
- **Shared files**: `cmp scripts/hypr-nowplaying ~/Projects/apothecary-hyprland/scripts/hypr-nowplaying` and
  `cmp apps/zen/nowplaying-bridge.user.js ~/Projects/apothecary-hyprland/apps/zen/nowplaying-bridge.user.js` → **identical**.
  `node --check` on the userscript, `py_compile` on the daemon (no `__pycache__` left), `bash -n` on every changed shell script.
- **Live**: one reload, no errors from NowPlaying in `~/.cache/overworld/qs.log`; `qs -c overworld ipc call nowplaying status` →
  `on, shown, daemon running, …` afterwards.

## Not verified (cannot be, by the rules of this run)
- **No real TikTok click was made.** Everything about TikTok's page is built on the orchestrator's probe facts and tested on a fixture
  that reproduces them. Unverified details: whether Escape closes TikTok's share panel / collection pop-over (fallbacks exist), the toast
  text for "Remove repost", the exact `innerText` of collection items (handled as "<name> <n> videos" with or without a newline), the React
  prop path from `anchoring-engagement-vertical` in Firefox through `wrappedJSObject`, what TikTok shows **logged out** (assumed: no
  `like-icon` in the column, or a like that does not toggle → "logged out?" error), and background-tab timing in Zen (waits are bounded
  wall-clock deadlines, so throttled 1 s timers only make them coarser).
- Chromium is not Zen/Firefox: Violentmonkey's real GM API, `exportFunction` media-session path and content-world isolation are not exercised.
- The buttons on the real screen (layer, real pointer, the McTooltip) and Apothecary's live shell (not running).

## Please try (user)
1. Reinstall the bridge: `overworld nowplaying userscript --serve`, open the printed URL in Zen, press **Install** (it is version
   1.3.0), reload the TikTok tab.
2. Play TikTok's For You feed (logged in), hover the PiP: ♥ ⟲ 🔖 above ⏮ ⏯ ⏭. Like → the heart turns red and TikTok's own heart too.
   Repost twice (on, off). Save → it lands in **Edits**; save again → un-favourited and **out of Edits** (TikTok's own behaviour).
3. Pause the clip and press like: it should still happen within ~1.5 s.
4. If something fails, hover the button (tooltip) or run `hypr-nowplaying status` → the `action:` line has the reason.
5. Another collection: `"nowplaying": {"tiktokCollection": "<name>"}` in `~/.config/overworld/config.json` (or Apothecary's).

## Open issues
- `ConfigService.defaults` (Overworld) has no `nowplaying.tiktokCollection` entry (works through the fallback; add it when that file is
  next touched for another reason).
- Un-save is all-or-nothing (TikTok's rule): it removes the clip from Favorites and every collection; documented in both themes.

## Requests filed
None: every file I changed was named in my prompt (the NowPlaying module, the shared daemon/userscript, their tests, the docs).
