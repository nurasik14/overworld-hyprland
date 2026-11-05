# Overworld Hyprland

A Minecraft-inspired theme for a real Hyprland desktop. The desktop is a Minecraft world and the Quickshell shell
is its HUD and menus: a hotbar for workspaces, hearts for the battery, a creative inventory for the launcher, toasts
for notifications, a chat console that runs `/` commands, advancements for desktop events. Every surface copies the
game's own GUI and behaviour (20-tick animations, nine-slice sprites, hover highlights), and windows are mined when
you close them and placed when you open them.

Two modes, switchable live. The CLI names are `light` and `dark`:

| CLI name | in the theme | feel |
|---|---|---|
| `light` | Day | classic Java GUI: light-grey bevelled panels, dark text, grass-and-sky worlds |
| `dark` | Night | deepslate and obsidian GUI, white text with drop shadows, moon, stars and nether accents |

A day/night cycle can switch them by itself at local sunrise and sunset (`daycycle` in `config.json`, or `/time set auto`).

| Desktop thing | Minecraft thing |
|---|---|
| workspaces 1-10 | hotbar (1-9) and offhand slot (10); the item is the busiest app, the stack count is the window count |
| battery / free RAM / CPU | hearts / hunger / air bubbles |
| uptime | XP level (hours) and XP bar |
| launcher | creative inventory (`=` calculator and `>` run kept) |
| notifications / history / Do Not Disturb | toasts ("Challenge Complete!" for urgent) / chat history / Peaceful difficulty |
| network panel | Multiplayer server list (signal = ping bars) |
| power menu | Game Menu (Esc screen) |
| wallpaper picker | Select World (Create New World renders a new wallpaper) |
| brew timer | brewing stand, boss bar |
| workspace title card | `/title` |
| closing / opening a window | mining a block (crack stages, break sound) / placing one |
| lock screen, login screen | title screen with the OVERWORLD wordmark and a splash |

## A theme system you can switch on and off

Overworld Hyprland is a theme system layered on top of
[JaKooLit's Fedora-Hyprland dotfiles](https://github.com/JaKooLit/Fedora-Hyprland); nothing of the base config is
edited in place. It coexists with the author's earlier theme, Apothecary Hyprland: both stay installed, at most one is on.

```sh
overworld on       # Hyprland layer, HUD shell, hyprlock/hypridle, app themes, wallpaper
overworld off      # back to what was there before: Apothecary in its mode, or the stock JaKooLit desktop
overworld status   # enabled, mode, previous theme, game mode, day cycle, processes
```

- `scripts/install.sh` adds one line to `~/.config/hypr/hyprland.conf` (after Apothecary's line if there is one) that
  sources `~/.config/hypr/overworld.conf`. That file only sources `~/.config/overworld/active.conf`, a symlink the
  CLI points at `hypr/on.conf` (the theme) or `hypr/off.conf` (empty), followed by `hyprctl reload`.
- `on` records what it replaces in `~/.config/overworld/previous-theme` (`apothecary dark`, `apothecary light` or
  `stock`). If Apothecary is on, it is switched off first. Then waybar and the notification daemons stop,
  `qs -c overworld` starts, and the theme's hyprlock/hypridle configs, wallpaper and app themes are applied.
- `off` reverses all of it for whatever was there before. If that was Apothecary, it comes back in the mode it was in
  (waybar and mako are not started); if it was stock, waybar, mako, the stock hypridle, your old wallpaper and your
  `hyprlock.conf` return.
- The state survives logout and reboot (`~/.config/overworld/enabled`). Off is not uninstall: `scripts/uninstall.sh`
  removes the hook and links. The SDDM login theme is separate and needs sudo ([docs/SUDO-STEPS.md](docs/SUDO-STEPS.md)).
- Day/Night (`SUPER+T`) is a separate switch inside the theme.

## Requirements and install

Fedora with JaKooLit's Hyprland dotfiles, Hyprland 0.56 (developed on 0.56.2), Quickshell (`qs`) 0.3, awww, kitty,
ImageMagick 7, jq, unzip, pw-play, nmcli, playerctl, grim and slurp. `uv` is needed for the world renderer and
the font and icon builds. Optional: the `claude` CLI (logged in) for workspace auto-labelling.

```sh
git clone <this repo> ~/Projects/overworld-hyprland && cd ~/Projects/overworld-hyprland
scripts/fetch-minecraft-assets.sh --build      # Mojang textures and sounds, then the local font and icons
(cd tools/worldgen && uv run python -m worldgen catalog)   # render the wallpaper set (docs/WORLDGEN.md)
scripts/install.sh                             # links the layer into ~/.config; idempotent
overworld on
```

Mojang assets are never committed. `scripts/fetch-minecraft-assets.sh` copies them from your own `~/.minecraft`
(read-only) or, if that is missing, downloads them from Mojang's servers into the gitignored `assets/mc/`. Anything
derived from them (wallpapers, renders, the bitmap font, icons) is built locally and also gitignored. Without the
assets the theme falls back to original art in `assets/gen/`.

Sounds are off on the owner's machine: `~/.config/overworld/config.json` has `"sounds": false`. To enable them set
`"sounds": true` there, or use Options > Music & Sounds (`SUPER+O`). (`install.sh` creates a config with
`"sounds": true` only when none exists.)

Full steps and removal: [docs/INSTALL.md](docs/INSTALL.md).

## Main keybinds

Active only while the theme is on. All of them are in [docs/KEYBINDS.md](docs/KEYBINDS.md), with what each replaced.

| Key | Action |
|---|---|
| `SUPER+Space` / `SUPER+D` | creative inventory (launcher) |
| `SUPER+Q` | mine the window (crack animation, then it closes) |
| `SUPER+Escape` | Game Menu |
| `SUPER+W` / `SUPER+SHIFT+W` | Select World / next wallpaper |
| `SUPER+T` | Day / Night |
| `SUPER+N` / `SUPER+I` | Multiplayer (network) / chat history (notifications) |
| `SUPER+SHIFT+T` / `SUPER+/` | chat console / chat console with `/` typed |
| `SUPER+L` / `SUPER+SHIFT+L` / `SUPER+O` | advancements / statistics / options |
| `SUPER+F3` / `SUPER+F4` | F3 debug screen / gamemode switcher |
| `SUPER+G` / `SUPER+B` | desktop widgets / brewing stand |
| `SUPER+SHIFT+G` / `SUPER+ALT+R` | adventure (performance) mode / repair |
| `SUPER+SHIFT+Space` | float or tile the window (`SUPER+Space` is the launcher) |

## Chat console, game modes, advancements, world effects

- **Chat**: `/help` lists the commands. Examples: `/time set day|night|auto`, `/weather clear|rain|thunder|snow|auto`,
  `/gamemode`, `/tp <1-10>` (go to a workspace), `/give <app>` (launch), `/locate <app>`, `/kill [class]`,
  `/brew 25m`, `/title <ws> <text>`, `/msg <text> in <duration>` (a real reminder), `/advancement`, `/stats`, `/f3`.
  Tab completes, Up/Down is history. System events show up as chat lines that fade after 10 s.
- **Game modes** (`overworld gamemode ...`, `SUPER+F4`): survival is normal; creative removes the HUD warnings; adventure
  is the performance mode (animations, blur, shadows, gaps, rounding off, widgets hidden); spectator is focus mode
  (HUD and widgets hidden, gaps 0, Do Not Disturb on).
- **Advancements and statistics**: 60 advancements in five tabs, unlocked by real desktop events (first terminal,
  first brew, 100 windows mined, 3 hours of uptime, Wi-Fi connected ...). The counts are of shell and Hyprland events
  only, no keystrokes.
- **World effects**: the day/night cycle (sun times computed locally) with time-of-day wallpapers; a rain, snow and
  thunder overlay driven by Open-Meteo weather or overridden by `/weather`; the F3 screen with live system values.
- **Interactions**: opening a window plays a place sound and dust; a screenshot (`Print`) prints "Saved screenshot as ..."
  in chat; at 5% battery while discharging a "You died!" screen appears; each uptime hour is an XP level.

## Layout of the repo

```
hypr/         Hyprland layer (on.conf, off.conf, decorations, animations, rules, keybinds), hyprlock, hypridle
quickshell/   the HUD shell: Bar/ Launcher/ Notifications/ Network/ Power/ Wallpapers/ Osd/ Brew/ Widgets/
              Game/ (chat, modes, advancements) World/ (day cycle, weather, F3) Interact/ (mining, death screen) Common/ Services/
scripts/      overworld (the CLI), install.sh, uninstall.sh, fetch-minecraft-assets.sh, make-world.sh, ow-sound, game/ world/ interact/
apps/         theming for kitty, GTK, Qt, rofi, cava, btop, fastfetch, nvim, Zen, wlogout ... (apply-mode.sh is the switch)
tokens/       tokens.json and build.py: one source for every colour file (out/)
tools/        worldgen (voxel world renderer), assetforge (fonts, icons, fallback art)
quotes/       splashes, advancements, chat texts, blocks of the day
sddm/         login theme (sudo to install)
assets/       gen/ original art (committed); mc/ fonts/ wallpapers/ renders/ are fetched or built locally and gitignored
docs/         documentation   BRIEF.md  the design contract the project was built from   qa/  QA review notes
```

## Docs

[INSTALL](docs/INSTALL.md) - [KEYBINDS](docs/KEYBINDS.md) - [HYPRLAND-GUIDE](docs/HYPRLAND-GUIDE.md) (a field guide to Hyprland on this setup) -
[QUICKSHELL](docs/QUICKSHELL.md) - [GAMEPLAY](docs/GAMEPLAY.md) - [WORLD](docs/WORLD.md) - [INTERACTIONS](docs/INTERACTIONS.md) -
[WIDGETS](docs/WIDGETS.md) - [APPS](docs/APPS.md) - [WORLDGEN](docs/WORLDGEN.md) - [DESIGN](docs/DESIGN.md) -
[SUDO-STEPS](docs/SUDO-STEPS.md) - [STATUS](docs/STATUS.md).

## Credits and licence

This is an unofficial fan project. It is not made by, endorsed by or affiliated with Mojang Studios or Microsoft;
"Minecraft" is a trademark of Mojang Studios. Textures, sounds, the bitmap font and splash texts from the game are
(c) Mojang Studios; they are not in this repository and are fetched to your machine for personal desktop theming.
The project never uses the Minecraft logo: its wordmark is OVERWORLD, in our own block lettering
(`assets/gen/wordmark/`). Fonts and other third-party assets are listed in [assets/CREDITS.md](assets/CREDITS.md).

The theme was designed and implemented by a team of AI agents (Hermes and Claude) under the owner's direction, then
QA-tested on real hardware; the process notes are in `docs/agent-prompts/`, `docs/agent-reports/` and `qa/`.

Code and configuration: MIT, see [LICENSE](LICENSE). Mojang's assets keep their owner's rights.
