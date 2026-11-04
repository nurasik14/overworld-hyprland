# Quickshell shell — `qs -c overworld`

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (the stock desktop returns in about 5 s, no logout); `overworld status` shows which state is active.
> The shell described here runs only while the theme is on; `off` stops it and restarts waybar and the notification daemon. How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

Owner: qs-core. Config root: `quickshell/` (symlinked to `~/.config/quickshell/overworld`). Entry: `quickshell/shell.qml`.
Desktop widgets (`quickshell/Widgets`, IPC targets `widgets` and `brew`) belong to qs-widgets and are instantiated by
`shell.qml` as `DesktopWidgets {}`.

## Layout

| path | surface | layer namespace | layer |
|---|---|---|---|
| `Bar/` | 36 px top bar: 猫 seal (launcher) · workspaces 一…十 · window title · `HH:MM · 時辰 · date` · tray · wifi · bluetooth · battery · volume · mode · bell · power | `overworld-bar` | top, exclusive |
| `Launcher/` | medicine cabinet 药柜 (900×600): search drawer, category labels, wooden drawers, `=` calculator, `>` run | `overworld-launcher` | overlay, scrim, exclusive keyboard |
| `Notifications/Notifications.qml` | paper-note popups, top-right (340 wide) | `overworld-notif` | overlay |
| `Notifications/NotificationCenter.qml` | 报 desk of notes (420 wide, right) · DND · clear all · grouped by app | `overworld-notifcenter` | overlay, scrim |
| `Network/` | 网 NETWORK (420×600, right under the bar) | `overworld-network` | overlay, scrim |
| `Power/` | five hanging scrolls 锁 出 眠 启 关 | `overworld-power` | overlay, scrim |
| `Wallpapers/` | handscroll of thumbnails at the bottom | `overworld-wallpapers` | overlay, scrim |
| `Osd/` | paper slip with an ink bar (volume / brightness) | `overworld-osd` | overlay, click-through |
| `Osd/WorkspaceCard.qml` | workspace card: numeral seal · title · `WORKSPACE n` · note, on every switch to 1–10 | `overworld-wscard` | overlay, click-through |
| `Widgets/` (qs-widgets) | desktop cards | `overworld-widgets` | bottom |

Every surface is created per screen with `Variants { model: Quickshell.screens }`; modal overlays only show on the
focused monitor (`OverlayWindow.onlyFocusedScreen`).

### Services (`quickshell/Services/`, singletons — `import qs.Services`)

| singleton | what |
|---|---|
| `ShellState` | which overlay is open (`toggle/open/close/closeAll`), one at a time; test hooks (`launcherSearch`, `networkExpand`, `wallpaperAction`) |
| `TimeService` | clock, `shichen(hour) → {glyph,name,range,…}`, `current`, `numeral(n)`, `relative(ms)` |
| `HyprlandState` | workspaces 1–10 (`exists/occupied/isActive/go/cycle`), focused window title |
| `NetworkService` | nmcli wrapper (argument arrays only): `networks`, `vpns`, `wifiEnabled`, `airplane`, `wiredState`, `connect/disconnect/forget/rescan/setWifi/setAirplane/vpnUp/vpnDown`, `lastMessage/lastError/busy` |
| `NotificationService` | the `NotificationServer` (org.freedesktop.Notifications) + tracked notes: `all`, `popups`, `groups`, `dnd`, `unread`, `dismiss/dismissAll/toggleDnd/invokeDefault` |
| `AudioService` | Pipewire default sink volume/mute, brightness via `brightnessctl -m`; signals `volumeShown/brightnessShown` |
| `WorkspaceNotes` | `~/.config/overworld/workspaces.json`, watched: `title(id)`, `note(id)`, `has(id)`, `isAuto(id)`; runs `scripts/ws-autolabel.py` while `config.json → workspace_auto.enabled` |
| `SoundService` | `play(name)` → `pw-play assets/sounds/<name>.wav`, honours `config.json {"sounds": false}` |
| `ConfigService` | `~/.config/overworld/config.json`, watched; `sounds`, `reducedMotion`, `timeoutLow/Normal`, `get("a.b.c", fallback)` |

Non-singleton helpers in the same folder: `OverlayWindow` (full-screen modal layer window: scrim, Esc, focus, open/close
animation) and `InkField` (text / password field on paper). Both are qs-core's; qs-widgets may add files here but must
not edit them.

Everything visual comes from `qs.Common` (`Theme`, `PaperPanel`, `TitleBar`, `Seal`, `InkButton`, `InkDivider`, `InkText`,
`PaperBackground`). No `qmldir` files: Quickshell registers `pragma Singleton` files automatically (DESIGN.md §12).

## IPC

```
qs -c overworld ipc call launcher toggle|open|close
qs -c overworld ipc call launcher search "<query>"          # opens + types (also "=2*3" / ">cmd")
qs -c overworld ipc call network toggle|open|close
qs -c overworld ipc call network expand "<ssid>"             # opens + expands the row's connect form
qs -c overworld ipc call network connect "<ssid>"            # saved-profile connect (no password)
qs -c overworld ipc call network rescan
qs -c overworld ipc call power toggle|open|close
qs -c overworld ipc call wallpapers toggle|open|close
qs -c overworld ipc call wallpapers select <index> | apply | next | prev
qs -c overworld ipc call notifications toggle|open|close    # notification centre
qs -c overworld ipc call notifications dnd                  # toggle do-not-disturb
qs -c overworld ipc call notifications clear
qs -c overworld ipc call notifications status               # "dnd 2 notes, 1 unread"
qs -c overworld ipc call theme toggle
qs -c overworld ipc call theme set light|dark
qs -c overworld ipc call theme get
qs -c overworld ipc call osd volume|brightness
qs -c overworld ipc call workspace reveal <1-10> | current | hide | title <n>   # workspace card
qs -c overworld ipc call shell closeAll|status
qs -c overworld ipc show                                     # lists every target incl. widgets/brew (qs-widgets)
```

Default keybinds (hyprland-engineer binds them): SUPER+Space launcher · SUPER+N network · SUPER+Escape power ·
SUPER+W wallpapers · SUPER+I notification centre · SUPER+T theme toggle.

## Behaviour notes

- **Bar clock**: `HH:MM · 午` — the 時辰 glyph follows BRIEF §2 (子23–1 … 亥21–23); tooltip shows `午 · Hour of the Horse · 11:00–13:00 · Thursday 29 October`.
- **Workspaces**: all ten are drawn; absent = 35 % muted, existing = muted, occupied = ink, active = 14 px seal behind a cream glyph. Click switches, wheel cycles.
- **Launcher**: fuzzy scoring in `Launcher/fuzzy.js` (prefix > word start > subsequence; name > genericName > keywords > comment); categories map freedesktop `Categories` to 全 All · 网 Internet · 工 Development · 画 Media · 书 Office · 器 System · 设 Settings. `=` evaluates with `Launcher/calc.js` (own recursive-descent parser: `+ - * / % ^ ( )`, decimals, sqrt/abs/round/floor/ceil/sin/cos/tan/log/ln/exp, pi, e; never `eval`) and Enter copies the result with `wl-copy`. `>` runs the rest through `sh -c` detached. Drawers enter with a 40 ms stagger (opacity + 6 px rise). The Maomao strip appears only when `assets/art/launcher-maomao.png` exists.
- **Notifications**: `NotificationServer { keepOnReload; actions; bodyMarkup; image; persistence }`. Timeouts low 4 s / normal 7 s (overridable in `config.json → notifications.timeout.{low,normal}`), critical sticky; hover pauses the timer; click on the body invokes the `default` action (or the single action), else dismisses; popups slide 16 px from the right. Critical = vermilion frame + sealWash + 印 stamped over the fold, title in `error`. Sounds `notify.wav` / `notify-urgent.wav` via `pw-play`, skipped with DND or `"sounds": false`. Popups are hidden while the centre is open; closing the centre marks everything read.
- **Network**: list = `nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY,BSSID,FREQ dev wifi list --rescan no` (`\:` escapes handled, deduped by SSID keeping the strongest / active BSSID). Connect: saved profile → `nmcli con up id <ssid>`, else `nmcli dev wifi connect <ssid> [password <pw>]`; connected row → `nmcli dev disconnect <iface>` / `nmcli con delete id <ssid>` (Forget needs a second click). Wi-Fi/airplane via `nmcli radio wifi|all on|off`; VPN/wireguard profiles via `nmcli con up|down id`. The last nmcli stderr line is shown inline under the expanded row and in the footer (error colour on failure); a spinner runs while a command is in flight. Refreshes on open and every 20 s while open (45 s light refresh for the bar chip otherwise).
- **Power**: Lock `hyprlock` · Logout `hyprctl dispatch exit` · Suspend `systemctl suspend` · Reboot `systemctl reboot` · Shutdown `systemctl poweroff`. Logout/Reboot/Shutdown arm on the first Enter/click and need a second one on the 印 Confirm seal. Letter keys L O S R P jump.
- **Wallpapers**: files from `<repo>/assets/wallpapers/<mode>` (repo resolved by `Theme.repoDir`); current = `~/.config/overworld/wallpaper-<mode>` (compared by file name so a symlinked path still matches). Apply = `overworld wallpaper <path>` when `~/.local/bin/overworld` exists, else `awww img <path> --transition-type grow --transition-duration 1.2 --transition-fps 165 --transition-bezier .22,1,.36,1` and the path is written to the state file.
- **OSD**: shows on IPC and automatically on Pipewire sink volume/mute changes (after a 1.5 s arming delay at startup). Brightness reads/sets through `brightnessctl -m -c backlight` (class-filtered: the first device on this laptop is a NIC LED). When no backlight device exists (this machine under the NVIDIA driver: `/sys/class/backlight` is empty) the slip says `亮 · Brightness · no backlight device` instead of a fake value.
- **Workspace card** (`Osd/WorkspaceCard.qml`, namespace `overworld-wscard`, click-through): when the focused workspace changes to 1–10 (after a 1.5 s arming delay at startup) a paper slip shows the numeral seal, your title, `WORKSPACE n` and your note, then fades out. Text comes from `Services/WorkspaceNotes.qml` ← `~/.config/overworld/workspaces.json` (`{"3": {"title": "Coding", "note": "…"}}`, a bare string = title only; watched live), written by `overworld ws <n> "Title" ["note"]` / `ws <n> --note "…"` / `ws <n> --clear` / `ws edit` / `ws show [n]`. Hovering a bar numeral shows the title as a tooltip. Settings in `config.json → "workspace_card"`: `enabled` (true), `duration` ms (2600), `position` `"top"|"center"|"bottom"` ("top"), `show_untitled` (true).
- **Claude auto-labelling** (`scripts/ws-autolabel.py`, off by default): `overworld ws auto on` sets `config.json → workspace_auto.enabled`; `Services/WorkspaceNotes.qml` then runs the watcher as a child of the shell (restarted 15 s after a crash, killed with the shell). It listens on Hyprland's socket2 for window open/close/move, waits `settle` s of quiet (20; at most 3 × settle), and asks Claude (`claude -p --model haiku --tools "" --json-schema …`, your logged-in plan; `ANTHROPIC_API_KEY` is stripped) for a ≤24-char title and ≤50-char note when a workspace has windows but no title; when a titled workspace's app set changes (or only its window titles changed and the last check is older than `recheck`, 600 s) and the title is older than `cooldown` (600 s), it asks Claude whether title + note still fit (`fits` + replacement, `--json-schema`) and rewrites both if not — also titles you set, unless `manage_manual: false`; a workspace empty for `reset_after` (600 s) is reset. A 60 s tick drives the timers (state in `~/.cache/overworld/ws-auto-state.json`); entries with `"pinned": true` (`ws <n> --pin`) are skipped. One watcher at a time (flock on `~/.cache/overworld/ws-auto.pid`, a new one replaces the old; `PR_SET_PDEATHSIG` so it dies with the shell). Auto labels are stored with `"auto": true` (card subtitle `WORKSPACE n · AUTO`, `(auto)` in `overworld ws`). Window classes and titles are sent, and for terminals the commands started from their shell (`/proc` tree: name + cwd) and, for a Hermes CLI, its latest top-level `local` session title from `~/.hermes/state.db` (Hermes does not store the pid, so a session is matched to the newest Hermes CLI started before it) (`send_titles: false` = classes only); `max_per_hour` (20) caps calls. Commands: `ws auto on|off|status|now [n]|clear|log`, `ws <n> --auto`. Log `~/.cache/overworld/ws-auto.log`.
- **Mode**: `Theme.setMode()` (bar sun/moon chip, `theme` IPC) writes `~/.config/overworld/mode` (or calls `overworld light|dark` when installed); every surface cross-fades through Theme.

## Testing (what was verified on 2026-10-29)

```
source scripts/dev-env.sh
ln -sfn ~/Projects/overworld-hyprland/quickshell ~/.config/quickshell/overworld
qs -c overworld > /tmp/qs-overworld.log 2>&1 &
grim -o eDP-1 qa/screenshots/qs-core-<surface>.png
```

Screenshots in `qa/screenshots/` (gitignored): `qs-core-bar-{light,dark}.png`, `qs-core-launcher-{light,dark}.png`,
`qs-core-notification.png` (normal + critical with actions), `qs-core-notifcenter.png`, `qs-core-network.png`
(real adapter: <home-wifi> connected, <campus-wifi> expanded with the inline error for the non-existent SSID
`overworld-test`), `qs-core-power.png`, `qs-core-wallpapers.png` (wallpaper applied through the picker), `qs-core-osd.png`.

- Every IPC target above was exercised while the shell ran; `shell status` reports open-state, mode and Wi-Fi.
- Keyboard focus returns to the previously focused window after an overlay closes (checked with `hyprctl activewindow`).
- The notification daemon registered after stopping the user's `mako.service` for the test (`busctl --user list` showed
  `org.freedesktop.Notifications` owned by `qs`); mako was started again afterwards. With `overworld on` the
  `session-start` script must stop swaync/mako before starting the shell, otherwise the server logs
  "Could not register notification server" and keeps retrying.
- qs log is clean apart from environment noise: malformed third-party `.desktop` files (`swappy` exec string,
  icons pointing at `/home/yourusername/...`) and Qt's `qt.svg.draw: The requested buffer size is too big` for a few
  oversized SVG app icons.

### Known gaps

- Keyboard paths (arrows / Enter / Esc / Tab) are implemented but were not driven in the headless run (no `wtype`/`ydotool`);
  Esc is handled by `OverlayWindow`'s FocusScope and by `InkField`.
- Tray menus use `QsMenuAnchor` (native popup); the shell runs without `//@ pragma UseQApplication` to keep the log free of
  the KIconThemes thread warning — if a tray menu refuses to open, re-add that pragma at the top of `shell.qml`.
- Notification popups anchor top-right under whatever reserves the top edge (currently waybar + this bar during tests).
- Hidden (empty-SSID) networks are skipped; enterprise (802.1X) networks need a saved profile (the form explains this).
- No pagination dots in the launcher — the grid scrolls instead.
