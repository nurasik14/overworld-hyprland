# qs-features report (phase 2)

Running log. Started 2026-11-05 ~06:40 HKT.

## Plan / decisions
- Module layout `quickshell/Game/`: singletons `GameCore` (paths, ipc/run helpers, texts), `GameUi` (which screen is open),
  `Advancements` (engine), `Stats`, `GameMode`, `ChatService`; windows `ChatOverlay`, `ScreenWindow` (generic McScreen host),
  `AdvancementsScreen`, `StatsScreen`, `OptionsScreen`, `GameModeSwitcher`, `AdvancementToasts`; `EventBridge` (synthesises
  window/workspace/battery/xp/mode events when their owner did not emit them — de-duplicated against the bus).
- `OW_STATE_DIR` env overrides `~/.config/overworld` for everything this module writes (advancements/stats/chat-history/gamemode/config.json)
  so tests never touch the real state. `OW_GAME_DRYRUN=1` makes every desktop-changing command print to chat instead of running.

## Status (07:10 HKT): all six deliverables written and exercised; polishing + full-config load + final docs remaining

### Delivered
| # | what | where |
|---|---|---|
| 1 | Chat console + log | `Game/ChatOverlay.qml`, `ChatService.qml`, `ChatCommands.js` (19 commands + `/say /me /msg /options`) |
| 2 | Game modes + switcher | `Game/GameMode.qml`, `GameModeSwitcher.qml`, `scripts/game/apply-gamemode.sh` |
| 3 | Advancements engine + screen + toasts | `Game/Advancements.qml`, `AdvancementsScreen.qml`, `AdvFrame.qml`, `AdvancementToasts.qml`, `EventBridge.qml` |
| 4 | Statistics | `Game/Stats.qml`, `StatsScreen.qml` |
| 5 | Options | `Game/Options.qml`, `OptionsScreen.qml`, `OptSlider.qml`, `BindsModel.qml`, `scripts/game/set-config.sh` |
| 6 | IPC + docs | `Game/GameSystems.qml` (5 targets), `docs/GAMEPLAY.md`, `scripts/game/advancement-table.py`, `wallpaper-seed.sh` |
| – | infrastructure | `GameCore.qml` (paths/helpers/texts), `GameUi.qml` (open screen state), `JsonStore.qml`, `ScreenWindow.qml`, `preview/` (harness + `SelfTest.qml`) |

### Decisions
- Toasts are mine (`overworld-advtoast`, left of qs-core notification stack (right margin 246 GUI px)) because the McToast advancement kinds are not part of the notification flow.
- `window.open/close/kill`, `workspace`, `mode`, `net.connect`, `battery`, `xp.levelup` are synthesised from Hyprland raw events / services by `EventBridge`
  only when the owning module did not emit them (de-duplicated within ~0.5 s; `window.kill` looks back 6 s).
- `/proc/uptime` catch-up is fed to the engine silently (a shell started at 30 h of uptime must not throw five toasts).
- Desktop mode changes go through my own `apply-gamemode.sh`, not the CLI: the CLI's `gamemode` flag file collides with the new mode file (request filed).
- The Day-mode chat uses `darkGround: true` text on a 50 % black bar (it floats over the world, like the game), the screens use the dim gradient.
- Advancement hover box = the game's `box_obtained/unobtained` sprites; the window frame is sliced from `gui/advancements/window` (`AdvFrame.qml`) and follows Night through the palette shader.
- `OW_STATE_DIR` redirects every state file; the real `advancements.json` / `stats.json` / `chat-history.json` were never created during the build.

### Verified
- `OW_SELFTEST=1` (SelfTest.qml, temp state dir, dry-run): 97 assertions PASS, 0 FAIL — durations, advancement engine (case-insensitive class match, distinct, counts to 100,
  `all` triggers, `$time`, battery thresholds, `unlocked_at_least`, grant/revoke by id/tab/suffix), completion + Tab cycling, every chat command through the dry-run interpreter,
  history, game-mode switching incl. spectator DND and restore, reminder firing, Options write-through (config.json written in place, state files persisted).
- EventBridge against real Hyprland events: a test window `overworld-test-bridge` opened silently on workspace 77 and closed → `window.open`, `window.close`, `window.kill`
  (synthetic) appeared on the bus and unlocked Overworld / Monster Hunter.
- IPC: `qs -p … ipc show` lists chat, gamemode, advancements, stats, options; every function called.

### Screenshots (all viewed; Day = `light`, Night = `dark`; the live Apothecary desktop is visible underneath, judge the surface only)
`qa/screenshots/qs-features-{chat,switcher,advancements,advancements-adventure,stats,stats-items,options,options-video,options-sounds,options-controls}-{day,night}.png`
plus `qs-features-{advancements,options,stats}-day-gui{1,3}.png` (GUI scale 1 and 3). `qs-features-raw.png` is a scratch capture.

### Bugs found by looking at the screenshots and fixed
- Chat lines double-spaced / wrapped lines overlapped the next line (row height assumed a fixed 9 px line box; now the Text's own implicit height).
- Advancement chat line printed `[[Title]]` (the lore template already holds the brackets).
- Advancements: tree drawn scrolled off-screen when the window was first created at size 0 (recentre now also runs when the size changes); hover box title clipped and its frame drawn 6 px off the node.
- Icons whose block has no item sprite (hay_block …) were the missing texture: `Advancements.iconUrl` falls back to `_front/_side/_top`.
- Statistics on the 1.21 "menu" background was unreadable over a busy desktop (dark layer added).
- Controls page: keycode binds (SUPER+1…0) printed as "SUPER +".
- Toasts overlapped qs-core's wider (240 GUI px) notification toasts: right margin 246 GUI px.
- Fake events from my tests leaked through the shared bus into another agent's full-shell run and wrote the real `advancements.json`: file deleted, private bus (`OW_EVENTS_DIR`) added, qa-reviewer note filed.

### Not verified (and why)
- **Real keyboard and pointer input** (Tab/Enter/Esc/arrows in the chat input and screens, hover, click, drag-to-pan, wheel, the advancement bracket hover in chat): the safety rules forbid moving the pointer and
  grabbing the keyboard (`OW_NOFOCUS=1` in every preview). The logic behind the keys is tested through the same functions the handlers call (completion, Tab cycling, history, mode switching, grant/revoke,
  hover box via `advancements inspect`), but no key event has reached a handler. qa-reviewer should type in the chat once, press Tab, Up and Esc, drag the advancement tree and click a switcher slot.
- **Click-through of the closed chat window** (empty input region) and **keyboard focus hand-back** after closing the chat.
- **Desktop effects of game modes**: `apply-gamemode.sh` only ran in dry-run (it would change the live Hyprland config); adventure/spectator, `hyprctl reload`, widgets hide/reveal and `hyprctl dispatch workspace` / `focuswindow` for `/tp` and `/locate` were not executed for real.
- `/time set`, `/weather`, `/f3`, `/kill`, `/seed`, `/brew`, `/title` only print their IPC/CLI commands (dry-run): the receiving end (fx-world IPC, `interact kill`, brew IPC, `overworld wallpaper random`) did not exist yet or must not be driven live.
- `battery` and `xp.levelup` synthesis (needs a real discharge / an hour boundary); `net.connect` (would need a connect).
- Full-shell load with the Game module: `Configuration Loaded`, no warnings from Game files, but surfaces of other modules were not exercised.

### Open issues / notes for the next agent
- fx-world / fx-interactions / qs-core / hyprland-engineer requests are in docs/REQUESTS.md (IPC names, `interact kill`, config defaults, layer rules, gamemode flag clash in the CLI).
- chat.json lacks `say`, `me`, `msg`, `options` and `advancement` sub-command help; supplementary entries live in `ChatService.extraCommands`.
- The hover over the green advancement bracket uses a width measured with a hidden Text; if a line wraps exactly at the bracket the hover box is off.
- Advancement toasts use their own layer; if qs-core later wants one stack, `AdvancementToasts.qml` is a 60-line file to fold in.

### Final checks (07:25 HKT)
- Self-test re-run after the last edits on a private bus: 97 PASS / 0 FAIL. Full shell (`qs -p quickshell`, temp state dir, dry-run): `Configuration Loaded`, no warnings from `Game/` files.
- GUI scale applies live: a preview with `HOME=/tmp/ow-fakehome` (its own `config.json`): `options set gui_scale 3` rewrote the file in place and the Options screen re-laid itself out at scale 3 (screenshot compared).
- Controls page falls back to `docs/KEYBINDS.md` when `hyprctl binds -j` fails. Scrollbars hide when nothing scrolls.
- `~/.config/overworld/` holds only `config.json` (no advancements/stats/chat-history/gamemode/reminders files). Previews I started are killed.
