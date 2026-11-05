# Overworld Hyprland — keybinds

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (what was there before comes back, Apothecary or the stock desktop, no logout); `overworld status` shows which state is active.
> Every bind in this file exists only while the theme is on; there is no keybind for on/off itself (use the CLI).

Active only while the theme is on; `hypr/keybinds.conf` is sourced from `hypr/on.conf`.
`overworld off` + `hyprctl reload` brings every JaKooLit bind back untouched.

`$qs` below stands for `qs -c overworld ipc call`. Check any key against the live config with `hyprctl binds | grep -i <key>`.

## Menus (the keys you knew from Apothecary)

| Key | Action | Command | Replaces (JaKooLit) |
|---|---|---|---|
| `SUPER + Space`, `SUPER + D` | Creative inventory (launcher) | `$qs launcher toggle` | `togglefloating` (moved), rofi launcher |
| `SUPER + N` | Multiplayer (network) | `$qs network toggle` | `Hyprsunset.sh` (moved) |
| `SUPER + Escape` | Game Menu (power) | `$qs power toggle` | was free |
| `SUPER + W` | Select World (wallpapers) | `$qs wallpapers toggle` | `WallpaperSelect.sh` |
| `SUPER + SHIFT + W` | Next wallpaper | `overworld wallpaper next` | `WallpaperEffects.sh` |
| `CTRL + ALT + W` | Random wallpaper | `overworld wallpaper random` | `WallpaperRandom.sh` (ran wallust and Refresh) |
| `SUPER + T` | Day / Night | `overworld toggle` | `ThemeChanger.sh` |
| `SUPER + G` | Desktop widgets on/off | `$qs widgets toggle` | `togglegroup` (moved) |
| `SUPER + I`, `SUPER + SHIFT + N` | Chat history (notification centre) | `$qs notifications toggle` | `addmaster` (moved), swaync panel |
| `SUPER + SHIFT + I` | Peaceful (do not disturb) | `$qs notifications dnd` | `togglesplit` (moved) |
| `SUPER + B` | Brewing stand: start/pause | `$qs brew toggle` | default browser (moved) |
| `SUPER + SHIFT + B` | Brewing stand: set brew and rest time | `$qs brew open` | `RainbowBorders-low-cpu.sh` |
| `SUPER + E` | superfile | `kitty --class spf -e spf` | `LaunchFileManager.sh` |

## The game

| Key | Action | Command | Replaces (JaKooLit) |
|---|---|---|---|
| `SUPER + Q` | Mine the window: cracks, particles, break sound, then it closes | `overworld kill` | `killactive` |
| `SUPER + SHIFT + T` | Chat console (T is the game's chat key) | `$qs chat open` | was free |
| `SUPER + /` | Chat console with `/` typed | `$qs chat command "/"` | was free |
| `SUPER + F1` | Hide or show the HUD, as F1 does in the game | `$qs hud toggle` | was free |
| `SUPER + F2` | Screenshot of everything, as F2 does in the game | `screenshot.sh screen` | was free |
| `SUPER + F3` | F3 debug screen | `$qs world f3 toggle` | was free |
| `SUPER + SHIFT + F3` | F3 debug screen with the frame graph | `$qs world f3graph toggle` | was free |
| `SUPER + F4` | Gamemode switcher | `$qs gamemode switcher` | was free |
| `SUPER + L` | Advancements (L is the game's key) | `$qs advancements toggle` | was free |
| `SUPER + SHIFT + L` | Statistics | `$qs stats toggle` | was free |
| `SUPER + O` | Options | `$qs options toggle` | was free |
| `SUPER + SHIFT + G` | Adventure mode on/off (performance) | `overworld gamemode toggle` | `GameMode.sh` (its "off" half ran Refresh.sh and restored JaKooLit's wallpaper) |
| `SUPER + ALT + R` | Repair: stop waybar/mako, restart the shell, re-apply the wallpaper | `overworld repair` | `Refresh.sh` (`pkill qs`, restarted waybar/swaync) |

## Screenshots

All of them go through `scripts/interact/screenshot.sh`: same folder and names as JaKooLit's script, copied to the clipboard,
`Saved screenshot as …` in chat, item-pickup pop.

| Key | Action | Replaces |
|---|---|---|
| `Print` | Select an area | your `grim \| swappy` bind in UserKeybinds.conf |
| `SHIFT + Print`, `SUPER + F2` | Everything | was free |
| `ALT + Print`, `ALT + F6` | The active window | `ScreenShot.sh --active` |
| `SUPER + F6` / `SUPER + SHIFT + F6` | Everything / select an area (JaKooLit's laptop binds) | `ScreenShot.sh --now` / `--area` |
| `SUPER + CTRL + F6` / `SUPER + ALT + F6` | Everything after 5 s / 10 s | `ScreenShot.sh --in5` / `--in10` |
| `SUPER + SHIFT + S` | Select an area and annotate it in swappy | `ScreenShot.sh --swappy` |

Unbound while on, so that nothing bypasses the wrapper: `SUPER + Print`, `SUPER + SHIFT + Print`, `SUPER + CTRL + Print`,
`SUPER + CTRL + SHIFT + Print` (timers, already unbound by your UserKeybinds.conf), `ALT + SHIFT + S` (hyprshot).

## OSD

| Key | Action | Command |
|---|---|---|
| `XF86AudioRaiseVolume/LowerVolume/Mute` | "Master Volume" Options slider, in addition to `Volume.sh` | `$qs osd volume` |
| `XF86MonBrightnessUp/Down` | "Brightness" Options slider, in addition to `Brightness.sh` | `$qs osd brightness` |

## Re-homed JaKooLit actions

| Key | Action | Command | Was |
|---|---|---|---|
| `SUPER + SHIFT + Space` | Float current window | `togglefloating` | `SUPER + Space` |
| `SUPER + CTRL + N` | Hyprsunset night light | `Hyprsunset.sh toggle` | `SUPER + N` |
| `SUPER + ALT + G` | Toggle group | `togglegroup` | `SUPER + G` |
| `SUPER + ALT + I` | Add master (master layout) | `layoutmsg addmaster` | `SUPER + I` |
| `SUPER + CTRL + I` | Toggle split (dwindle) | `layoutmsg togglesplit` | `SUPER + SHIFT + I` |
| `SUPER + Z` | Default browser | `xdg-open "https://"` | `SUPER + B` |

Not re-homed while on, because waybar is off or the look does not fit: `SUPER + CTRL + B` (WaybarStyles), `SUPER + ALT + B` (WaybarLayout),
`SUPER + CTRL + ALT + B` (waybar on/off), rainbow borders.

## Unchanged JaKooLit binds you will keep using

`SUPER+Return` kitty · `SUPER+SHIFT+Q` kill process (hard, no mining) · `SUPER+F` maximise · `SUPER+SHIFT+F` fullscreen ·
`SUPER+1…0` workspaces (`+SHIFT` move, `+CTRL` move silently) · `SUPER+Tab` next workspace · `SUPER+U` special workspace · `SUPER+arrows` focus ·
`SUPER+CTRL+arrows` move · `SUPER+SHIFT+arrows` resize · `SUPER+A` overview · `SUPER+H` cheat sheet · `SUPER+SHIFT+K` keybind search ·
`SUPER+ALT+V` clipboard · `SUPER+ALT+E` emoji · `SUPER+S` web search · `CTRL+ALT+L` lock (the title screen) · `CTRL+ALT+P` wlogout (themed) ·
`CTRL+ALT+Delete` logout · `ALT+Shift` keyboard layout (us/ru/kz) · media keys (`MediaCtrl.sh`).

## Notes

- `unbind` in Hyprland matches the key string verbatim, so `hypr/keybinds.conf` uses the exact spellings from
  `configs/Keybinds.conf` (`SPACE`, `D`, `N` …). If JaKooLit renames a key, update both.
- `hypr/test/check-config.sh` checks every Overworld key against `configs/Keybinds.conf` and `UserConfigs/UserKeybinds.conf`:
  each one is either free or unbound first, and none is bound twice.
- The XF86 volume/brightness keys keep JaKooLit's scripts, which also send a `notify-send`. The shell drops notifications
  whose hint is `x-canonical-private-synchronous:volume_notif` / `brightness_notif`, so you only see the slider.
- `SUPER+W` / `SUPER+SHIFT+W` choose from `assets/wallpapers/<mode>/`; the choice is remembered per mode in
  `~/.config/overworld/wallpaper-<mode>`.
- Widgets: drag a card by its **title bar** to move it (saved in `~/.config/overworld/widget-positions.json`);
  double-click a title bar to send that card back; `qs -c overworld ipc call widgets layout` resets all.
