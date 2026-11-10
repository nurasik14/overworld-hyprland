# tiktok-actions: Like / Repost / Save-to-"Edits" buttons on the Now Playing PiP (both themes)

The user: "Add the ability to like, repost and save the post into the edits collection" — from the floating Now Playing
PiP, while TikTok plays in Zen in the background, so he never has to switch to the Zen window.

User decisions (final):
- Buttons live in the PiP's HOVER CONTROLS only (next to ⏮ ⏯ ⏭). No keybinds, no new CLI verbs, no IPC verbs needed.
- Each button TOGGLES (press again = unlike / remove repost / un-save) and SHOWS the current state (filled vs outline).
- BOTH themes: Overworld (this repo) and Apothecary (`~/Projects/apothecary-hyprland`, same feature ported earlier by
  `now-playing-pip-apothecary`; read docs/agent-reports/now-playing-pip-apothecary.md there).
- Only shown when the PiP's current source is TikTok via the bridge (hide them for YouTube / Spotify / MPRIS-only).

Read first: BRIEF.md (§1 rules), docs/agent-reports/now-playing-pip.md (the whole bridge/daemon/service design),
`apps/zen/nowplaying-bridge.user.js` (READ IT FULLY — the orchestrator added two things after that report that you must
keep working: v1.1.0 media-session ⏮/⏭ = scroll the TikTok feed (`feedStep`, `trackActions`) and v1.2.0 a stall
watchdog (`watchdog`) that bounces away and back when a clip is stuck behind the user's VPN), `scripts/hypr-nowplaying`
(daemon: `/state`, `on_control` via `--stdin`, state file), `quickshell/NowPlaying/NowPlayingService.qml`,
`NowPlayingView.qml`, `NowPlayingPip.qml`, and the Apothecary copies of those QML files. The userscript and the daemon are
SHARED and must stay byte-identical in both repos (`cmp` them at the end).

## Verified facts about the user's LOGGED-IN TikTok web page (2026-11-10, orchestrator probed it with his approval)
You cannot log in; do NOT try to obtain cookies or touch his account. Build against these facts + fixtures.
For You feed, logged in, the current clip's controls are OUTSIDE the item container, in one shared column:
- `[data-e2e="anchoring-engagement-vertical"]` holds the action bar for the CURRENT clip:
  - Like: `div[role=button][data-e2e="like-icon"][data-key-interaction="action_like"]`, `aria-pressed="false"|"true"`,
    `aria-label="Like video\n9836 likes"`. A DOM `.click()` toggles it (verified: aria-pressed true, count +1; click again
    = unliked, count back). TikTok calls `POST /api/commit/item/digg/` itself.
  - Favorite: `div[role=button][data-e2e="favorite-icon"][data-key-interaction="action_favorite"]`,
    `aria-label="Add to Favorites. 2374 added to Favorites"` — NO aria-pressed; the label text does not change with state
    (only the count). `.click()` favorites (`POST /api/item/collect/?action=1&itemId=…`); clicking again un-favorites
    (`action=2`).
  - After favoriting, a toast appears with a `<button>` whose text is exactly `Manage`. Clicking it opens a popover
    `div[role=dialog].TUXPopover-popover--open` listing collections: `div[data-e2e="collection-<collectionId>"]` items whose
    innerText is "<name> <n> videos" (e.g. `collection-7264957855126899462` = "Edits 395 videos"), plus
    `[data-e2e="collection-action-create"]` "Create new collection". Clicking the Edits item adds the clip to Edits
    (`POST /api/collection/modify_items/?collectionId=…&commitIds=<itemId>`; verified Edits 395 → 396).
  - Un-favoriting removes the clip from Favorites AND from its collections (verified Edits 396 → 395). There is no
    verified "remove from one collection only" path.
  - Share: `div[role=button][data-e2e="share-icon"]` (`aria-expanded`). `.click()` opens a share panel; in it
    `[data-e2e="share-repost"]` whose text is `Repost` or, when already reposted, `Remove repost`. Clicking it toggles
    (toast "Reposted"); verified both directions. Close the panel afterwards (Escape key event / click the panel's
    `[aria-label="close"]` / click share-icon again — make sure it closes; check `aria-expanded`).
  - Also present: `comment-icon`, `more-menu-icon` (BUTTON with `data-more-menu-item-id="<current clip id>"` — the reliable
    id of the clip the action bar belongs to), `feed-navigation-prev` / `feed-navigation-next` buttons
    (`aria-label="Go to previous/next video"`, `disabled` on the first clip) — use these in `feedStep` first when present,
    keeping the existing scrollIntoView path as fallback.
- Item data (React props of the action bar, reachable from `[data-e2e="anchoring-engagement-vertical"]`'s
  `__reactFiber$…` → `memoizedProps…item`) has booleans `digged` (liked) and `collected` (favorited); may be stale after an
  action, so prefer live DOM (`aria-pressed`) and your own action results. There is no repost flag in item data; the
  share panel text is the only verified repost signal. In Firefox the content script must read page-world props via
  `wrappedJSObject` (as `fiberItem` already does).
- Toasts/labels are English (the user's TikTok UI language). Match by data-e2e first, text second.
- Background tab: the Zen window is usually NOT focused; DOM clicks work there too, but popovers may need a moment —
  wait for elements with a bounded poll (e.g. 100 ms × up to 4 s), never fixed long sleeps.

## Semantics (decided)
- like: toggle the like-icon of the clip whose id == the command's clip id; result state from `aria-pressed`.
- repost: open share panel, read `share-repost` text, click it, close the panel; new state = the opposite of what it said.
  Until the first look, repost state is "unknown" (show the button neutral, not filled).
- save (to the collection named by config `nowplaying.tiktokCollection`, default "Edits", matched case-insensitively by the
  name part of the item text): if NOT favorited → favorite, wait for the `Manage` toast, open it, click the named
  collection, close the popover → state saved. If favorited → un-favorite (this also removes it from every collection —
  document this in the help/docs). If the collection is not in the list → fail with a clear reason (do NOT create one).
  If the Manage toast never appears → leave it favorited, report "saved to Favorites only".
- Never act on a different clip than the one the user saw in the PiP: every command carries the clip id; the userscript
  refuses (reports an error) when `more-menu-icon[data-more-menu-item-id]` != that id.
- One action at a time per tab; ignore duplicate presses while one is running (button shows busy).

## Plumbing (design the details; keep it light and safe)
1. PiP → service → daemon: the service already talks to the daemon over `--stdin`. Add a control cmd, e.g.
   `{"cmd":"action","tab":…,"key":"tiktok-<id>","action":"like|repost|save"}`; the daemon queues it for that tab
   (short TTL, e.g. 10 s; one pending per tab+action).
2. Daemon → userscript: deliver pending commands in the reply to the tab's next `/state` POST. The userscript only posts
   every 1 s while playing and goes silent while paused — commands must still arrive within ~1.5 s when the clip is
   paused, so add a light path for that (e.g. while a TikTok tab is reported AND the daemon's reply says the PiP is on,
   keep a 1 s heartbeat even when paused; nothing when the PiP is off or nothing is reported). Keep the token check.
3. Userscript → daemon: report the result and the per-clip state in the regular payload: e.g.
   `tt: {liked: bool|null, saved: bool|null, reposted: bool|null, busy: "", lastError: ""}` read live from the DOM each report
   (liked from aria-pressed, saved = favorited, from `collected`/your own last result; reposted from your last result,
   else null). Daemon validates/sanitises these fields like the others; state.json carries them.
4. Service (both themes): expose `canLike` (TikTok bridge source + logged-in action bar present), `liked/saved/reposted`,
   `busy`, `act(name)`. View: three hover buttons in the existing control row style (Overworld: McButton glyphs; Apothecary:
   its own button component), filled/outline per state, busy = dim + no input, tooltip with state + last error. Fit the
   row at the PiP's minimum size (check the existing min width; wrap/shrink rather than overflow).
5. Daemon tests (`tests/hypr-nowplaying.test.sh`): queue/deliver/expire, bad token, bad action, unknown tab, state fields
   sanitised. Userscript tests (`tests/nowplaying-bridge.test.sh` uses a Chromium harness with fixtures): add a fixture page
   reproducing the logged-in DOM above (action bar with like/favorite/share, Manage toast, collection popover with
   `collection-<id>` items incl. "Edits", share panel with share-repost Repost/Remove repost, more-menu-icon with the clip
   id) whose fake handlers flip state like TikTok does; test like/unlike, repost/remove, save → Edits, un-save, wrong
   clip id refused, missing collection, toast never appears, duplicate presses, paused-clip delivery. Service test
   (`tests/nowplaying-service.test.sh`): command goes out on stdin, state comes back, buttons hidden for non-TikTok.
   Keep ALL existing tests passing, incl. the v1.1/v1.2 behaviours (`feedStep`, watchdog) — add tests for those too
   (prev/next via feed-navigation buttons; watchdog bounce on a fixture whose video never advances; no bounce when paused).
6. Bump the userscript `@version` to 1.3.0. Do NOT run `hypr-nowplaying userscript --serve` (the orchestrator gives the
   user the install link afterwards).

## THE USER IS AT THE DESK (hard rules)
No scripts/dev-shot.sh, no grim, no workspace switching, no on-screen previews/test windows, no sound, no git commits,
no sudo, no input injection, never control the user's players (no playerctl play/pause/next), never open or drive his Zen
browser, never touch TikTok with his account. Visual checks = OFFSCREEN renders only (`QT_QPA_PLATFORM=offscreen`
harness → PNG → Read it), Day + Night, both themes: hover controls with TikTok source (all three states: off / on /
busy, and unknown repost), and non-TikTok source (buttons hidden). The live `qs -c overworld` hot-reloads on EVERY QML save
and a reload resets the user's running brew timer: write each QML file's final version in as few saves as possible
(develop in a scratch copy / the offscreen harness, then copy in), every save must be valid; check
`~/.cache/overworld/qs.log` after saves for errors from your files. Apothecary is not running live, but keep it valid.

## Docs
docs/WIDGETS.md (or the NowPlaying doc the earlier agents wrote) in both repos: the three buttons, toggle semantics incl.
"un-save un-favorites and removes from all collections", the config key, that it needs the bridge 1.3.0 and a
logged-in TikTok tab, privacy (commands only over 127.0.0.1 with the token). CHANGELOG entries in both repos.

Report in docs/agent-reports/tiktok-actions.md: changed files (both repos), decisions, verified vs not verified (real
TikTok clicks are NOT verifiable by you — say so), the `cmp` results for the shared files, test counts, offscreen PNG paths.
