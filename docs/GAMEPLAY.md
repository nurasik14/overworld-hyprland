# Gameplay — chat console, game modes, advancements, statistics, options

Owner: qs-features. Code: `quickshell/Game/` (entry `GameSystems.qml`), `quickshell/Services/GameEvents.qml` (the event bus),
helpers in `scripts/game/`. Everything below runs inside the Quickshell shell (`qs -c overworld`); nothing needs a daemon.

All screens are real Minecraft screens (McScreen, the game's sprites, hover = instant, `ui.click` sounds, ≤ 150 ms fade) and are keyboard driven.

## 1. Surfaces and IPC

| surface | layer namespace | open | keys |
|---|---|---|---|
| Chat console + chat log | `overworld-chat` (always mapped, click-through while closed) | `ipc call chat open` · `chat command "/"` (prefilled) · `chat toggle` | Enter send · Esc close · ↑/↓ history · Tab / Shift+Tab complete · PgUp/PgDn or wheel scroll |
| Game mode switcher | `overworld-gamemode` | `ipc call gamemode switcher` | ←/→ or Tab / Shift+Tab move · 1–4 pick · Enter apply · Esc close · click a slot |
| Advancements | `overworld-advancements` | `ipc call advancements open` | Tab / Shift+Tab or 1–5 change tab · arrows pan · Home recentre · drag or wheel to pan · hover for the box · **Reset Advancements** / Done buttons below the window · Esc closes |
| Statistics | `overworld-stats` | `ipc call stats open` | ←/→ or Tab change tab · ↑/↓ PgUp/PgDn scroll · Enter / Esc close · **Reset Statistics** / Done buttons |
| Options | `overworld-options` | `ipc call options open` · `options page video\|sounds\|controls\|access` | Tab between buttons · Enter · ←/→ on sliders · Esc = back one page, then close |
| Advancement toasts | `overworld-advtoast` (top-right, stacked ≤ 4, click-through) | automatic | — |

Prefix every call with `qs -c overworld`. Full IPC list (never named `show`):

| target | functions |
|---|---|
| `chat` | `open()` · `command(text)` (opens with `text`, "/" if empty) · `say(text)` (posts a line) · `run(text)` (executes a line without opening) · `log(n)` (last n lines as text) · `close()` · `toggle()` |
| `gamemode` | `set(mode)` · `get()` · `switcher()` · `cycle()` |
| `advancements` | `open()` · `close()` · `toggle()` · `grant(spec)` · `revoke(spec)` · `list()` · `reset()` (confirm-less, for scripts) · `resetdialog()` (opens the screen with the confirm question) · `tab(id)` · `inspect(id)` (opens the hover box of one advancement) |
| `stats` | `open()` · `close()` · `toggle()` · `summary()` · `tab(general\|items\|mobs)` |
| `options` | `open()` · `close()` · `toggle()` · `page(name)` · `get(key)` · `set(key, json)` |

From QML: `import qs.Game` gives `GameUi.open("advancements"|"stats"|"options"|"switcher")`, `GameUi.openChat("/")`, `GameMode.mode`,
`Advancements`, `Stats`, `ChatService`. From the bus: `GameEvents.emit("ui.open", {screen: "stats"})` and `chat.open {prefill}`.
Opening any launcher/network/power/wallpapers/brew modal closes these screens (and the other way round, one screen at a time).

## 2. Chat console

Type `/help` for the list (texts: `quotes/chat.json`). Commands, what each really does:

| command | effect |
|---|---|
| `/help [page\|command]` | 7 commands per page; `/help brew` shows one usage |
| `/time set day\|night\|auto` · `/time query` | day → `overworld light`, night → `overworld dark`, auto → the sun decides. Also writes `config.json` `daycycle` and calls `ipc world daycycle <v>` (fx-world) |
| `/weather clear\|rain\|thunder\|snow\|auto` | `ipc call world weather <w>` (fx-world overlay); auto = real Open-Meteo weather |
| `/gamemode [survival\|creative\|adventure\|spectator]` | sets the mode (see §3); no argument opens the switcher |
| `/tp <1-10>` | `hyprctl dispatch workspace N` |
| `/give <app>` | launches the best-matching desktop entry (id / name / startup class); emits `launcher.launch` |
| `/kill [class]` | focuses the first window of that class (if given), then `ipc call interact kill` — the block-break close |
| `/locate <app>` | focuses the nearest window (same workspace first, else closest id) whose class or title matches: "The nearest kitty is at workspace 3 (title)" |
| `/seed [current]` | rolls a random wallpaper world (`overworld wallpaper random`) and prints its seed (index.json `seed`, else a stable hash of the file name); `current` only prints |
| `/brew <dur> [task]` · `/brew stop` | `ipc call brew start <sec>s` / `reset`; durations `25m`, `1h30m`, `90s`, `45` (minutes), max 12 h |
| `/title <1-10> [text]` | `overworld ws N text` (no text = reset) and shows the /title card |
| `/clear` | clears the chat log and the notification history |
| `/advancement [open\|list [unlocked\|locked\|tab]\|grant <id\|tab\|all>\|revoke …\|reset]` | open the screen / progress / testing aid (ids, tab names, "all", or a unique suffix like `terminal`). `/advancement reset` only asks; `/advancement reset confirm` does it |
| `/stats` · `/options` | open the screens |
| `/f3 [on\|off]` | `ipc call world f3 <on\|off\|toggle>` |
| `/reload` | `Quickshell.reload()` |
| `/say <text>` · plain text · `/me <text>` | `<Nurasik> text` / `* Nurasik text` |
| `/msg <text> in <duration>` · `/msg list` | a **real reminder**: kept in `reminders.json`, survives a shell restart; at the time it posts `[Reminder] text` and sends a desktop notification (`notify-send -a Overworld`) |

Completion (Tab): command names, sub-commands, `1-10` workspaces, desktop-entry names (slugged) plus running window classes, advancement ids,
durations. A list of candidates shows above the input while typing; Tab completes a unique match (adds a space), extends to the common
prefix, then cycles; Shift+Tab goes backwards. History: Up/Down, last 100 lines in `chat-history.json`.

**The log.** The last 10 lines show for 200 ticks (10 s) and fade over the last 20, like the game; with the console open the last 20 show and
the wheel scrolls. Lines come from commands and from events:

| event | line |
|---|---|
| (shell start) | `Nurasik joined the game` + the MOTD |
| `advancement` unlock | `Nurasik has made the advancement [Title]` (goal: "has reached the goal", challenge: "has completed the challenge", purple); hover the green bracket with the console open → the advancement tooltip |
| `screenshot {path}` | `Saved screenshot as <file>` |
| `xp.levelup {level}` | `Nurasik reached experience level N` |
| `brew.done`, `rest.done`, `mode`, `wallpaper.set {path}`, `world.created {path}`, `net.connect {ssid}`, `gamemode`, `window.kill` (not synthetic), `battery` (low ≤ 20 %, charging / unplugged), DND changes ("Difficulty set to Peaceful") | the matching line from `chat.json → system` |

**Posting from another module:** `GameEvents.emit("chat.say", {text: "§aHello", color: "#ffff55"})` — `text` may contain §-codes, `color` (optional,
`#rrggbb`) is the default colour. Do **not** also post lines for the events in the table above; just emit the event.

## 3. Game modes

State: `~/.config/overworld/gamemode` (one word, watched; absent = survival). `GameMode.set(m)` writes it, runs
`scripts/game/apply-gamemode.sh <new> <old>`, sets/restores DND and emits `gamemode {mode}`.

| mode | meaning | what happens |
|---|---|---|
| survival | normal | nothing |
| creative | everything on, no warnings | the HUD reads the file: hearts/hunger stop jiggling and shaking (`GameMode.creative`) |
| adventure | the old Apothecary **performance mode** | animations, shadows, blur, gaps, rounding, opacity off through one `hyprctl --batch keyword …`, desktop widgets hidden |
| spectator | focus | HUD and widgets hidden (`GameMode.spectator`), gaps 0, DND on; chat stays reachable |

Leaving adventure/spectator runs `hyprctl reload`, re-shows the widgets if they were visible when entering (remembered in
`$XDG_RUNTIME_DIR/overworld/gamemode-widgets`) and restores the DND state from before spectator. A legacy `visible|hidden` flag (old
CLI) reads as adventure. `OW_GAME_DRYRUN=1` prints the script's commands instead of running them.

## 4. Advancements

Definitions: `quotes/advancements.json` (60 advancements, 5 tabs; vocabulary in `quotes/README.md`). Engine: `Advancements.qml`.

- **Input:** every bus event (`GameEvents`), plus derived `$resume` (wall clock jumped > 2 min = suspend/resume), `$time` (once a minute,
  `at: "HH:MM"`), `$day` (once per local day, `date`). Counts are lifetime; `distinct` counts distinct values of a field; `all` needs every part;
  `unlocked_at_least: all_others` fires on an `advancement` event.
- **Catch-up:** at shell start the current uptime level is fed once as `xp.levelup {catchup: true}`; those unlocks are silent (no toast or chat line).
- **EventBridge** makes sure the counted events exist whoever draws the surface: Hyprland raw events → `window.open`, `window.close`, `window.kill`,
  `workspace`; `Theme.mode` → `mode`; `NetworkService.activeSsid` → `net.connect`; UPower → `battery`; `/proc/uptime` → `xp.levelup`. A synthetic event
  (`"synth": true`) is only emitted if the owning module did not emit the same event around that time, so nothing counts twice.
- **Unlock:** state saved, `advancement {id}` emitted, toast (`McToast` advancement / goal / challenge, sounds `ui.toast.in` / `ui.toast.challenge`),
  chat line. Unlocking is independent of the parent (hidden ones show only once unlocked).
- **Screen:** tabs above the window with the root icon, tiled tab background, tree with task/goal/challenge frames (obtained = gold), connector
  lines, hover box with description + progress (`3/10`, `4/7 requirements`) or the unlock date, drag/wheel to pan.
- **Reset:** the **Reset Advancements** button (below the window, next to Done) opens a confirm screen — "Reset all advancements? / This cannot be
  undone.", buttons **Reset** (red) and **Cancel** (default, Esc = cancel, ←/→/Tab move, Enter activates). Same engine call from
  `overworld advancements reset [--yes]` (asks y/N on a terminal, refuses without a terminal unless `--yes`), `ipc call advancements reset`
  (no question) and the chat (`/advancement reset confirm`). A reset clears `unlocked` + `progress`, rewrites `advancements.json` at once
  (`{"version":1,"unlocked":{},"progress":{}}`), posts `[Overworld] Advancements have been reset` in the chat and emits `advancement.reset {}` on the
  bus. **Statistics are not touched** (their own **Reset Statistics** button on the Statistics screen, same confirm screen, clears `stats.json`; a
  reset session counts as game 1). The uptime catch-up that credits "Level N" advancements silently is switched off for the rest of that shell run, so a
  reset is not undone a minute later; **at the next shell start the catch-up credits the uptime advancements again** (the machine's uptime is still
  real — reboot to get a truly clean slate). Real events keep counting after a reset, including the time-of-day ones (Night Owl / Early Bird
  re-unlock within a minute if the reset happens inside their window).
- **Testing aids:** `/advancement grant|revoke`, `ipc call advancements grant|revoke <id|tab|all>`; the real state starts clean (no file until the
  first event).

### Trigger table

Generated by `python3 scripts/game/advancement-table.py` from `quotes/advancements.json`.

#### overworld

| id | frame | title | trigger | description |
|---|---|---|---|---|
| `overworld/root` | task | Overworld | window.open | Open your first window. |
| `overworld/terminal` | task | Getting an Upgrade | window.open (cls in {kitty, foot, Alacritty, …}) | Open a terminal. |
| `overworld/launch` | task | Acquire Hardware | launcher.launch | Launch an app from the launcher. |
| `overworld/browser` | task | Cartographer | window.open (cls in {zen, zen-browser, app.zen_browser.zen, …}) | Open a web browser. |
| `overworld/wifi` | task | Diamonds! | net.connect | Connect to Wi-Fi. |
| `overworld/uptime3` | goal | Isn't It Iron Pick | xp.levelup (level ≥ 3) | Keep the session running for 3 hours. |
| `overworld/uptime12` | goal | Diamond Pickaxe Shift | xp.levelup (level ≥ 12) | Reach XP level 12 (12 hours of uptime). |
| `overworld/uptime30` | challenge | Netherite Marathon | xp.levelup (level ≥ 30) | Reach XP level 30 in a single session. |
| `overworld/mode_night` | task | Moonrise | mode (mode = "dark") | Switch to Night mode. |
| `overworld/mode_day` | task | Rise and Shine | mode (mode = "light") | Switch back to Day mode. |
| `overworld/wallpaper` | task | Interior Designer | wallpaper.set | Change your wallpaper. |
| `overworld/wallpapers10` | goal | Changing Scenery | wallpaper.set ×10 | Change the wallpaper 10 times. |
| `overworld/new_world` | goal | Create New World | world.created | Generate a new world wallpaper. |
| `overworld/screenshot` | task | Say Cheese | screenshot | Take a screenshot. |
| `overworld/screenshot25` | goal | Photojournalist | screenshot ×25 | Take 25 screenshots. |
| `overworld/chat` | task | Local Chat | chat.command | Run your first chat command. |
| `overworld/chat50` | goal | Server Operator | chat.command ×50 | Run 50 chat commands. |
| `overworld/locate` | task | Where Are We? | chat.command (cmd starts with `/locate`) | Use /locate to find an app. |

#### adventure

| id | frame | title | trigger | description |
|---|---|---|---|---|
| `adventure/root` | task | Adventure | workspace | Switch your first workspace. |
| `adventure/hunter` | task | Monster Hunter | window.kill | Mine (close) a window with the pickaxe. |
| `adventure/hunted` | challenge | Monsters Hunted | window.kill ×100 | Mine 100 windows. |
| `adventure/travel` | goal | Adventuring Time | workspace ×10 (distinct id) | Visit all 10 workspaces. |
| `adventure/hotbar5` | task | Hotbar Shuffle | workspace ×50 | Switch workspaces 50 times. |
| `adventure/hotbar500` | goal | Fast Travel | workspace ×500 | Switch workspaces 500 times. |
| `adventure/title` | task | The Title Is Yours | chat.command (cmd starts with `/title`) | Set a /title for a workspace. |
| `adventure/tp` | task | Teleporter | chat.command (cmd starts with `/tp`) | Use /tp to jump to a workspace. |
| `adventure/give` | task | Creative Giver | chat.command (cmd starts with `/give`) | Use /give to launch an app. |
| `adventure/spectate` | task | Spectator Seat | gamemode (mode = "spectator") | Enter spectator mode for focus. |
| `adventure/creative` | task | Creative Mind | gamemode (mode = "creative") | Enter creative mode. |
| `adventure/adventure_mode` | task | Road Less Travelled | gamemode (mode = "adventure") | Enter adventure (performance) mode. |
| `adventure/all_modes` | challenge | Gamemode Collector | gamemode ×4 (distinct mode) | Use all four game modes. |
| `adventure/ten_windows` | task | Crowded Village | window.open ×10 | Open 10 windows. |
| `adventure/hundred_windows` | goal | Mass Builder | window.open ×100 | Open 100 windows. |
| `adventure/death` | task | Postmortem | death | Run out of battery and see the death screen. |
| `adventure/plugged` | task | Respawn Point | battery (percent ≥ 100; charging = true) | Reach 100 % battery after discharging. |

#### husbandry

| id | frame | title | trigger | description |
|---|---|---|---|---|
| `husbandry/root` | task | Husbandry | brew.start | Start your first brew. |
| `husbandry/brewery` | task | Local Brewery | brew.done | Finish your first brew. |
| `husbandry/brewed10` | goal | Brewed Awakening | brew.done ×10 | Finish 10 brews. |
| `husbandry/brewed100` | challenge | Master Alchemist | brew.done ×100 | Finish 100 brews. |
| `husbandry/rest` | task | A Balanced Diet | rest.done | Finish a rest break. |
| `husbandry/rest20` | goal | Well Fed | rest.done ×20 | Finish 20 rest breaks. |
| `husbandry/fresh` | task | Sleep Through the Night | $resume | Suspend and resume the machine. |
| `husbandry/night_owl` | goal | Night Owl | $time (02:00–05:00) | Be active after 02:00. |
| `husbandry/early_bird` | goal | Early Bird | $time (05:00–07:00) | Be active between 05:00 and 07:00. |
| `husbandry/week` | goal | Hero of the Village | $day ×7 (distinct date) | Use the desktop on 7 different days. |
| `husbandry/month` | challenge | Beekeeper | $day ×30 (distinct date) | Use the desktop on 30 different days. |

#### nether

| id | frame | title | trigger | description |
|---|---|---|---|---|
| `nether/root` | task | Nether | notify | Receive your first notification. |
| `nether/debris` | challenge | Cover Me in Debris | notify ×100 | Receive 100 notifications. |
| `nether/urgent` | task | Uneasy Alliance | notify (urgency = "critical") | Receive an urgent notification. |
| `nether/hot` | task | Hot Tourist Destinations | mode (mode = "dark") | Switch to Night mode. |
| `nether/thousand` | challenge | Ghast Mail | notify ×1000 | Receive 1000 notifications. |
| `nether/low` | task | Withering Hearts | battery (percent ≤ 20; charging = false) | Let the battery drop to 20 % or less. |
| `nether/critical` | goal | Hardcore | battery (percent ≤ 5; charging = false) | Let the battery drop to 5 % or less. |
| `nether/regen` | task | Regeneration | battery (percent ≤ 30; charging = true) | Plug in the charger while below 30 %. |

#### end

| id | frame | title | trigger | description |
|---|---|---|---|---|
| `end/root` | task | The End? | window.kill | Close your first window. |
| `end/free` | challenge | Free the End | window.kill ×1000 | Mine (close) 1000 windows. |
| `end/level` | goal | Great View From Up Here | xp.levelup (level ≥ 6) | Reach XP level 6 (6 hours of uptime). |
| `end/elytra` | challenge | Sky's the Limit | xp.levelup (level ≥ 24) | Reach XP level 24 (24 hours of uptime). |
| `end/everything` | challenge | How Did We Get Here? | brew.done ×10 AND window.kill ×100 AND screenshot AND world.created AND gamemode ×4 (distinct mode) AND mode (mode = "dark") AND workspace ×10 (distinct id) | Do a bit of everything: 10 brews, 100 mined windows, a screenshot, a new world, all game modes, Night mode and all 10 workspaces. |
| `end/all_adv` | challenge | Advancing Time | advancement (every other advancement unlocked) | Unlock every other advancement. |

## 5. Statistics

`Stats.qml` counts events (never keystrokes) into `stats.json`; shown in the Statistics screen (General: this session / total; Items: apps opened;
Mobs: windows mined per app). Counters: time played (shell running; a suspend does not count), games started (shell sessions), windows placed
(`window.open`), closed (`window.close`), mined (`window.kill`), workspaces visited, distance walked (sum of |workspace id hops|, in blocks),
notifications (urgent separately), brews started/completed, well-rested (`rest.done`), screenshots, apps launched, chat commands, worlds visited
(`wallpaper.set`) / created, XP levels gained, networks joined, game mode changes, deaths, advancements.

## 6. Options

Writes `config.json` in place (`scripts/game/set-config.sh`: jq + `cat >`, never `mv`, flock'd with `config.json.lock` like the CLI). Keys:

| key | values | where |
|---|---|---|
| `gui_scale` | 1–4, `"auto"` | Video / Accessibility: applies live (Theme watches the file) |
| `animations`, `reduced_motion` | bool | Video, Accessibility (Theme.reducedMotion) |
| `particles` | `"all"`, `"decreased"`, `"minimal"` | Video |
| `weather_effects` | bool | Video (fx-world) |
| `daycycle` | `"auto"`, `"day"`, `"night"` | Video, Options main, `/time` |
| `widgets.opacity` | 0.3–1 | Video, Options main |
| `sounds` | bool | Music & Sounds (`ow-sound`) |
| `sound_volume.master/ui/toasts/blocks/ambient` | 0–100 | Music & Sounds sliders (`ow-sound`) |

Difficulty is not a key: **Peaceful = Do Not Disturb** (`NotificationService.dnd`). Controls lists `hyprctl binds -j` read-only (Overworld binds
first, in yellow). Esc / Done go back one page, then close.

## 7. Files

| file | content |
|---|---|
| `~/.config/overworld/gamemode` | `survival\|creative\|adventure\|spectator` |
| `~/.config/overworld/advancements.json` | `{version, unlocked: {id: ms}, progress: {id: [{n, seen[]}]}}` |
| `~/.config/overworld/stats.json` | `{version, first, sessions, playSeconds, totals{}, apps{cls:{opened,mined}}, workspaces{}}` |
| `~/.config/overworld/chat-history.json` | last 100 typed lines |
| `~/.config/overworld/reminders.json` | pending `/msg` reminders `[{due, text}]` |
| `~/.config/overworld/config.json` | Options (see §6) |
| `$XDG_RUNTIME_DIR/overworld/events.jsonl` | the bus |
| `$XDG_RUNTIME_DIR/overworld/gamemode-widgets` | widgets state remembered while in adventure/spectator |

`OW_STATE_DIR=<dir>` redirects every file this module reads or writes (tests); `OW_EVENTS_DIR=<dir>` gives a process a private event bus (otherwise every shell on the machine shares `$XDG_RUNTIME_DIR/overworld/events.jsonl`); `OW_GAME_DRYRUN=1` prints desktop-changing commands to the
chat instead of running them; `OW_NOFOCUS=1` never takes the keyboard (previews); `OW_BRIDGE=0` disables the EventBridge; `OW_QS_ARGS` picks the shell
that IPC calls address (default `-c overworld`).

## 8. Testing

```sh
source scripts/dev-env.sh
P=$PWD/quickshell/Game/preview
# logic checks (97 assertions, temp state dir + private bus, dry-run):  grep SELFTEST
OW_SELFTEST=1 OW_EVENTS_DIR=/tmp/ow-feat-rt/overworld OW_STATE_DIR=/tmp/ow-feat-test OW_GAME_DRYRUN=1 OW_NOFOCUS=1 OW_BRIDGE=0 OW_SOUND_DRYRUN=1 OW_QS_ARGS="-p $P" timeout 25 qs -p $P
# look at a screen
OW_MODE=dark OW_EVENTS_DIR=/tmp/ow-feat-rt/overworld OW_STATE_DIR=/tmp/ow-feat-state OW_GAME_DRYRUN=1 OW_NOFOCUS=1 OW_BRIDGE=0 OW_QS_ARGS="-p $P" qs -p $P &
qs -p $P ipc call advancements inspect overworld/uptime3
XDG_RUNTIME_DIR=/tmp/ow-feat-rt scripts/overworld event window.open '{"cls":"kitty"}'   # fake events on the private bus
```
