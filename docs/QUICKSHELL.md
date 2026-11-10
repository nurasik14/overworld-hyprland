# Quickshell shell — `qs -c overworld`

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (what was there before comes back, Apothecary or the stock desktop, no logout); `overworld status` shows which state is active.
> The shell described here runs only while the theme is on; `off` stops it and restarts waybar and the notification daemon. How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

Owner: qs-core. Config root: `quickshell/` (symlinked to `~/.config/quickshell/overworld`). Entry: `quickshell/shell.qml`.
Look and components: [DESIGN.md](DESIGN.md). Other modules, instantiated by `shell.qml`: `Widgets/` ([WIDGETS.md](WIDGETS.md)), `Game/` ([GAMEPLAY.md](GAMEPLAY.md)),
`World/`, `Interact/`.

## Surfaces

| path | Minecraft element | layer namespace | layer |
|---|---|---|---|
| `Bar/Bar.qml` | HUD: hotbar, hearts, hunger, air, XP, and the slots on both sides of the hotbar | `overworld-bar` | top, reserves 40 GUI px (80 px) at the bottom edge |
| `Bar/BossBar.qml` | boss bar: brew timer, else the playing track | `overworld-bossbar` | top, click-through |
| `Bar/WidgetsMenu.qml` | panel above the item-frame slot: each desktop card on/off, reset positions | `overworld-widgetsmenu` | overlay |
| `Launcher/` | creative inventory | `overworld-launcher` | overlay, keyboard |
| `Notifications/Notifications.qml` | toasts, top-right, at most 5 drawn | `overworld-notif` | overlay |
| `Notifications/NotificationCenter.qml` | chat history, Difficulty button | `overworld-notifcenter` | overlay, keyboard |
| `Network/` | Multiplayer screen | `overworld-network` | overlay, keyboard |
| `Power/` | Game Menu and its confirm screen | `overworld-power` | overlay, keyboard |
| `Wallpapers/` | Select World, world-loading screen | `overworld-wallpapers` | overlay, keyboard |
| `Osd/Osd.qml` | Options slider | `overworld-osd` | overlay, click-through |
| `Osd/WorkspaceCard.qml` | /title | `overworld-wscard` | overlay, click-through |
| `Brew/` | brewing stand GUI | `overworld-brew` | overlay, keyboard |

Every surface is created per screen with `Variants { model: Quickshell.screens }`; modal overlays only show on the
focused monitor (`OverlayWindow.onlyFocusedScreen`).

There is no top bar any more. The top of the screen stays free, as in the game: the boss bar and toasts appear there only while active.

### The HUD

All numbers are the game's, in GUI px from the bottom of the screen:

| what | where | shows |
|---|---|---|
| hotbar | y−22 | workspaces 1–9. Item = the app with the most windows there (`tokens/items.json`, title rules first, so Hermes in kitty is its own item), stack count = windows, empty workspace = empty slot. Click switches, wheel cycles, the selection frame snaps |
| offhand, left | beside the hotbar | workspace 10 |
| offhand, right | beside the hotbar, only when occupied | special workspaces, as an ender chest with the window count; click toggles |
| tooltip on a slot | above the hotbar | title and note from `WorkspaceNotes`, the apps in it, workspace number |
| item name | y−59, fades after 2 s | the workspace title on every switch |
| XP bar + level | y−29, level y−35 | level = hours of uptime, bar = progress through the hour. A new hour plays `xp.levelup`, emits `xp.levelup {level}`, and glitter comes off the number |
| hearts | y−39, left | battery, in half hearts. A heart travels along the row while charging, the row jiggles below 20 %, hardcore hearts at 5 % or less. Blinks on `battery {flash: true}` |
| hunger | y−39, right | free RAM (MemAvailable/MemTotal). Shakes and turns green while over half of swap is in use |
| air | y−49, right | CPU headroom: full = idle, every popped bubble is 10 % load |

**Air, not armour, for the CPU:** in the game armour says how protected you are and only changes when you change gear. Air drains under pressure and bursts bubble by
bubble, which is what CPU load looks like. The row is the only HUD part above the 80 reserved px, and small, so it may overlap the bottom edge of a window by its 18 px.

Left of the hotbar: crafting table (launcher), item frame (widgets; click = cards, middle-click = all on/off), the focused window's title.
Right of the hotbar: tray items, ping bars (Wi-Fi; opens Multiplayer), ender pearl (Bluetooth; opens blueman), note block (volume; click mutes, wheel changes), sun or moon (mode),
bell (unread count as the stack; click = history, middle-click = Peaceful), oak door (Game Menu), `Day 309, 14:32` (hover: real date). If the row does not fit, as at GUI scale 3, the clock moves above it.

**Game modes** (read from `~/.config/overworld/gamemode`, watched): spectator hides the HUD and boss bar and gives the reserved space back; creative turns off the jiggle, hardcore hearts and hunger shake.

### Services (`quickshell/Services/`, singletons — `import qs.Services`)

| singleton | what |
|---|---|
| `ShellState` | which overlay is open (`toggle/open/close/closeAll`), one at a time; `hudHidden`; `run(cmd)` (detached, only logged in previews); `ipc(target, fn, args…)` calls an IpcHandler in this same process; test hooks `launcherSearch`, `networkExpand`, `wallpaperAction` |
| `ConfigService` | `config.json`, watched. `get("a.b", fallback)`, `set("a.b", value)` (in place, through jq), defaults for every key below; `gamemode`, `isCreative`, `isSpectator` |
| `SystemStats` | battery (UPower), `/proc` memory, CPU, uptime. Emits `battery`, `xp.levelup` |
| `TimeService` | clock, `dayOfYear`, `mcClock` ("Day 309, 14:32"), `phase`, `relative(ms)` |
| `HyprlandState` | workspaces 1–10 (`exists/occupied/isActive/go/cycle`), focused window; `info(id)` = what a slot shows; `specials`, `activeSpecial`, `toggleSpecial`. Emits `workspace` |
| `NetworkService` | nmcli wrapper (argument arrays only): `networks`, `vpns`, `wifiEnabled`, `airplane`, `wiredState`, `connect/disconnect/forget/rescan/setWifi/setAirplane/vpnUp/vpnDown`, `pingLevel`, `motd`, `lastMessage/lastError/busy`. Emits `net.connect` |
| `NotificationService` | the `NotificationServer` (org.freedesktop.Notifications) + tracked notes: `all`, `popups`, `groups`, `dnd` (Peaceful, persisted as `difficulty`), `unread`, `dismiss/dismissAll/setDnd/toggleDnd/invokeDefault`, `test(…)`. Emits `notify` |
| `AudioService` | Pipewire default sink volume/mute, brightness via `brightnessctl -m`; signals `volumeShown/brightnessShown` |
| `WorkspaceNotes` | `~/.config/overworld/workspaces.json`, watched: `title(id)`, `note(id)`, `has(id)`, `isAuto(id)`; `displayTitle(id)` and `subtitle(id, cls, count)` fall back to `quotes/titles.json`; runs `scripts/ws-autolabel.py` while `workspace_auto.enabled` |
| `SoundService` | `play(id)` → `scripts/ow-sound <id>` (one player, BRIEF §4.5). Old names still work: `login` → `door.open`, `notify`, `notify-urgent` → `notify.urgent`, `brew-done` → `brew.done`, `seal` and `click` → `ui.click` |
| `GameEvents` | the event bus (qs-features; BRIEF §4.4) |

Non-singleton helper: `OverlayWindow` (full-screen modal layer window around `McScreen`: dim, Esc, focus, the fade, unmapping).

Everything visual comes from `qs.Common`. No `qmldir` files: Quickshell registers `pragma Singleton` files automatically.

### config.json keys

| key | default | read by |
|---|---|---|
| `gui_scale` | 2 (1–4 or `"auto"`) | Theme |
| `sounds` | true | Theme, ow-sound |
| `sound_volume.{master,ui,toasts,blocks,ambient}` | 100 (0–100) | ow-sound |
| `animations`, `reduced_motion` | true, false | Theme |
| `particles` | `"all"` (`"decreased"`, `"minimal"`) | fx modules |
| `weather_effects` | true | fx-world |
| `daycycle` | `"auto"` (`"day"`, `"night"`, `"off"`) | fx-world |
| `difficulty` | `"normal"` (`"peaceful"` = DND) | NotificationService |
| `widgets.opacity` | 0.72 | Theme, Widgets |
| `death_screen` | true | fx-interactions |
| `hud.bossbar_media` | `"playing"` (`"track"` = 10 s when a track starts, `"off"`) | BossBar |
| `notifications.timeout.{low,normal}` | 4000, 7000 ms | NotificationService |
| `workspace_card.enabled` | true | WorkspaceCard |
| `workspace_card.duration` | unset = 70 ticks of stay; ms overrides | WorkspaceCard |
| `workspace_card.position` | `"center"` (`"top"`, `"bottom"`) | WorkspaceCard |
| `workspace_card.show_untitled` | true | WorkspaceCard |
| `workspace_auto.enabled` | false | WorkspaceNotes |

Other state: `~/.config/overworld/launcher.json` (favourites), `~/.cache/overworld/worlds-played.json` (last played times in Select World).

## IPC

```
qs -c overworld ipc call launcher toggle|open|close
qs -c overworld ipc call launcher search "<query>"          # opens + types (also "=2*3" / ">cmd")
qs -c overworld ipc call network toggle|open|close
qs -c overworld ipc call network expand "<ssid>"             # opens, selects the row, password screen if it needs one
qs -c overworld ipc call network connect "<ssid>"            # saved-profile connect (no password)
qs -c overworld ipc call network rescan
qs -c overworld ipc call power toggle|open|close
qs -c overworld ipc call wallpapers toggle|open|close
qs -c overworld ipc call wallpapers select <index> | apply | next | prev   # next/prev: picker closed = cycle the wallpaper (same as `overworld wallpaper next`, does not open it); open = move the selection
qs -c overworld ipc call notifications toggle|open|close    # chat history
qs -c overworld ipc call notifications dnd                  # toggle Peaceful
qs -c overworld ipc call notifications setDnd true|false
qs -c overworld ipc call notifications clear
qs -c overworld ipc call notifications status               # "dnd 2 notes, 1 unread"
qs -c overworld ipc call notifications test "<summary>" "<body>" low|normal|critical
qs -c overworld ipc call theme toggle
qs -c overworld ipc call theme set light|dark
qs -c overworld ipc call theme get
qs -c overworld ipc call osd volume|brightness
qs -c overworld ipc call workspace reveal <1-10> | current | hide | title <n>   # /title
qs -c overworld ipc call hud reveal|hide|toggle|status
qs -c overworld ipc call shell closeAll|status
qs -c overworld ipc call nowplaying toggle|on|off|status|reveal|reset   # the Now Playing PiP (docs/NOWPLAYING.md)
qs -c overworld ipc show                                     # lists every target of every module
```

Default keybinds (hyprland-engineer binds them, see [KEYBINDS.md](KEYBINDS.md)): SUPER+Space launcher · SUPER+N network · SUPER+Escape Game Menu ·
SUPER+W worlds · SUPER+I history · SUPER+SHIFT+I Peaceful · SUPER+T mode · SUPER+SHIFT+B brewing stand.

## Behaviour notes

- **Launcher**: fuzzy scoring in `Launcher/fuzzy.js` (prefix > word start > subsequence; name > genericName > keywords > comment). Tabs: Search (every app until you type; typing on any tab jumps here, as in the game), Favourites, Internet, Development, Media, Office, System, then Settings and Games below the panel. An app's icon is its item from `tokens/items.json` when it has one (by desktop id, class, icon name or name), else its own icon. Tooltip: name, grey description, blue category; the keyboard cursor shows it too. `=` evaluates with `Launcher/calc.js` (own recursive-descent parser: `+ - * / % ^ ( )`, decimals, sqrt/abs/round/floor/ceil/sin/cos/tan/log/ln/exp, pi, e; never `eval`), Enter copies with `wl-copy`. `>` runs the rest through `sh -c` detached. Keys: arrows, PageUp/PageDown, Enter, Esc, Tab/Shift+Tab, Ctrl+F favourite. Right-click favourites; favourites wear a small star, and the first nine fill the hotbar row. Sounds: `chest.open`, `chest.close`. Emits `launcher.launch {app}`.
- **Notifications**: `NotificationServer { keepOnReload; actions; bodyMarkup; image; persistence }`. Timeouts low 4 s / normal 7 s (overridable, see above), critical sticky; hover pauses the timer and the green line; a click on the body invokes the `default` action (or the single action), else dismisses; the cross on hover dismisses. Normal = advancement frame with a yellow title. Critical = purple "Challenge Complete!" with the summary under it. Low = the light recipe frame. Icon slot: the note's image, else its app icon, else the app's item. Sounds `ui.toast.in/out/challenge`, none under Peaceful (no toast either; notes wait in the history). Toasts are hidden while the history is open; closing it marks everything read. The volume and brightness notes of JaKooLit's scripts are swallowed: the OSD covers those keys.
- **Network**: list = `nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY,BSSID,FREQ dev wifi list --rescan no` (`\:` escapes handled, deduped by SSID keeping the strongest / active BSSID). Join: saved profile → `nmcli con up id <ssid>`, else `nmcli dev wifi connect <ssid> [password <pw>]`. Direct Connection adds `hidden yes`. Connected row: Disconnect → `nmcli dev disconnect <iface>`. Forget needs a second click → `nmcli con delete id <ssid>`. Wi-Fi and airplane via `nmcli radio wifi|all on|off`; VPN and WireGuard profiles via `nmcli con up|down id`, as rows under LAN Worlds; wired is a row there too. The last nmcli line shows in the header, and in red on the password screen, on failure. The selected row's bars animate while a command runs. Refreshes on open and every 20 s while open (45 s light refresh for the HUD otherwise). Keys: Up/Down, Enter, F5, Esc. Emits `net.connect {ssid}`.
- **Game Menu**: Lock `hyprlock` · Sleep in Bed `systemctl suspend` · Respawn `systemctl reboot` · Save and Quit to Title `hyprctl dispatch exit` · Quit Game `systemctl poweroff`. The last three go through a confirm screen where No is selected: Enter there goes back; Y or Yes confirms. Keys: arrows, Enter, Esc; letters L, S, R, O, P jump to them (as in Apothecary). Advancements, Statistics, Options open qs-features' screens.
- **Worlds**: rows from `assets/wallpapers/index.json` (`file`, `thumb`, `title`, `seed`, `world`) for the current mode, plus any other picture in `assets/wallpapers/<mode>/`; dawn and dusk variants are left to fx-world's cycle. Current = `~/.config/overworld/wallpaper-<mode>`, compared by file name. Play = `overworld wallpaper <path>` when `~/.local/bin/overworld` exists, else `awww img <path> --transition-type grow --transition-duration 1.2 --transition-fps 165 --transition-bezier .22,1,.36,1` and the path is written to the state file; emits `wallpaper.set`. Clicking a thumbnail or double-clicking a row plays it. Create New World runs `scripts/make-world.sh --mode <mode>` behind the game's loading screen. The percentage is an estimate, because the script reports no progress. Closing the screen leaves it running, and the new world ends up selected; the script emits `world.created` itself. Delete asks first, never touches the world in use, and also removes the row from the index. Random picks a row.
- **OSD**: shows on IPC and on Pipewire sink volume or mute changes (after a 1.5 s arming delay at startup). Brightness reads through `scripts/backlight-dev.sh` + `brightnessctl -m -d`, so the backlight of the connected display is used. Labels: `Moody (n%)` up to 25 %, `Bright (100%)` at full, plain percent between. Without a backlight device it says `Brightness: no device`.
- **/title**: when the focused workspace changes to 1–10 (after 1.5 s at startup). Fade-in 10 ticks, stay 70, fade-out 20. Title at 4× the font, or 2× if it would leave the screen; subtitle at 2×. Text: `overworld ws <n> "Title" ["note"]` / `ws <n> --note "…"` / `ws <n> --clear` / `ws edit` / `ws show [n]`, else `quotes/titles.json`: a default per slot, and a line chosen by the dominant app's category (`· auto` marks Claude's labels).
- **Claude auto-labelling** (`scripts/ws-autolabel.py`, off by default): `overworld ws auto on` sets `config.json → workspace_auto.enabled`; `Services/WorkspaceNotes.qml` then runs the watcher as a child of the shell (restarted 15 s after a crash, killed with the shell). It listens on Hyprland's socket2 for window open/close/move, waits `settle` s of quiet (20; at most 3 × settle), and asks Claude (`claude -p --model haiku --tools "" --json-schema …`, your logged-in plan; `ANTHROPIC_API_KEY` is stripped) for a ≤24-char title and ≤50-char note when a workspace has windows but no title; when a titled workspace's app set changes (or only its window titles changed and the last check is older than `recheck`, 600 s) and the title is older than `cooldown` (600 s), it asks Claude whether title + note still fit (`fits` + replacement, `--json-schema`) and rewrites both if not — also titles you set, unless `manage_manual: false`; a workspace empty for `reset_after` (600 s) is reset. A 60 s tick drives the timers (state in `~/.cache/overworld/ws-auto-state.json`); entries with `"pinned": true` (`ws <n> --pin`) are skipped. One watcher at a time (flock on `~/.cache/overworld/ws-auto.pid`, a new one replaces the old; `PR_SET_PDEATHSIG` so it dies with the shell). Auto labels are stored with `"auto": true`. Window classes and titles are sent, and for terminals the commands started from their shell (`/proc` tree: name + cwd) and, for a Hermes CLI, its latest top-level `local` session title from `~/.hermes/state.db` (Hermes does not store the pid, so a session is matched to the newest Hermes CLI started before it) (`send_titles: false` = classes only); `max_per_hour` (20) caps calls. Commands: `ws auto on|off|status|now [n]|clear|log`, `ws <n> --auto`. Log `~/.cache/overworld/ws-auto.log`.
- **Brewing stand**: the top of `gui/container/brewing_stand` with the running timer drawn on it: arrow = progress of the phase, bubbles rise while it runs, fuel gauge = time left, nether wart in the top slot (a cookie while resting), blaze powder in the fuel slot, one potion per finished brew, in threes. Fields take any duration (25 · 50m · 1h30 · 90s · 1:30; rest 0 = none). Enter = save and start, or only save while a brew runs. Tab next field, Up/Down ±1 min, Esc closes. Saving goes through `overworld brew set` via `BrewTimer.save()`.
- **Boss bar**: brew first: `Brewing: <workspace title>  12:34`, purple with notches, drains as time passes; green while resting; yellow when paused. Else the playing media, pink, following the track. Note that with `hud.bossbar_media: "playing"` the bar stays over the top of your windows as long as music plays; `"track"` shows it for 10 s per track.
- **Mode**: `Theme.setMode()` (sun/moon slot, `theme` IPC) writes `~/.config/overworld/mode` (or calls `overworld light|dark` when installed); every surface cross-fades through Theme.

## Preview and testing

```
source scripts/dev-env.sh
OW_PREVIEW=1 OW_MODE=light OW_SURFACE=launcher qs -p quickshell/Bar/preview      # dark for Night
quickshell/Bar/preview/shot.sh <surface> <light|dark> [region] [suffix]          # starts it, dev-shot.sh, stops it
OW_PREVIEW=1 OW_SOUND_DRYRUN=1 OW_SELFTEST=1 qs -p quickshell/Bar/preview        # PASS/FAIL lines, DRYRUN lines for commands
```

`OW_SURFACE`: `hud launcher launcher-tip launcher-calc launcher-search launcher-fav notifications notifcenter network network-password power power-confirm wallpapers wallpapers-create wallpapers-delete osd brightness title brew bossbar itemname hudtip stacks levelup widgetsmenu`.

Preview pins: `OW_PREVIEW=1` (no exclusive zone, no keyboard grab, no writes to `config.json`, every command that would touch the desktop only logged), `OW_MODE`, `OW_GUI`, `OW_NO_MOJANG`, `OW_REDUCED_MOTION` (Theme), `OW_FAKE_WS=<n>` (focused workspace; `dev-shot.sh` sits on 77), `OW_FAKE_STATS='{"battery":18,"charging":false,"ram":0.4,"cpu":0.7,"uptime":3.5,"swap":0.6}'`, `OW_GAMEMODE=creative`, `OW_CONFIG=<file>` (ConfigService on a scratch file, written even in previews).

**How the self-test gets real input:** `Bar/preview/SelfTest.qml` uses QtTest's `TestEvent`, which injects hover, click, wheel and key events straight into a window's event queue. All handlers run, but the compositor sees nothing: the actual pointer does not move and other windows receive nothing.

**Testing the real D-Bus daemon while mako owns the bus:** `dbus-run-session -- bash -c 'OW_PREVIEW=1 qs -p quickshell & sleep 3; notify-send -u critical Hello World'`. A private session bus has no other daemon, so the shell's server registers there and mako is left alone.

`qs` logs environment noise that is not ours: malformed third-party `.desktop` files (the `swappy` exec string, icons pointing at `/home/yourusername/...`), and `qt.svg.draw: The requested buffer size is too big` for a few oversized SVG app icons.

### Known gaps

- Hidden (empty-SSID) networks are skipped in the list; join them with Direct Connection. Enterprise (802.1X) networks need a saved profile (the password screen says so).
- Tray menus use `QsMenuAnchor` (native popup); the shell runs without `//@ pragma UseQApplication` to keep the log free of the KIconThemes thread warning. If a tray menu refuses to open, re-add that pragma at the top of `shell.qml`.
