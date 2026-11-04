# Overworld Hyprland — install, use, remove

Owner: hyprland-engineer. Overworld is a **theme system** you switch on and off (`overworld on` / `overworld off`):
a **layer** over the JaKooLit Fedora-Hyprland dotfiles: nothing under
`~/.config/hypr/configs`, `UserConfigs`, `~/.config/waybar` or `~/.config/swaync` is edited. Everything lives in this
repo and is linked in. It coexists with Apothecary Hyprland: both stay installed, only one is on.

## 1. Install (no sudo, theme stays off)

```
cd ~/Projects/overworld-hyprland
scripts/fetch-minecraft-assets.sh   # textures and sounds, from your ~/.minecraft or Mojang's servers (once; gitignored)
scripts/install.sh
```

What it does (idempotent, reversed exactly by `scripts/uninstall.sh`, never touches Apothecary's files):

| step | effect |
|---|---|
| hook | adds `source = ~/.config/hypr/overworld.conf # overworld` to `~/.config/hypr/hyprland.conf`, right after Apothecary's line if there is one, else at the end (a copy is kept as `hyprland.conf.pre-overworld`), and links `~/.config/hypr/overworld.conf → hypr/overworld.conf` |
| shell | `~/.config/quickshell/overworld → quickshell/` |
| CLI | `~/.local/bin/overworld → scripts/overworld` |
| state | `~/.config/overworld/`: `mode` (`light`), `active.conf → hypr/off.conf`, `colors.conf`, `hyprlock-vars.conf`, `kitty-colors.conf` (→ `tokens/out/<mode>/…`), `lock.png` (→ `assets/renders/lock-<day\|night>.png`), `repo → <repo root>`, `config.json` only if missing, never overwritten |
| lock pieces | `~/.cache/overworld/lock/`: the button sprite at GUI scale 3, the wordmark link (`hypr/scripts/lock-assets.sh`) |
| fonts | copies `assets/fonts/*.ttf` (Mojangles) to `~/.local/share/fonts/overworld/` if not there |
| apps | runs `apps/install.sh` (visually a no-op, see `docs/APPS.md`) |
| reload | `hyprctl reload`: with the theme off this changes nothing visible |

Existing real files at a link path are moved to `<file>.pre-overworld` (never overwritten).

## 2. On / off, and Apothecary

```
overworld on       # Hyprland layer + hyprlock + hypridle + the HUD shell
overworld off      # back to what was there before: Apothecary in its mode, or stock JaKooLit
overworld status   # enabled, mode, previous theme, game mode, day cycle, processes
```

Both themes are always sourced from `hyprland.conf`, each behind its own `active.conf`, and at most one of them points at its
`on.conf`.

`on` remembers what it replaced in `~/.config/overworld/previous-theme` (`apothecary dark`, or `stock`) and then:
- if Apothecary is on, switches it off through its files: removes `~/.config/apothecary/enabled`, points its `active.conf` at `off.conf`,
  stops `qs -c apothecary`, runs its `apps/apply-mode.sh off`. Going through `apothecary off` would start waybar and mako only to stop
  them again a second later;
- flips `~/.config/overworld/active.conf` to `hypr/on.conf`, re-links the mode files;
- moves `~/.config/hypr/hyprlock.conf` to `hyprlock.conf.pre-overworld` and links ours. JaKooLit's `LockScreen.sh` runs plain `hyprlock`,
  so the file itself must change. While Apothecary is on, that file is Apothecary's symlink, and it is kept as the symlink;
- one `hyprctl reload` swaps both layers at once;
- stops waybar/waybar-weather/swaync/mako if they run, starts `qs -c overworld` (log `~/.cache/overworld/qs.log`), restarts hypridle with
  `hypr/hypridle.conf`, sets the mode's wallpaper (the one on screen is remembered in `prev-wallpaper`), runs `apps/apply-mode.sh <mode>`.

`off` reverses all of it:
- previous theme Apothecary: `enabled` + `active.conf → on.conf` in its state dir, its hyprlock link back, `qs -c apothecary`, its hypridle,
  its wallpaper; `apps/apply-mode.sh off` hands the apps to Apothecary's own apply-mode in its mode. Waybar and mako are never started;
- previous theme stock: waybar, mako, the stock hypridle, your old wallpaper and the stock hyprlock.conf come back.

A later `apothecary off` still restores stock, because its own `prev-wallpaper` and `mako-was-active` are left alone.

At every login `hypr/on.conf` runs `exec-once = $HOME/.local/bin/overworld session-start`, which is a no-op unless
`~/.config/overworld/enabled` exists; it first waits up to 10 s for JaKooLit's startup to bring waybar up, so it stops the real thing.

The on/off state persists across logout and reboot. Turning the theme off is not uninstalling it: the hook line, symlinks and app files stay in
place (inert), so `overworld on` brings the theme back with the last mode and wallpaper.

Running `apothecary on` while Overworld is on is safe but leaves both enabled, and `overworld status` warns about it. Settle it with
`overworld on` or `apothecary off`.

## 3. Modes and wallpapers

```
overworld light | dark | toggle        # Day / Night, SUPER+T while on
overworld wallpaper next | prev        # SUPER+SHIFT+W = next
overworld wallpaper pick               # SUPER+W: Select World
overworld wallpaper current            # re-apply the remembered one
overworld wallpaper /path/to/file.png
overworld world new --scene plains     # render a new world wallpaper
```

A mode switch writes `~/.config/overworld/mode`, re-links `colors.conf`/`hyprlock-vars.conf`/`kitty-colors.conf`/
`lock.png`, runs `hyprctl reload` and then sets the mode's wallpaper with `awww` (`grow`, 1.2 s) and runs `apps/apply-mode.sh <mode>` detached
(`~/.cache/overworld/apps.log`). Wallpapers come from `assets/wallpapers/<mode>/` (gitignored; `docs/WORLDGEN.md`); the choice is remembered per
mode in `~/.config/overworld/wallpaper-<mode>`. `config.json → {"reduced_motion": true}` turns the wallpaper transition into a 0.3 s fade.

`overworld help` lists every verb, `overworld help <verb>` explains one.

## 4. What the Hyprland layer changes (only while on)

`hypr/on.conf` comes after JaKooLit's files, so it overrides them until `off`:
- `decorations.conf`: rounding 0, border 3, gaps 4/8, windows 0.94/0.88 translucent over blur (`ignore_opacity`), dim_inactive 0.06, a hard
  shadow (sharp, offset 5 5, no spread), layer rules for every `overworld-*` namespace: catch-all first (blur + `ignore_alpha 0.35` + `no_anim`),
  then blur off for the sprites and full-screen overlays. All GUI animation happens in QML on the 20-tick clock. Border colours come from
  `tokens/out/<mode>/hyprland-colors.conf` via `~/.config/overworld/colors.conf`.
- `animations.conf`: beziers `place` (a small overshoot) and `snap`; windows popin 85 % 250 ms, close 100 ms (the block-break effect does the
  drama), workspaces slide 350 ms, special workspace slidevert, fades 150 ms, `border` and `borderangle` off.
- `rules.conf`: `spf` (superfile in kitty) floats centred at 70 %, `overworld-*` helper and test windows float at 60 %, pickers
  (nwg-look, pavucontrol, blueman, nm-connection-editor, portals, swappy) float, video players unblurred and opaque, PiP pinned.
- `keybinds.conf`: see `docs/KEYBINDS.md` (every unbound JaKooLit key is listed with where it moved).
- `env`: `XCURSOR_THEME`/`HYPRCURSOR_THEME` = Overworld, size 24, for apps started while on. `hyprctl reload` re-reads `env` lines, so `off` puts
  JaKooLit's values back.

`hypr/overworld.conf` itself is always sourced and only sources `active.conf`. The `import-environment` + hermes-gateway restart at login stays in
Apothecary's `apothecary.conf`, so it runs once. If you ever uninstall Apothecary, move that exec-once line here.

## 5. hyprlock and hypridle

- `hypr/hyprlock.conf` (linked in only while on) is the title screen: the panorama render for the mode (`~/.config/overworld/lock.png` →
  `assets/renders/lock-<day|night>.png`, falls back to the current wallpaper), the OVERWORLD wordmark, a yellow splash tilted 20°
  (`hypr/scripts/splash.sh`, a new line every 10 min; hyprlock cannot pulse it), `Day N · HH:MM` (N = day of the year), a black text field with a grey
  outline, a Singleplayer button that says what Enter does, keyboard layout, date, battery, and a quote (`hypr/scripts/quote.sh`) where the game prints its
  copyright line. Variables from `~/.config/overworld/hyprlock-vars.conf`.
- `hypr/hypridle.conf` (used only while on; the stock file is never touched): 5 min dim to 30 % via `brightnessctl` on the backlight
  `scripts/backlight-dev.sh` picks, 10 min lock, 15 min DPMS off, lock before sleep. `lock_cmd` runs `hyprlock -c <repo>/hypr/hyprlock.conf`, so
  `loginctl lock-session` (CTRL+ALT+L, the Game Menu) always gets the title screen while on.

## 6. SDDM login screen (sudo, optional)

See `docs/SUDO-STEPS.md`. Preview without sudo:
`scripts/install-sddm.sh prepare && sddm-greeter-qt6 --test-mode --theme ~/Projects/overworld-hyprland/sddm/overworld`
(a normal window opens; the power buttons are greyed out in test mode because SDDM reports them as unavailable there).
`sudo scripts/install-sddm.sh [auto|light|dark]` copies the font, sprites, panorama strips, wordmark, splashes and quotes into
`/usr/share/sddm/themes/overworld` and sets `[Theme] Current=overworld` (backup `/etc/sddm.conf.pre-overworld`).
`auto` picks the Day or Night panorama by the clock at the login screen. `sudo scripts/install-sddm.sh revert` restores the old theme.

## 7. Uninstall

```
scripts/uninstall.sh            # off → remove hook line + links; keeps ~/.config/overworld (mode, wallpapers, config.json)
scripts/uninstall.sh --purge    # also deletes ~/.config/overworld
```
Only Overworld's changes are reversed: if Apothecary was on before, it is on afterwards, with its hook line and links as they were.
SDDM is separate (`sudo scripts/install-sddm.sh revert`).

## 8. Troubleshooting

| symptom | check |
|---|---|
| `hyprctl configerrors` lists something after `on` | the first error names the file/line; `overworld off` restores the previous config at once |
| no HUD after `on` | `tail ~/.cache/overworld/qs.log`; `qs -c overworld` by hand; `overworld reload` restarts it |
| notifications do not appear | another daemon holds the bus name: `overworld repair` stops mako and swaync |
| waybar came back by itself | a JaKooLit script restarted it: `overworld repair` (SUPER+ALT+R) |
| lock screen is the old one while on | `readlink ~/.config/hypr/hyprlock.conf` must point into the repo; `overworld on` re-does the swap |
| lock screen shows no picture | `ls -l ~/.config/overworld/lock.png` → needs `assets/renders/lock-<day\|night>.png` (`docs/WORLDGEN.md`) |
| lock screen has no button or wordmark | `hypr/scripts/lock-assets.sh`, then `ls ~/.cache/overworld/lock` (needs `magick`) |
| hyprlock has **not been live-tested** by the engineer (it cannot be dry-run without locking). First time: lock from a session you can recover (CTRL+ALT+L); if it fails to start, `overworld off` restores the previous `hyprlock.conf`. Syntax follows hyprlock 0.9.6; `hypr/test/check-config.sh` checks every `$ow_*` variable, every `cmd[]` and every option name against the binary. `hypr/test/lock-sim.sh` composes the expected layout with ImageMagick. |
| no /title card when switching | theme on? (`overworld status`); `config.json → workspace_card.enabled`; `overworld ws show 3` tests it via IPC; a malformed `workspaces.json` is ignored (the last good copy stays): `jq . ~/.config/overworld/workspaces.json` |
| Claude never labels a workspace | `overworld ws auto status` (watcher running?) and `overworld ws auto log`; the workspace must have windows; a pinned one (`(pinned)` in `overworld ws`) is skipped, and with `manage_manual: false` so are your own titles; `claude auth status --text` must show your plan login; `max_per_hour` may be reached |
| no sound | `config.json → "sounds": false`? `OW_SOUND_DRYRUN=1 overworld sound ui.click` prints what would play |
| `overworld` not found in a terminal | `~/.local/bin` is not in that shell's PATH; Hyprland binds use the full path |
| keybind still does the JaKooLit thing | `hyprctl binds \| grep -i <key>`; the unbind lines must match the key spelling in `configs/Keybinds.conf` |
| nothing happens on `overworld light` from a script | the script's shell cannot see Hyprland → `source scripts/dev-env.sh` first |
| `off` brings Apothecary back but you turned it off meanwhile | `apothecary off` while Overworld was on left `previous-theme` saying Apothecary; `apothecary off` again after `overworld off` |

## 9. Tests

| script | what it does |
|---|---|
| `hypr/test/check-config.sh` | `Hyprland --verify-config` on your real config + `on.conf` in both modes (parses only), hyprlock variables, `cmd[]`, option names, keybind conflicts |
| `hypr/test/handover-sandbox.sh` | install, on, off, stock path, Apothecary gone, verbs, uninstall in a throw-away `$HOME` with every session command stubbed |
| `hypr/test/greeter-shot.sh <out.png>` | SDDM theme in test mode on the empty workspace 77, one screenshot, closed again |
| `hypr/test/lock-sim.sh [day\|night]` | ImageMagick composite of the expected lock layout |
