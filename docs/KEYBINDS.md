# Overworld Hyprland — keybinds

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (the stock desktop returns in about 5 s, no logout); `overworld status` shows which state is active.
> Every bind in this file exists only while the theme is on; there is no keybind for on/off itself (use the CLI). How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

Active only while the theme is on (`overworld on`); `hypr/keybinds.conf` is sourced from `hypr/on.conf`.
`overworld off` + `hyprctl reload` brings every JaKooLit bind back untouched.

## Overworld binds

| Key | Action | Command | Replaces (JaKooLit) |
|---|---|---|---|
| `SUPER + Space` | Launcher — medicine cabinet | `qs -c overworld ipc call launcher toggle` | `togglefloating` (moved to `SUPER+SHIFT+Space`) |
| `SUPER + D` | Launcher — medicine cabinet (alias) | `qs -c overworld ipc call launcher toggle` | rofi `drun` launcher |
| `SUPER + N` | Network panel | `qs -c overworld ipc call network toggle` | `Hyprsunset.sh toggle` (moved to `SUPER+CTRL+N`) |
| `SUPER + Escape` | Power menu | `qs -c overworld ipc call power toggle` | — (was unbound) |
| `SUPER + W` | Wallpaper picker | `qs -c overworld ipc call wallpapers toggle` | `WallpaperSelect.sh` (rofi wallpaper menu) |
| `SUPER + SHIFT + W` | Next wallpaper (current mode) | `overworld wallpaper next` | `WallpaperEffects.sh` |
| `SUPER + T` | Toggle light / dark mode | `overworld toggle` | `ThemeChanger.sh` (wallust theme switcher) |
| `SUPER + G` | Toggle desktop widgets | `qs -c overworld ipc call widgets toggle` | `togglegroup` (moved to `SUPER+ALT+G`) |
| `SUPER + I` | Notification centre | `qs -c overworld ipc call notifications toggle` | `layoutmsg addmaster` (moved to `SUPER+ALT+I`) |
| `SUPER + SHIFT + N` | Notification centre (alias) | `qs -c overworld ipc call notifications toggle` | `swaync-client -t -sw` (swaync is stopped while on) |
| `SUPER + SHIFT + I` | Do not disturb toggle | `qs -c overworld ipc call notifications dnd` | `layoutmsg togglesplit` (moved to `SUPER+CTRL+I`) |
| `SUPER + E` | superfile in kitty | `kitty --class spf -e spf` | `LaunchFileManager.sh` (thunar) |
| `SUPER + B` | Brew timer start / pause | `qs -c overworld ipc call brew toggle` | `xdg-open https://` (browser, moved to `SUPER+Z`) |
| `SUPER + SHIFT + B` | Brew timer: set brew / rest time (dialog) | `qs -c overworld ipc call brew open` | `RainbowBorders-low-cpu.sh` (dropped: rainbow borders are off-theme) |
| `XF86AudioRaise/Lower/Mute` | Volume OSD (in addition to JaKooLit's `Volume.sh`) | `qs -c overworld ipc call osd volume` | — (additional bind, both fire) |
| `XF86MonBrightnessUp/Down` | Brightness OSD (in addition to `Brightness.sh`) | `qs -c overworld ipc call osd brightness` | — (additional bind, both fire) |

## Re-homed JaKooLit actions

| Key | Action | Command | Was |
|---|---|---|---|
| `SUPER + SHIFT + Space` | Float current window | `togglefloating` | `SUPER+Space` |
| `SUPER + CTRL + N` | Hyprsunset night-light toggle | `~/.config/hypr/scripts/Hyprsunset.sh toggle` | `SUPER+N` |
| `SUPER + ALT + G` | Toggle group | `togglegroup` | `SUPER+G` |
| `SUPER + ALT + I` | Add master (master layout) | `layoutmsg addmaster` | `SUPER+I` |
| `SUPER + CTRL + I` | Toggle split (dwindle) | `layoutmsg togglesplit` | `SUPER+SHIFT+I` |
| `SUPER + Z` | Open default browser | `xdg-open "https://"` | `SUPER+B` |

## Unchanged JaKooLit binds you will keep using

`SUPER+Return` kitty · `SUPER+Q` close window · `SUPER+SHIFT+Q` kill process · `SUPER+F` maximise · `SUPER+SHIFT+F` fullscreen ·
`SUPER+1…0` workspaces (`+SHIFT` move) · `SUPER+Tab` next workspace · `SUPER+U` special workspace · `SUPER+arrows` focus ·
`SUPER+CTRL+arrows` move · `SUPER+SHIFT+arrows` resize · `Print` area screenshot (swappy) · `SUPER+SHIFT+S` swappy ·
`ALT+SHIFT+S` hyprshot region · `SUPER+A` overview · `SUPER+H` cheat sheet · `SUPER+SHIFT+K` keybind search ·
`SUPER+ALT+V` clipboard · `SUPER+ALT+E` emoji · `SUPER+S` web search · `CTRL+ALT+L` lock (hyprlock) · `CTRL+ALT+P` wlogout ·
`CTRL+ALT+Delete` logout · `ALT+Shift` keyboard layout (us/ru/kz) · media keys (`MediaCtrl.sh`).

## Notes

- `unbind` in Hyprland matches the key string verbatim, so `hypr/keybinds.conf` uses the exact spellings from
  `configs/Keybinds.conf` (`SPACE`, `D`, `N` …). If JaKooLit renames a key, update both.
- The XF86 volume/brightness keys keep JaKooLit's scripts, which also send a `notify-send` — while the theme is on,
  that notification goes to the Overworld notification daemon, so you may see both the OSD and a note. The shell
  drops notifications whose hint is `x-canonical-private-synchronous:volume_notif` / `brightness_notif` (NotificationService, QA fix 4), so you only see the OSD.
- `SUPER+W` / `SUPER+SHIFT+W` choose from `assets/wallpapers/<mode>/`; the choice is remembered per mode in
  `~/.config/overworld/wallpaper-<mode>`.


## Added 2026-10-29 (user feedback)

| keys | action | replaces (JaKooLit) | why |
|---|---|---|---|
| SUPER+SHIFT+G | `overworld gamemode` — no animations/blur/shadows/gaps, opaque, widgets hidden; press again to restore the theme | `GameMode.sh` | its "off" half restored JaKooLit's wallpaper + wallust colours and ran `Refresh.sh` (`pkill qs && qs &`, restarts waybar/swaync) → waybar came back, SUPER+G died, wallpaper reset |
| SUPER+ALT+R | `overworld repair` — stop waybar/mako again, (re)start the shell + JaKooLit overview, re-apply the wallpaper | `Refresh.sh` | same teardown |
| CTRL+ALT+W | `overworld wallpaper random` | `WallpaperRandom.sh` | it set a non-theme wallpaper and ran wallust |
| SUPER+CTRL+B, SUPER+ALT+B | unbound while on | waybar style / layout menus | waybar is off while the theme is on |

Widgets: drag a card by its **title bar** to move it (saved in `~/.config/overworld/widget-positions.json`);
double-click a title bar to send that card back; `qs -c overworld ipc call widgets layout` resets all.
