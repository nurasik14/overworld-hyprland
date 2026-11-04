# Maomao's Workbench: a Hyprland field guide

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (the stock desktop returns in about 5 s, no logout); `overworld status` shows which state is active.
> The Overworld binds and panels in this guide need the theme on; the JaKooLit parts work in both states. How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

> *"Poison or medicine, it all depends on the dose."* The same goes for keybinds.

This guide covers what Hyprland can do **on this machine**: Hyprland 0.56.2 on Fedora 44 with
JaKooLit/KoolDots dotfiles in `~/.config/hypr` and the Overworld theme layer from this repo on top. I checked
every key here against the live bind list (`hyprctl binds -j`) and the config files it comes from. If a key
isn't in this guide, it isn't bound.

Notation: `SUPER` is the Windows key. `SUPER+SHIFT+Space` means hold SUPER and SHIFT, then tap Space.
"Number row" means the `1 … 0` keys above the letters (`0` is workspace 10).

---

## 0. The cheat sheet (pin this to the cabinet door)

| Key | What it does |
|---|---|
| `SUPER+Return` | Terminal (kitty) |
| `SUPER+Space` / `SUPER+D` | Launcher (the medicine cabinet 药柜) |
| `SUPER+Q` | Close window |
| `SUPER+SHIFT+Space` | **Float / unfloat the window** (was `SUPER+Space` in stock JaKooLit) |
| `SUPER` + left-drag | Move a window with the mouse |
| `SUPER` + right-drag | Resize a window with the mouse |
| `SUPER+arrows` | Focus left / right / up / down |
| `SUPER+CTRL+arrows` | Move window in that direction |
| `SUPER+SHIFT+arrows` | Resize window (hold to repeat) |
| `SUPER+F` / `SUPER+SHIFT+F` | Maximize (bar stays) / true fullscreen |
| `SUPER+1…0` | Go to workspace 1–10 |
| `SUPER+SHIFT+1…0` | Move window to workspace and follow it |
| `SUPER+CTRL+1…0` | Move window to workspace silently (you stay put) |
| `SUPER+U` / `SUPER+SHIFT+U` | Show/hide scratchpad / send window to it |
| `SUPER+A` | Overview of all workspaces |
| `SUPER+E` | File manager (superfile, a floating sheet) |
| `SUPER+N` | Network panel 网 |
| `SUPER+I` | Notification centre 报 (`SUPER+SHIFT+I` = do not disturb) |
| `SUPER+W` | Wallpaper picker (`SUPER+SHIFT+W` next, `CTRL+ALT+W` random) |
| `SUPER+T` | Light ↔ dark (Overworld 薬屋 ↔ Inner Palace 后宫) |
| `SUPER+G` | Desktop widgets on/off |
| `SUPER+B` | Brew timer start/pause (`SUPER+SHIFT+B` = set brew / rest time) |
| `SUPER+Escape` | Power menu (five hanging scrolls) |
| `CTRL+ALT+L` | Lock screen |
| `SUPER+ALT+R` | **Repair** the theme if something broke it |

Also good to know: `SUPER+SHIFT+S` screenshot and annotate · `SUPER+ALT+V` clipboard history ·
`SUPER+ALT+E` emoji · `SUPER+SHIFT+G` game mode · `SUPER+Z` browser.
Name a workspace: `overworld ws 3 "Coding" "what it is for"` — a card shows it whenever you switch there; or let
Claude do it with `overworld ws auto on` (§3.6).

---

## 1. The mental model in 10 lines

1. **Hyprland is the compositor.** It draws every window, owns every keybind and runs the animations. There's no separate "desktop".
2. **Windows tile by default.** New windows split the space with the ones already there (the *dwindle* layout). Nothing overlaps.
3. **A floating window** leaves the tiling and behaves like a normal desktop window: you can move it, resize it, and let it overlap others.
4. **Workspaces 1–10** are separate desks. A workspace only exists while it has windows (or while you're on it).
5. **The special workspace** (scratchpad) is a hidden drawer that slides down over whatever desk you're on, then hides again.
6. **Layers** sit outside the tiling: the 36 px bar, notifications, the launcher and the desktop widget cards. Quickshell (`qs -c overworld`) draws all of these, not waybar.
7. **JaKooLit** supplies the base: keybinds, scripts and rofi menus in `~/.config/hypr/configs` and `scripts/`.
8. **The Overworld layer** loads *last* (`hypr/on.conf`). It overrides decorations, animations, rules and some keys, and swaps waybar/swaync for the Quickshell shell.
9. **`overworld off`** returns the stock JaKooLit desktop without logging out. `overworld on` brings the workbench back.
10. **When in doubt**, run `hyprctl binds` (the live truth) or `overworld repair` (`SUPER+ALT+R`).

---

## 2. Window management

### 2.1 Focus, move, swap

| Key | Action |
|---|---|
| `SUPER+←/→/↑/↓` | Focus the neighbour in that direction (layout-aware script) |
| `SUPER+J` / `SUPER+K` | Focus the next / previous window (layout-aware) |
| `ALT+Tab` | Focus the next window and raise it (good for overlapping floats) |
| `SUPER+CTRL+S` | Window switcher (rofi list of every window) |
| `SUPER+CTRL+←/→/↑/↓` | **Move** the window in that direction (it takes a new slot) |
| `SUPER+ALT+←/→/↑/↓` | **Swap** places with the neighbour |
| `SUPER+Q` | Close politely (like clicking ×) |
| `SUPER+SHIFT+Q` | `kill` the window's process (`KillActiveProcess.sh`) for frozen apps |

Focus follows the mouse (`input:follow_mouse = 1`): hover over a window to focus it.

### 2.2 Resize

| How | Action |
|---|---|
| `SUPER+SHIFT+←/→` | Width −50 / +50 px (hold to repeat) |
| `SUPER+SHIFT+↑/↓` | Height −50 / +50 px (hold to repeat) |
| `SUPER` + **right**-drag | Free resize with the mouse (`bindm SUPER, mouse:273`) |
| `SUPER` + **left**-drag | Move with the mouse (`bindm SUPER, mouse:272`). A tiled window gets re-slotted where you drop it |
| Drag a window **border** | Resize without a modifier (`resize_on_border = true`) |

On a tiled window, resizing moves the split line between it and its neighbours. On a floating window it changes
the window itself.

### 2.3 "What happened to SUPER+Space? How do I float a window and resize it freely?"

While the theme is on, `SUPER+Space` opens the launcher. **Floating moved to `SUPER+SHIFT+Space`.** To float a
window and resize it freely:

1. Focus it and press **`SUPER+SHIFT+Space`**. It pops out of the tiling and floats.
2. Resize it with **`SUPER` + right-drag** anywhere inside the window, or grab the 2 px border and drag. Use `SUPER+SHIFT+arrows` for 50 px steps.
3. Move it with **`SUPER` + left-drag**.
4. Press `SUPER+SHIFT+Space` again to drop it back into the tiling.

Related:

| Key / gesture | Action |
|---|---|
| `SUPER+ALT+Space` | Toggle floating on **every** window of the current workspace (`Float-all-Windows.sh`) |
| 4-finger swipe **down** (touchpad) | Toggle floating on the active window |
| `ALT+Tab` | Raise a floating window that got buried |

Some windows float automatically: superfile (70 % centred), pavucontrol, blueman, nm-connection-editor,
nwg-look, qt5ct/qt6ct/kvantum, and picture-in-picture (also pinned).

### 2.4 Fullscreen, maximize, pin, centre, opacity

| Key | Action |
|---|---|
| `SUPER+F` | **Maximize** (`fullscreen 1`): fills the work area, and the bar stays visible |
| `SUPER+SHIFT+F` | **True fullscreen** (`fullscreen 0`): covers the bar. Fullscreen windows are 100 % opaque and undimmed |
| `SUPER+CTRL+O` | Make the active window fully opaque (toggle). Handy for photos and colour work |
| `SUPER+SHIFT+H` | Mute/unmute just this window's audio |
| *pin* | **No bind.** Run `hyprctl dispatch pin` (floating window stays on every workspace) or add a bind (§6.2) |
| *centre* | **No bind.** Run `hyprctl dispatch centerwindow`, or add one (§6.2) |

### 2.5 Groups (tabbed windows)

A group stacks several windows in one tile, with a tab bar on top. Click a tab to switch to it.

| Key | Action |
|---|---|
| `SUPER+ALT+G` | Turn the window into a group, or dissolve the group (was `SUPER+G` in JaKooLit) |
| `SUPER+CTRL+K` | Move the window into the group on its **left** ⚠ |
| `SUPER+CTRL+L` | Move the window into the group on its **right** |
| `SUPER+CTRL+H` | Take the window out of its group |
| `SUPER+CTRL+Tab` | Next tab in the group (the clean choice, see below) |
| `SUPER+Tab` / `SUPER+SHIFT+Tab` | Next / previous tab ⚠ |

⚠ **Two JaKooLit double-binds** (both binds fire, as I read the config):
- `SUPER+Tab` is bound to *next group tab* **and** *next workspace*, and `SUPER+SHIFT+Tab` to *previous tab* and *previous workspace*. So pressing it also jumps desks. Use `SUPER+CTRL+Tab` or click the tabs.
- `SUPER+CTRL+K` is *move into group left* **and** *Kitty theme selector*. Close the rofi menu with Esc. Don't pick a kitty theme while the Overworld is on (§5.3).

### 2.6 Layouts: dwindle, master, scrolling, monocle

The default is **dwindle** (`general:layout = dwindle`). Workspaces **3 and 5 start in master**
(`~/.config/hypr/workspaces.conf`). You can change the layout of the current workspace at any time, and JaKooLit
remembers it (`PersistWorkspaceLayout.sh`).

| Key | Action |
|---|---|
| `SUPER+ALT+1` | Dwindle: binary splits, each new window halves the focused one |
| `SUPER+ALT+2` | Master: one big "master" pane plus a stack (`mfact 0.55`, master on the left) |
| `SUPER+ALT+3` | Scrolling: a horizontal strip of columns (80 % wide) you scroll through |
| `SUPER+ALT+4` | Monocle: one window at a time, full size |
| `SUPER+ALT+L` | Cycle through the layouts (`ChangeLayout.sh toggle`) |

**Dwindle tools**

| Key | Action |
|---|---|
| `SUPER+CTRL+I` | Toggle split direction (side by side ↔ stacked) (was `SUPER+SHIFT+I`) |
| `SUPER+P` | Pseudo-tile: keeps the window's own size inside its tile |
| `SUPER+M` | Labelled "Set split ratio 0.3". It sends `splitratio 0.3`, which Hyprland treats as a relative +0.3 nudge. Use `SUPER+SHIFT+arrows` to fine-tune |

**Master tools**

| Key | Action |
|---|---|
| `SUPER+CTRL+Return` | Swap the focused window with the master |
| `SUPER+ALT+I` | Add a master (two windows share the big pane) (was `SUPER+I`) |
| `SUPER+CTRL+D` | Remove a master |

**Scrolling tools**

| Key | Action |
|---|---|
| `SUPER+R` | Cycle the column width preset |
| `SUPER+SHIFT+.` / `SUPER+SHIFT+,` | Move the window to the right / left column |
| `SUPER+ALT+.` / `SUPER+ALT+,` | Swap the whole column right / left |
| `SUPER+ALT+H` | Scroll direction: horizontal |
| `SUPER+ALT+V` | Scroll direction: vertical (**also** opens the clipboard menu, a JaKooLit double-bind) |
| `SUPER+ALT+S` | Toggle vertical ↔ horizontal |

---

## 3. Workspaces

### 3.1 Switching and moving

| Key | Action |
|---|---|
| `SUPER+1…0` | Go to workspace 1–10. Press the current one again to bounce back to the previous desk (`workspace_back_and_forth`) |
| `SUPER+.` / `SUPER+,` | Next / previous existing workspace |
| `SUPER` + mouse wheel | Next / previous workspace |
| `SUPER+Tab` / `SUPER+SHIFT+Tab` | Next / previous workspace (also flips group tabs, see §2.5) |
| `SUPER+SHIFT+1…0` | Move the window **and follow** it |
| `SUPER+CTRL+1…0` | Move the window **silently** (you stay where you are) |
| `SUPER+SHIFT+[` / `SUPER+SHIFT+]` | Move the window to the previous / next workspace and follow |
| `SUPER+CTRL+[` / `SUPER+CTRL+]` | Same, silently |
| `SUPER+CTRL+F9…F12` | Push the whole workspace to the left/right/up/down monitor (only matters with an external screen) |

Bar: the ten workspaces show as 一 … 十. Click one to jump there, or scroll over them to cycle. Absent desks are
faint, occupied ones are inked, and the active one carries a red seal. Hover a numeral to see the title you gave
that workspace (§3.6).

Plug in an HDMI monitor and the odd workspaces stay on the laptop while the even ones (2, 4, 6, 8, 10) move to
`HDMI-A-1` (`UserConfigs/WorkspaceMonitors.conf`).

### 3.2 The special workspace (scratchpad drawer)

| Key | Action |
|---|---|
| `SUPER+SHIFT+U` | Put the active window in the drawer |
| `SUPER+U` | Slide the drawer down / back up (`togglespecialworkspace`) |
| `SUPER+SHIFT+1…0` (while it's open) | Take a window back out to a normal workspace |
| `SUPER+SHIFT+Return` | **Drop-down terminal**: its own kitty in a separate `special:scratchpad`. Same key hides it again |

The drawer drops from the top (`slidevert`, 500 ms). It scales to 80 % and dims the desk behind it with a 35 %
blurred scrim.

### 3.3 Overview

| Key / gesture | Action |
|---|---|
| `SUPER+A` | JaKooLit's Quickshell overview (`OverviewToggle.sh` → `qs ipc -c overview call overview toggle`) |
| 4-finger swipe **up** | Same overview |

### 3.4 Touchpad gestures (from `configs/SystemSettings.conf`)

| Gesture | Action |
|---|---|
| 3-finger swipe left/right | Switch workspace (inverted, swiping past the last one creates a new desk) |
| 3-finger swipe up / down | Zoom in ×1.5 / zoom out ÷1.5 (screen magnifier) |
| 4-finger swipe up | Overview |
| 4-finger swipe down | Toggle floating on the active window |

Also: tap-to-click, natural scrolling, and the touchpad turns off while you type. The touchpad on/off key
(`XF86TouchpadToggle`) runs `TouchPad.sh`.

### 3.5 Zoom / magnifier

| Key | Action |
|---|---|
| `SUPER+ALT` + wheel down | Zoom in ×2 around the cursor |
| `SUPER+ALT` + wheel up | Zoom out ÷2 |
| reset | `hyprctl keyword cursor:zoom_factor 1` |

### 3.6 Workspace titles (the card)

Each of the ten workspaces can carry a **title** and a one-line **note**. When you switch to a workspace (keys,
bar click, wheel, gestures — anything that changes the focused workspace) a paper card floats in under the bar for
about 2.6 s: the numeral seal (一 … 十), the title, `WORKSPACE n`, and the note. It never takes a click.

```
overworld ws                         # list all ten
overworld ws 3 "Coding" "MCP server + course labs"
overworld ws 3 "Coding"              # title only, keeps the existing note
overworld ws 3 --note "new note"     # note only
overworld ws 3 --clear
overworld ws edit                    # open workspaces.json in $EDITOR (nvim)
overworld ws show 3                  # flash the card now
overworld ws help                    # every ws / ws auto command, file paths and examples
```

Titles and notes grow up to about 50 characters before the title is cut with "…" and the note wraps (3 lines max).
Everything lives in `~/.config/overworld/workspaces.json` and is picked up live, no reload:

```json
{ "3": { "title": "Coding", "note": "MCP server + course labs" },
  "5": "Music" }
```

Card settings go in `~/.config/overworld/config.json`:

```json
"workspace_card": { "enabled": true, "duration": 2600, "position": "top", "show_untitled": true }
```

`position` is `"top"` (under the bar), `"center"` or `"bottom"` (above the OSD). With `show_untitled: false` the
card only appears on workspaces that have a title.

**Let Claude label them.** `overworld ws auto on` starts a small watcher inside the shell
(`scripts/ws-autolabel.py`). It listens to Hyprland's window events, waits until things settle (20 s without a
window opening/closing/moving), and also looks once a minute. For every workspace that is not pinned it will

- **label** it: windows but **no title** → Claude writes a title and note (a note you wrote is kept);
- **check** it: the windows changed → Claude is shown the current title + note and the windows, and rewrites both if
  they clearly no longer match — your own titles too. It checks when the set of apps changes, or when only window
  titles changed and the last check is older than `recheck` (10 min). A title is left alone for `cooldown` (10 min)
  after it was set, by you or by Claude. A terminal's window title is often just `hermes` or `zsh`, so for terminals it
  also sends what runs inside (program + folder, and the title of the Hermes session in that terminal, read from
  `~/.hermes/state.db`); music/video tabs and bare terminals count as neutral;
- **reset** it: the workspace stayed **empty** for `reset_after` (10 min) → its title and note are removed.

`overworld ws 3 --pin` protects workspace 3 from all three (`--unpin` undoes it); `manage_manual: false` protects
every title you set yourself (the old behaviour). Every rewrite and reset is logged with the old text, so nothing is
lost. Claude's labels are marked `(auto)` in `overworld ws` and `WORKSPACE n · AUTO` on the card; setting a title by
hand turns an auto label into yours.

```
overworld ws auto on | off | status
overworld ws auto now          # one pass now: label untitled ones, check every titled one (no waiting)
overworld ws auto now 3        # relabel workspace 3 now, even if you titled it yourself
overworld ws 3 --auto          # drop your title on 3 and let Claude label it
overworld ws 3 --pin           # never rewrite or reset 3 (--unpin to undo)
overworld ws auto clear        # remove all of Claude's labels (yours stay)
overworld ws auto log          # what it did and why (~/.cache/overworld/ws-auto.log)
```

It runs `claude -p --model haiku` with no tools, MCP servers or settings, so each label is one short request (~5 s)
counted against your **Claude plan**: `ANTHROPIC_API_KEY` is removed from its environment so it never bills an API
key. What is sent: each window's app class and title, plus the other workspaces' titles (so names stay distinct).
Tune it under `config.json → "workspace_auto"`:

```json
"workspace_auto": { "enabled": true, "model": "haiku", "send_titles": true,
                    "settle": 20, "cooldown": 600, "recheck": 600, "reset_after": 600,
                    "manage_manual": true, "max_per_hour": 20 }
```

`send_titles: false` sends app classes only (more private, vaguer labels, and title-only changes are no longer
noticed); `reset_after: 0` never resets; `max_per_hour` caps the calls. The empty/check timers live in
`~/.cache/overworld/ws-auto-state.json`, so a shell reload does not restart them. The watcher lives and dies with the
shell (only one runs at a time), so it only runs while the theme is on.

---

## 4. The Overworld shell (Quickshell)

### 4.1 Keys

| Key | Surface |
|---|---|
| `SUPER+Space` / `SUPER+D` | **Launcher** 药柜 (medicine cabinet) |
| `SUPER+N` | **Network** 网 (Wi-Fi list, connect/forget, VPN, airplane) |
| `SUPER+Escape` | **Power** (lock 锁 · logout 出 · suspend 眠 · reboot 启 · shutdown 关) |
| `SUPER+W` | **Wallpaper picker** (handscroll of thumbnails) |
| `SUPER+SHIFT+W` | Next wallpaper |
| `CTRL+ALT+W` | Random wallpaper |
| `SUPER+I` or `SUPER+SHIFT+N` | **Notification centre** 报 |
| `SUPER+SHIFT+I` | Do not disturb on/off |
| `SUPER+T` | Light ↔ dark mode |
| `SUPER+G` | Desktop **widgets** on/off |
| `SUPER+B` | **Brew timer** start / pause |
| `SUPER+SHIFT+B` | Brew timer: set the brew / rest time (dialog) |
| `SUPER+SHIFT+G` | **Game mode** on/off |
| `SUPER+ALT+R` | **Repair** the shell |
| `SUPER+E` | superfile (`spf`) in a floating kitty sheet |
| Volume / brightness keys | The Overworld ink-slip OSD shows on top of JaKooLit's own handlers |

Every overlay closes with **Esc**, and keyboard focus goes back to your window. Only one overlay is open at a time.

### 4.2 Launcher tricks

- **Fuzzy search**: type part of an app name. Prefix matches win over word-start matches, which win over scattered letters.
- **Categories**: 全 All · 网 Internet · 工 Development · 画 Media · 书 Office · 器 System · 设 Settings.
- **`=` calculator**: `=2^10/3` or `=sqrt(2)*pi`. Enter copies the result to the clipboard.
- **`>` run**: `>pavucontrol` runs the rest through `sh -c`, detached.
- Open it pre-typed from anywhere: `qs -c overworld ipc call launcher search "=12*7"`.

JaKooLit's rofi helpers are still bound: `SUPER+S` web search · `SUPER+ALT+C` rofi calculator · `SUPER+CTRL+S`
window switcher.

### 4.3 Power menu

The letters **L O S R P** jump to Lock, lOgout, Suspend, Reboot and Power off. Logout, Reboot and Shutdown need a
**second** Enter or click on the 印 Confirm seal, so you can't bump them by accident.

### 4.4 Widgets (`SUPER+G`)

Eight paper cards: Weather · Calendar · Music (MPRIS) · SysInfo · Brew timer · Cava · Herb of the day · Quote.

- **Move a card**: drag it by its title bar (the cursor turns into a hand). The position is saved.
- **Put one card back**: double-click its title bar.
- **Reset every card**: `qs -c overworld ipc call widgets layout`.
- Herb card: left-click for the next herb, right-click for the previous. Quote card: click for a new quote.
- Visibility persists across logins (`~/.config/overworld/widgets-visible`).

### 4.5 Notifications

Paper-note popups appear top-right. Hover pauses the timer, and clicking the body runs its default action.
Critical notes stay until dismissed and get a vermilion 印 stamp. The centre (`SUPER+I`) groups notes by app and
has DND and "clear all". DND also silences the notification sounds.

### 4.6 Light/dark, game mode, repair

- **`SUPER+T`** (`overworld toggle`) switches the colours, the wallpaper (remembered per mode), the hyprlock palette and the kitty colours. It runs `hyprctl reload`, so any temporary `hyprctl keyword` tweak is lost.
- **`SUPER+SHIFT+G`** (`overworld gamemode`) turns off animations, blur, shadows, gaps, rounding, opacity and dimming, sets the border to 1 px and hides the widgets. Press it again to restore everything, including whether the widgets were showing. Use this one, **not** JaKooLit's `GameMode.sh`, which would tear the theme down.
- **`SUPER+ALT+R`** (`overworld repair`) stops waybar/mako again, restarts the shell and the overview, re-applies the wallpaper and reloads Hyprland.

### 4.7 The `overworld` CLI

```
overworld on | off | status
overworld light | dark | toggle
overworld wallpaper next | prev | random | current | pick | <path>
overworld reload            # hyprctl reload + restart the shell
overworld gamemode [on|off|toggle]
overworld repair
overworld ws [list] | ws <1-10> "Title" ["note"] | ws <n> --note "…" | --clear | --auto | --pin | --unpin | ws edit | ws show [n]
overworld ws auto on | off | status | now [n] | clear | log     # §3.6
overworld ws help                                                # full ws reference
```

### 4.8 Full IPC list (`qs -c overworld ipc call <target> <fn>`)

| Target | Functions |
|---|---|
| `launcher` | `toggle` `open` `close` `search "<q>"` |
| `network` | `toggle` `open` `close` `rescan` `expand "<ssid>"` `connect "<ssid>"` (saved profiles only) |
| `power` | `toggle` `open` `close` |
| `wallpapers` | `toggle` `open` `close` `next` `prev` `apply` `select <index>` |
| `notifications` | `toggle` `open` `close` `dnd` `clear` `status` |
| `theme` | `toggle` `set light\|dark` `get` |
| `osd` | `volume` `brightness` |
| `workspace` | `reveal <1-10>` `current` `hide` `title <n>` (the workspace card, §3.6) |
| `widgets` | `toggle` `reveal` `hide` `layout` `demo on\|off` `status` (use `reveal`, because `show` collides with `qs ipc show`) |
| `brew` | `toggle` `start <dur>` `startWith <brew> <rest>` `pause` `reset` `add <dur>` `open` `sound brew\|rest` `status` `settings` |
| `shell` | `closeAll` `status` |

`qs -c overworld ipc show` lists everything the running shell exposes.

---

## 5. JaKooLit extras worth knowing

### 5.1 Screenshots (saved to `~/Pictures/Screenshots` unless noted)

| Key | What |
|---|---|
| `Print` | Select an area → opens in **swappy** to annotate (your override in `UserKeybinds.conf`; not auto-saved, save from swappy) |
| `SUPER+SHIFT+S` | Area → swappy (`ScreenShot.sh --swappy`) |
| `SHIFT+ALT+S` | Region with hyprshot |
| `ALT+Print` / `ALT+F6` | Active window only |
| `SUPER+F6` | Whole screen now |
| `SUPER+SHIFT+F6` | Area |
| `SUPER+CTRL+F6` | Whole screen in 5 s |
| `SUPER+ALT+F6` / `SUPER+CTRL+SHIFT+Print` | Whole screen in 10 s |

### 5.2 Utilities

| Key | What |
|---|---|
| `SUPER+ALT+V` | Clipboard history (cliphist). Enter re-copies, `CTRL+Del` deletes an entry, `ALT+Del` wipes all |
| `SUPER+ALT+E` | Emoji picker |
| `SUPER+ALT+C` | Rofi calculator |
| `SUPER+S` | Web search (rofi → Google) |
| `SUPER+C` | SSH session menu (hosts from your ssh config) |
| `SUPER+Z` | Default browser (was `SUPER+B`) |
| `SUPER+SHIFT+M` | Online radio / music menu (RofiBeats) |
| `SUPER+CTRL+N` | Night light: hyprsunset at 4500 K, toggle (was `SUPER+N`) |
| `SUPER+ALT+O` | Toggle "less blur" ↔ "normal blur" (a temporary `hyprctl keyword`, see note) |
| `ALT+SHIFT` | Switch keyboard layout **us → ru → kz** (xkb `grp:alt_shift:toggle`, plus JaKooLit's `KeyboardLayout.sh` on `ALT+SHIFT_L` and a per-window switcher on `SHIFT+ALT_L`) |
| `SUPER+H` | KooL cheat sheet (yad). **Stale while themed**: it still lists `SUPER+B` browser, `SUPER+D` rofi, `SUPER+E` Thunar, `SUPER+T` theme switcher |
| `SUPER+SHIFT+K` | Searchable keybind list (rofi). Parses JaKooLit's files only, so it **misses the Overworld binds** and shows the ones they replaced. Use this guide or `hyprctl binds` |
| `SUPER+SHIFT+E` | KooL Quick Settings (edit user configs, nwg-displays, nwg-look, qt6ct…) ⚠ some items |
| `SUPER+SHIFT+O` | Change oh-my-zsh theme |
| `CTRL+ALT+P` | wlogout (JaKooLit's power screen; the Overworld one is `SUPER+Escape`) |
| `CTRL+ALT+L` | Lock (see §6.7) |
| `CTRL+ALT+Delete` | **Exits Hyprland immediately, with no confirmation** (`Logout.sh`) |

Note on `SUPER+ALT+O`: the blur script checks for the stock 2 passes. The theme uses 3, so the first press sets
"normal" (size 5, passes 2). Either way, `hyprctl reload` or `SUPER+T` brings back the theme's blur.

### 5.3 Media and Fn keys

| Key | What |
|---|---|
| Volume up/down/mute | `Volume.sh` + Overworld OSD (`ALT` + volume = fine steps) |
| Mic mute | Toggle mic |
| Play/Pause/Next/Prev/Stop | `MediaCtrl.sh` (playerctl) |
| Brightness up/down | `Brightness.sh` + OSD. **Needs the kernel-parameter fix** (§8) |
| Keyboard backlight up/down | `BrightnessKbd.sh` |
| Sleep key | `systemctl suspend` |
| Rfkill key | Airplane mode |
| `XF86Launch1/3/4` | Bound to ASUS tools (`rog-control-center`, `asusctl`). Leftovers that probably do nothing on this Acer |

### 5.4 ⚠ JaKooLit keys that fight the theme

The theme already **unbound** the worst ones: `SUPER+W` wallpaper menu, `SUPER+SHIFT+W` effects, `SUPER+T`
ThemeChanger, `SUPER+SHIFT+G` GameMode.sh, `SUPER+ALT+R` Refresh.sh, `CTRL+ALT+W` WallpaperRandom.sh,
`SUPER+CTRL+B` / `SUPER+ALT+B` waybar style/layout menus, and `SUPER+SHIFT+B` rainbow borders. These are
**still bound** and can still damage the theme:

| Key | Why it hurts | Use instead |
|---|---|---|
| `SUPER+SHIFT+A` animations menu | Overwrites `UserAnimations.conf` and runs `RefreshNoWaybar.sh`, which **kills `qs`** (bar and widgets vanish) | Theme curves in `hypr/animations.conf`. Afterwards: `SUPER+ALT+R` |
| `SUPER+SHIFT+E` Quick Settings → rainbow borders / waybar toggles | Run `Refresh.sh`: restarts waybar, kills `qs` | `SUPER+ALT+R` afterwards. Editing config files from the menu is fine |
| `SUPER+CTRL+K` kitty theme selector | Rewrites kitty's theme include and calls wallust (Overworld colours are included later in `kitty.conf`, but don't push it) | `SUPER+T` switches kitty with the mode |
| `SUPER+CTRL+G` ghostty themes | Wallust-based, same story | n/a |
| `SUPER+CTRL+ALT+B` toggle waybar | Waybar is stopped while themed. If it shows up, that's the bug | `SUPER+ALT+R` |
| `SUPER+ALT+O` blur toggle | Temporary, harmless | `SUPER+T` / reload restores |
| Running `WallpaperSelect.sh`, `WallustSwww.sh`, `WallpaperRandom.sh`, `ThemeChanger.sh`, `DarkLight.sh`, `GameMode.sh`, `Refresh.sh` by hand | Reset the wallpaper, run wallust, restart waybar | `SUPER+W`, `CTRL+ALT+W`, `SUPER+T`, `SUPER+SHIFT+G`, `SUPER+ALT+R` |

`SUPER+CTRL+R` / `SUPER+CTRL+SHIFT+R` (rofi theme selectors) only restyle rofi menus, which is harmless.

---

## 6. Power-user corner

### 6.1 `hyprctl` cheat sheet

Run `source ~/Projects/overworld-hyprland/scripts/dev-env.sh` first if a shell (e.g. one started by the gateway) can't reach Hyprland.

| Command | What |
|---|---|
| `hyprctl clients` | Every window: class, title, workspace, floating, size |
| `hyprctl activewindow` | The focused window. **Use this to find a `class` for rules** |
| `hyprctl activeworkspace` / `workspaces` / `monitors` | Where am I, what exists, screen info |
| `hyprctl binds` (`-j` for JSON) | Live keybinds with descriptions, the authoritative list |
| `hyprctl dispatch <dispatcher> <arg>` | Do any action: `hyprctl dispatch pin`, `… centerwindow`, `… workspace 4`, `… togglefloating` |
| `hyprctl keyword <option> <value>` | Temporary change: `hyprctl keyword general:gaps_out 4`. Lost on reload / `SUPER+T` |
| `hyprctl getoption <option>` | Read a value: `hyprctl getoption decoration:active_opacity` |
| `hyprctl reload` | Re-read all config files |
| `hyprctl configerrors` | Show config errors after you edit something (empty = good) |
| `hyprctl switchxkblayout <kbd> next` | Change keyboard layout |
| `hyprctl dispatch exit` | Log out |

Find free key combos before you bind one:

```bash
hyprctl binds -j | jq -r '.[] | "\(.modmask) \(.key)  \(.description)"' | sort
# modmask bits: SHIFT=1 CAPS=2 CTRL=4 ALT=8 SUPER=64  (SUPER+SHIFT = 65, SUPER+CTRL = 68, SUPER+ALT = 72)
```

### 6.2 Your own binds and window rules

- **Binds** go in `~/.config/hypr/UserConfigs/UserKeybinds.conf`.
- **Window rules** go in `~/.config/hypr/UserConfigs/WindowRules.conf` (empty, made for you).

The theme never edits these files, so your additions survive `overworld on/off`. One catch: the theme layer is
sourced **after** them. If you bind a key the theme also uses, the theme wins while it's on. These were free at
the time of writing: `SUPER+X`, `SUPER+Y`, `SUPER+O`, `SUPER+V`.

```ini
# UserKeybinds.conf: bindd = MODS, key, description, dispatcher, arg
bindd = SUPER, Y, Pin floating window, pin
bindd = SUPER, X, Centre floating window, centerwindow
bindd = SUPER, O, Obsidian, exec, obsidian
bindd = SUPER SHIFT, X, Float + centre + 60%, exec, hyprctl --batch "dispatch setfloating; dispatch resizeactive exact 60% 60%; dispatch centerwindow"
# replace a JaKooLit bind: unbind first, with the key spelled exactly as in configs/Keybinds.conf
unbind = SUPER, C
bindd = SUPER, C, Calculator app, exec, gnome-calculator
```

```ini
# WindowRules.conf: Hyprland 0.56 syntax  windowrule = match:<prop> <regex>, <effect> <value>, ...
windowrule = match:class ^(org.gnome.Calculator)$, float on, center on, size 420 640
windowrule = match:class ^(Spotify|spotify)$, workspace 9 silent
windowrule = match:class ^(obsidian)$, opacity 1.0 1.0
windowrule = match:title ^(Open File)$, float on, center on, size 60% 70%
windowrule = match:class ^(steam_app_.*)$, fullscreen on, no_blur on
```

After editing, run `hyprctl reload && hyprctl configerrors`. The theme's own rules (`hypr/rules.conf`) are sourced
later and win on conflicts (superfile, pavucontrol, video players, PiP).

### 6.3 Monitor and scaling

`~/.config/hypr/monitors.conf` has `monitor=,preferred,auto,1` (eDP-1 runs at 1920×1080@165, scale 1).

```bash
hyprctl keyword monitor eDP-1,1920x1080@165,0x0,1.25   # try 125 % scaling (temporary)
hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1       # 60 Hz to save battery (temporary)
```

To keep a setting, put the same line in `monitors.conf`, or use Quick Settings → *Configure Monitors
(nwg-displays)*. XWayland apps use `force_zero_scaling`, so they stay sharp but may look small at fractional scales.

### 6.4 Animations (ink on wet paper)

The theme's three curves (`hypr/animations.conf`): no bounce, no overshoot.

| Curve | Bezier | Used for |
|---|---|---|
| `ink` | 0.22, 1, 0.36, 1 (ease-out quint) | Windows opening (700 ms popin 85 %), layers appearing |
| `brush` | 0.65, 0, 0.35, 1 (ease-in-out cubic) | Window close (600 ms), all fades (500 ms) |
| `drift` | 0.33, 1, 0.68, 1 (ease-out cubic) | Window moves (600 ms), **workspaces 400 ms slide**, scratchpad 500 ms slidevert |

Borders don't animate (no rotating gradient). Try a value temporarily, for example
`hyprctl keyword animation workspaces,1,2,drift,slide`. Turn everything off with
`hyprctl keyword animations:enabled 0`, or press game mode.

### 6.5 Opacity, blur and dim

| Knob | Theme value | Notes |
|---|---|---|
| `decoration:active_opacity` | 0.94 | Thin paper: the blurred wallpaper peeks through |
| `decoration:inactive_opacity` | 0.88 | |
| `decoration:dim_inactive` / `dim_strength` | on / 0.06 | A whisper of ink wash |
| `decoration:dim_special` | 0.35 | Scrim behind the scratchpad |
| `decoration:blur` | size 6, passes 3, vibrancy 0.17 | Also behind popups and the special workspace |
| kitty `background_opacity` | 0.88 | Stacks with the compositor's opacity |
| `general` | border 2, gaps 6/12, rounding 8 | |
| Video players, fullscreen | 1.0, no blur | Picture stays crisp |

Quick fixes: `SUPER+CTRL+O` makes one window opaque, and `hyprctl keyword decoration:inactive_opacity 1` is a
temporary global change. To make a change permanent, use a window rule (§6.2).

### 6.6 hypridle (theme on)

| After | Happens |
|---|---|
| 5 min | Dim the backlight to 30 % (a no-op until the backlight fix, §8) |
| 10 min | Lock (`loginctl lock-session` → Overworld hyprlock) |
| 15 min | Screen off; any input wakes it |
| Before sleep | Lock |

Video players and browsers can inhibit idle. With `overworld off`, the stock JaKooLit hypridle comes back.

### 6.7 hyprlock

`CTRL+ALT+L` → `loginctl lock-session` → hypridle's `lock_cmd` → `hyprlock -c <repo>/hypr/hyprlock.conf`.
`~/.config/hypr/hyprlock.conf` is a symlink to the theme's file while the theme is on. The colours follow light/dark
mode, and a 時辰 (Chinese hour) label updates every minute. Type your password and press Enter.

---

## 7. Daily rhythm (a suggested routine)

1. `SUPER+Return` for a terminal, `SUPER+Space` for anything else.
2. Desk 1 for work, 2 for the browser, 3 and 5 for master-layout coding, 9 for music. Move things with `SUPER+SHIFT+n`.
3. Put a notes app or terminal in the drawer: `SUPER+SHIFT+U`, then call it with `SUPER+U`.
4. `SUPER+SHIFT+B` to set the brew / rest lengths and start a focus session, `SUPER+SHIFT+I` to silence notes while it runs.
5. `SUPER+T` at sunset, `SUPER+CTRL+N` for warm night light.
6. Before gaming: `SUPER+SHIFT+G`. After: `SUPER+SHIFT+G` again.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| Waybar came back / two bars / bar gone / widgets gone | `overworld repair` (`SUPER+ALT+R`). Usually a JaKooLit script ran `Refresh.sh` (§5.4) |
| `SUPER+G` (or another theme key) does nothing | The shell died or was killed: `SUPER+ALT+R`. Check that the bind exists: `hyprctl binds \| grep -i widgets` |
| Wallpaper reset to a JaKooLit one | `SUPER+ALT+R`, or pick one with `SUPER+W` |
| Widget cards scattered | `qs -c overworld ipc call widgets layout` (or double-click each title bar) |
| A theme tweak "didn't stick" | `hyprctl keyword` changes are temporary. `SUPER+T` and reloads wipe them. Put it in a config file |
| Text colours wrong in a TUI (btop, nvim…) after `SUPER+T` | Restart that program. Running TUIs keep the old palette |
| Everything looks stock JaKooLit | Theme is off: `overworld on`. Check with `overworld status` |
| Want the stock desktop back | `overworld off` (no logout needed) |
| Game mode stuck on | `overworld gamemode off` |
| Brightness keys / OSD say "no backlight device" | Remove `acpi_backlight=vendor`: see `docs/SUDO-STEPS.md` → *Screen brightness* (one `grubby` command + reboot) |
| Edited a config and something broke | `hyprctl configerrors`, fix, `hyprctl reload` |
| Pressed `SUPER+Tab` and lost your desk | That bind also switches workspace (§2.5). Use `SUPER+CTRL+Tab` for group tabs |
| Keyboard layout skips one (us → kz) | Alt+Shift is handled by xkb **and** JaKooLit's `KeyboardLayout.sh`. If it double-steps, remove one of them (e.g. `kb_options` in `hyprland.conf`) |
| A floating window went off-screen | Focus it (`SUPER+CTRL+S`) and run `hyprctl dispatch centerwindow`, or press `SUPER+SHIFT+Space` twice |

Further reading in this repo: `docs/KEYBINDS.md` (what each theme key replaced) · `docs/QUICKSHELL.md` (shell
internals) · `docs/WIDGETS.md` (cards) · `docs/INSTALL.md` (install/uninstall) · `docs/SUDO-STEPS.md` (root-only fixes).
