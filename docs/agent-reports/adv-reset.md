# adv-reset report — "Reset advancements" button (follow-up, user at the desk)

Done 2026-11-05 ~14:20 HKT. No screenshots of the live desktop, no workspace switches, no sound, no commits, no real state touched on purpose.

## Delivered
| what | where |
|---|---|
| Confirm screen (new, reusable): "Reset all advancements?" / "This cannot be undone." · **Reset** (red text) / **Cancel** (default, Esc = cancel, ←/→/Tab move, Enter activates, click on the dim = cancel) | `quickshell/Game/AdvancementsConfirm.qml` |
| Advancements screen: bottom bar **Reset Advancements** + **Done** under the window (there was no Done button before), confirm overlay | `AdvancementsScreen.qml` |
| Engine `Advancements.reset()`: clears `unlocked` + `progress`, writes `advancements.json` at once (`{"version":1,"unlocked":{},"progress":{}}`), emits `advancement.reset {}`, signal `wasReset()` | `Advancements.qml` |
| Chat line `[Overworld] Advancements have been reset` | `ChatService.qml` (`onWasReset`) |
| Chat `/advancement reset` (only asks) → `/advancement reset confirm` (does it); Tab completes `reset` and `confirm`; help text | `ChatService.qml`, `quotes/chat.json` |
| IPC `advancements reset` (no question; prints `reset <n> of 60`) and `advancements resetdialog` (opens the screen with the confirm question, handy to try) | `GameSystems.qml`, `AdvancementsState.qml` |
| CLI `overworld advancements reset [--yes]` (y/N on a tty, refuses without a tty unless `--yes`), `overworld advancements` still opens the tree, help text | `scripts/overworld` |
| Statistics screen: **Reset Statistics** + **Done**, same confirm screen ("Reset all statistics?"), `Stats.reset()` clears every counter, rewrites `stats.json`, this session counts as game 1 | `StatsScreen.qml`, `Stats.qml` |
| Docs | `docs/GAMEPLAY.md` |

Ownership note: `Stats.qml`, `StatsScreen.qml` and `GameSystems.qml` are not on the follow-up's file list, but the Statistics button and the IPC verb cannot exist without them; the edits are small and additive. Nothing was filed in REQUESTS.md.

## What a reset does / does not do
- Clears all advancement progress and unlocks, in memory (tree is all locked at once: tab counters 0/n, frames "unobtained") and on disk.
- Statistics are NOT reset by it (separate button). Bus event `advancement.reset {}` is emitted (nothing consumes it yet; stats ignore it).
- **No instant undo:** every minute EventBridge feeds `xp.levelup {level: uptime hours, catchup: true}` so "Level 3/6/12/24/30" advancements are credited silently. After a reset `Advancements.catchupBlocked` is set and those catch-up feeds are ignored for the rest of that shell run.
  **At the next shell start (login, `overworld reload` that restarts qs, qs restart) the catch-up credits the uptime advancements again** — the machine's uptime is real. A reboot gives a truly clean slate.
- The `chat.command` event of `/advancement reset …` reaches the engine a moment after the reset (file-tail bus); it is dropped for 5 s so the reset does not immediately earn "First Words" / chat-count progress.
- Real events after a reset still count, also time-of-day ones: resetting at 02:00–05:00 re-unlocks "Night Owl" within a minute, 05:00–07:00 "Early Bird" (it is real activity, left as is).

## Verified
Headless, nothing on the real screen: a private `kwin_wayland --virtual` (own socket `ow-adv-test`, own dbus via `dbus-run-session`, no Hyprland env) + `qs -p ~/.hermes/cache/scratch/adv-reset-harness` with `OW_STATE_DIR` (temp dir, config copy with `sounds:false`), `OW_EVENTS_DIR` (private bus), `OW_GAME_DRYRUN=1`, `OW_SOUND_DRYRUN=1`, `OW_NOFOCUS=1`. (`QT_QPA_PLATFORM=offscreen` cannot be used: Quickshell's PanelWindow needs a Wayland layer-shell backend, hence the virtual compositor.) Run: `~/.hermes/cache/scratch/adv-reset-harness/run.sh test|render night|day`.
- `run.sh test night` → **28 PASS / 0 FAIL**: unlock 3 (+1 via event) → file has them + progress → `reset()` returns 4 → in-memory all locked, tab counts 0, progress 0 → file valid and empty immediately → chat line posted → stats untouched → catch-up feed (`xp.levelup 40, catchup`) ignored → real events (`workspace`, `window.open`) still unlock and save → `/advancement reset` only asks → `/advancement reset confirm` resets → IPC `advancements reset` through a real `qs ipc call` → output `reset 2 of 60`, state empty → `Stats.reset()` zeroes memory and `stats.json` valid with empty totals/apps, `sessions` 1 → `advancement.reset` present in the bus file.
- Rendered (GPU, Day + Night): the Advancements screen with the new bottom bar, the Advancements confirm, the Statistics screen with its new bottom bar, the Statistics confirm. All viewed. Cancel carries the white highlight, Reset has red text, the buttons do not collide with the tab row (Statistics) or the frame (Advancements).
  `qa/screenshots/adv-reset-{adv-tree,adv-confirm,stats,stats-confirm}-{day,night}.png` (the world behind is the private compositor's plain grey, not a wallpaper).
- Live hot-reload: `~/.cache/overworld/qs.log` checked after each save: `Configuration Loaded`, no errors from Game/ files (the only warnings are the pre-existing `HyprlandState`/`TimeService` "Unable to assign [undefined]" ones).
- CLI: `bash -n scripts/overworld`; `overworld help advancements`; `overworld advancements reset` without a tty and with `</dev/null` → refuses with a message, rc 1 (no reset happened); `echo n | …` same (no tty). The y/N prompt and `--yes` path were NOT run against the live shell on purpose; the IPC call they end in is the one tested above.

## Not verified
- Real keyboard / mouse input on the confirm screen (Esc, ←/→, Enter, clicks) — no input grabbing allowed; the key handler is plain `Keys.onPressed` logic (see `AdvancementsConfirm.qml`) and the buttons' `clicked` path is the standard `McButton`.
- Night frame in the software-render pass looked unframed (palette shader needs the GPU); the GPU pass shows it correctly. Not related to this change.
- Sounds (`ui.click` on Reset/Cancel): silent by rule, code path only.

## Real state files
Backed up to `~/.hermes/cache/scratch/adv-reset-backup/{advancements,stats}.json` before anything. **Not byte-identical afterwards, and that is the live shell, not the tests:** both files are still valid JSON; `advancements.json` has the same 23 unlocked ids (none added or removed), `stats.json` only grew (workspace switches 135→172, windows 22→24, notifications 4→6, screenshots 3→4, play time +529 s) from the user's own activity, and `sessions` went 7→11 because each hot-reload of my QML saves restarted the engine (each counts as a "game started"). If that count matters: it is only the "Games Started" row.

## Please try (user)
1. `overworld advancements` (or SUPER+L) → bottom bar shows **Reset Advancements** and **Done**.
2. Click **Reset Advancements** → "Reset all advancements? / This cannot be undone." Cancel is highlighted; Esc or Cancel returns to the tree untouched. Pick **Reset** only if you really want to lose your 23 unlocked advancements (they are in the backup above if you change your mind: copy `adv-reset-backup/advancements.json` over `~/.config/overworld/advancements.json` and restart the shell — I did not do that for you).
3. Chat: `T`, type `/advancement reset` → it asks; `/advancement reset confirm` does it ("[Overworld] Advancements have been reset").
4. Statistics (SUPER+SHIFT+L) → **Reset Statistics** → same confirm screen.
5. Scripts: `overworld advancements reset` asks y/N; `--yes` skips; `qs -c overworld ipc call advancements reset` has no question.
6. Safe preview of the dialog only: `qs -c overworld ipc call advancements resetdialog` then Cancel / Esc.

## Requests filed
none.
