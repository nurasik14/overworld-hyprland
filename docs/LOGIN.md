# The login screen and its theme button

One login screen with three looks behind a **Theme** button at the top right. Picking a look does two things:

| Look | Login screen | Session it selects | Desktop you land on |
|---|---|---|---|
| Waguri | your SilentSDDM theme, `configs/waguri.conf` | Hyprland · Stock | stock JaKooLit, every theme off |
| Overworld | the Minecraft title screen | Hyprland · Overworld | Overworld |
| Apothecary | the Apothecary sign-in card | Hyprland · Apothecary | Apothecary |

Open the menu with a click, **Alt+T** or **F10**. Inside it: ↑ ↓ and Enter, the keys 1 2 3, Esc to close.

The look's own session selector still works. Choosing Plasma by hand logs you into Plasma, keeps the look, and is still selected at the next boot.

## Install and revert

```
sudo ~/Projects/overworld-hyprland/scripts/install-sddm.sh hyprthemes
```

You see the new screen at the next logout or reboot. The first time it shows the look of the desktop you are running, so with Overworld on you get the Overworld look.

To go back, from your desktop or from a text console (Ctrl+Alt+F3) if the login screen ever misbehaves:

```
sudo ~/Projects/overworld-hyprland/scripts/install-sddm.sh revert
```

This puts `/etc/sddm.conf` back byte for byte and removes the theme, the three sessions and `/usr/local/bin/hypr-theme-session`. If you edited the file after installing, your edits stay and only the two changes below are undone. The desktop theme stays as it is; `overworld on|off` and `apothecary on|off` still switch it.

Run the install again after you change a theme, because it copies the themes rather than linking them.

## What the install changes

- `/usr/share/sddm/themes/hyprthemes`: the wrapper theme with copies of the three looks. The `sddm` user cannot read your home, so everything is copied in.
- `/usr/share/wayland-sessions/hyprland-{overworld,apothecary,stock}.desktop`: the three sessions.
- `/usr/local/bin/hypr-theme-session`: a copy of `scripts/theme-session`.
- `/var/lib/sddm/.config/hyprthemes/greeter.conf`: where the login screen remembers your pick.
- `/etc/sddm.conf`, backed up first as `/etc/sddm.conf.pre-hyprthemes`, in two places:
  - `Current=hyprthemes`. A drop-in in `/etc/sddm.conf.d/` cannot do this, because `/etc/sddm.conf` has the highest precedence (`man sddm.conf`) and says `Current=silent`.
  - `QT_VIRTUALKEYBOARD_DESKTOP_DISABLE=1` added to `GreeterEnvironment`. The file sets `QT_IM_MODULE=qtvirtualkeyboard` for Silent, which draws its own on-screen keyboard. Without this, any look that has no keyboard of its own gets Qt's desktop keyboard instead: a separate window that opens and takes the focus whenever a text field is focused.

Your original `/usr/share/sddm/themes/silent` is not touched and must stay installed: `GreeterEnvironment` points at its `components/` directory for the on-screen keyboard's style.

## How it works

### The looks and their config

SDDM gives a theme one `config` object, filled from one file, but Silent and the other two read different keys, and Overworld and Apothecary both read `Mode`. Each look lives in `looks/<dir>/` and is loaded with a `Loader`, so its relative paths (images, fonts, `components/`) resolve as usual. `theme.conf` is built from all three:

```
<Silent's waguri.conf, unchanged>      read through SDDM's real `config`

[HyprThemes]                           the wrapper's own settings
Looks=waguri,overworld,apothecary
DefaultLook=overworld
StateFile=/var/lib/sddm/.config/hyprthemes/greeter.conf

[look.overworld]                       Overworld's theme.conf [General]
Mode=auto

[look.apothecary]                      Apothecary's theme.conf [General]
Mode=light
...
```

`LookHost.qml` has a property called `config` that shadows SDDM's object for everything loaded under it, and answers `stringValue("Mode")` from that look's section. QML finds a name in the enclosing items before the root context, so the looks need no change for this.

Singletons are the exception. They only see the root context, and Silent reads all its settings in its `Config` singleton. That is why Silent's sections stay at the top level. The installer refuses to build if they ever collide with `[HyprThemes]` or `[look.*]`.

### The session

Each look keeps its own session index and starts from `sessionModel.lastIndex`, which is read-only. The installer replaces that one expression in the copies with `hyprthemesSessionIndex`, a property of `LookHost.qml`. Picking a look creates a new instance of it, which starts on the right session. If a future version of a theme no longer contains the expression, the install stops instead of building a look that logs into the wrong desktop. That is the only source change.

The wrapper remembers two values:

- `look`: the last pick.
- `sessionChoice`: the session that pick selected, until a login uses it. After a login it is cleared and SDDM's own "last session" takes over, which is how a session chosen by hand survives a reboot.

On the first boot, the plain `Hyprland` session moves to the theme session of the same desktop. Any other last session (Plasma, for example) stays selected.

### What happens at login

1. SDDM runs `/usr/local/bin/hypr-theme-session <theme>` as you, through `/etc/sddm/wayland-session`.
2. The script changes the theme state on disk, as `on` / `off` would, without `hyprctl` and without touching any process:
   - Overworld through `overworld prepare on|off`.
   - Apothecary with the same steps as its CLI's `on` / `off`, kept in the script because that repo is not changed from here.
   - `hyprlock.conf` keeps its chain of backups, so stock → Apothecary → Overworld → stock ends on your original file.
3. If the apps need switching (kitty, GTK, Qt, …), `apps/apply-mode.sh` runs in the background and the script waits for it, for at most 6 seconds. This only happens when the theme actually changes.
4. It execs `/usr/bin/start-hyprland`.
5. `exec-once` in the theme's `on.conf` runs `session-start` as on any login: waybar and mako stop, the shell, hypridle and wallpaper start. With stock, JaKooLit's own startup restores your wallpaper.

Hyprland always starts, whatever fails. A theme whose repo or Hyprland hook is missing falls back to stock, and a dangling `hyprlock.conf` is replaced by its backup. Logging in to the theme you are already on changes nothing.

Log: `~/.cache/hypr-theme-session.log`

## If something goes wrong

- A look that fails to load is skipped for the next one. If none loads you get a plain form, so a broken look cannot lock you out. The greeter's messages are in `journalctl -t sddm-greeter-qt6`.
- The look changes but the desktop does not: check the log above and the session named on the login screen.
- With two monitors each screen runs its own login screen, so a pick on one does not move the other until the next boot.

## Adding a look

1. Add its entry to `sddm/hyprthemes/looks.js`: `id`, `label`, `dir`, `configSection` (`look.<id>`), `session`, `desktop`.
2. In `build_hyprthemes` in `scripts/install-sddm.sh`, copy the theme to `looks/<dir>`, call `patch_session_index`, add the id to `looks`, and call `append_general` for its `theme.conf`.
3. For a new desktop theme, add `sessions/hyprland-<id>.desktop`, list it in `SESSION_FILES`, and add a case to `switch_to` and `apps_wanted` in `scripts/theme-session`. A look can also reuse an existing session.
4. If the theme reads its config in a singleton, shadowing cannot reach it. Its keys have to go at the top level of `theme.conf` without colliding with Silent's, or the singleton has to be patched like the session index.

## Tests (no sudo, nothing on screen, no sound)

```
scripts/install-sddm.sh prepare hyprthemes          # build into sddm/.staging/hyprthemes
sddm/hyprthemes/test/test-install.sh                # install and revert inside a scratch root, from a copy of /etc/sddm.conf
sddm/hyprthemes/test/test-theme-session.sh          # every theme transition, fake HOME and repos, traps on hyprctl and friends
sddm/hyprthemes/test/test-greeter.sh                # the real sddm-greeter-qt6, offscreen: real key and mouse events, PNGs in qa/screenshots/sddm-switcher/
```

`test-install.sh` rebuilds the staging dir with its own paths, so run `prepare` again before `test-greeter.sh`.

The offscreen renderer has no GPU, so it cannot draw `MultiEffect` or video frames. In those renders Silent's icons and avatar are blank squares and its background is the placeholder image. The untouched Silent theme renders the same way (`BASELINE=1 sddm/hyprthemes/test/run-harness.sh x <dir>`).
