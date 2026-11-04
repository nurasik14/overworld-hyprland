# Overworld Hyprland — shared design & engineering brief (THE CONTRACT)

Read this whole file before touching anything. Every agent on the project works from it.

Overworld Hyprland is a **Minecraft-inspired** theme system for the user's Hyprland desktop. It is a fork of the
user's finished **Apothecary Hyprland** theme (`~/Projects/apothecary-hyprland`, read-only reference: commit
26a8391; its original brief is kept as `docs/APOTHECARY-BRIEF-legacy.md`) and must keep **every Apothecary
feature** while turning the desktop into Minecraft — not just colours and pictures, but **Minecraft GUI
behaviour, Minecraft animations, Minecraft sounds and Minecraft game mechanics mapped onto real desktop
functions.** The repo was forked and mechanically renamed in phase 0 (`apothecary` → `overworld`,
`apo-`/`apo_` token prefixes → `ow-`/`ow_`); everything Chinese / Maomao / ink / paper / seal in it is now
legacy that the owning agent replaces with the Minecraft equivalent.

## 0. Machine & user facts (verified 2026-11-05 02:10)

- Fedora 44, Hyprland 0.56.2, Quickshell 0.3.2 (`qs`), one monitor `eDP-1` 1920x1080 @165 Hz scale 1,
  RTX 4050 (6 GB) + Intel iGPU, 15 GB RAM, 16 cores. hypridle 0.1.8. ImageMagick 7 (`magick`), ffmpeg, grim,
  jq, inkscape, hyprcursor-util, cava, playerctl, pw-play, Real-ESRGAN (`realesrgan-ncnn-vulkan`). **No numpy
  in system python** — Python work that needs numpy/Pillow/fonttools goes in a `uv` project under
  `tools/<name>/` (find uv with `command -v uv || ls ~/.hermes/tools/uv-*/uv`).
  No `xcursorgen` (write Xcursor files from Python), no blender, no sox.
- Base dotfiles: **JaKooLit Fedora-Hyprland**; the Apothecary theme is installed and currently **ON (dark)**
  (`apothecary status`). It hooks `~/.config/hypr/hyprland.conf` with `source = ~/.config/hypr/apothecary.conf`.
  Stock (theme-off) desktop = waybar + **mako** (systemd `mako.service`) + awww wallpaper daemon + `qs -c overview`.
- Fonts: **Monocraft** (Nerd-Font-patched TTC, family `Monocraft`, has Nerd glyphs + Cyrillic) is installed in
  `~/.local/share/fonts/overworld/`. asset-forge builds the proportional Minecraft bitmap font (family
  **`Overworld Mojangles`**) from the jar's font PNGs. All Apothecary fonts are still installed.
- **The user plays Minecraft** (TLauncher, `~/.minecraft`, versions up to 1.21.11, worlds in `~/.minecraft/saves/`:
  "New World", "New World (1)", "New World (2)", "SpeedrunHunt", "SpeedrunHunt (1)"; 2 screenshots in
  `~/.minecraft/screenshots/`). Read-only: never write anything under `~/.minecraft`.
- **Minecraft assets already extracted (phase 0)** to `assets/mc/` (gitignored, © Mojang):
  `assets/mc/textures/**` (the whole 1.21.11 texture tree incl. `gui/sprites/**` with `.png.mcmeta` nine-slice
  metadata, `block/`, `item/`, `environment/` sun/moon/rain/snow, `particle/`, `misc/`, `font/`), `assets/mc/models/`,
  `assets/mc/blockstates/`, `assets/mc/font/*.json`, `assets/mc/texts/splashes.txt`, `assets/mc/lang/en_us.json`,
  `assets/mc/sounds/**.ogg` (all 4405 sound files, same relative paths as `minecraft/sounds/...`) and
  `assets/mc/sounds.json` (event → file mapping). The title panorama files in this jar are 1x1 stubs →
  world-renderer renders our own panorama.
- User: CS freshman (Hong Kong), Russian/Kazakh/English, intermediate programmer, wants to understand the
  system; likes slow/soft animations EXCEPT workspace switches (quick, ~350–400 ms); likes see-through desktop
  widgets (~0.72 opacity, configurable). He uses kitty, Zen browser (flatpak) with YouTube Music, Spotify rpm
  (rarely), superfile `spf`, nvim, btop, the Hermes agent CLI in kitty.
- **The user is ASLEEP while this is built (02:00–~09:00 HKT).** An idle/sleep inhibitor is held by the
  orchestrator and the backlight is dimmed to 4 % on purpose — leave both alone.

## 1. Hard safety rules (every agent — violating one = failed run)

1. **Silence.** Never play audible sound: no `pw-play`/`paplay`/`mpv`/`ffplay` of anything; keep
   `~/.config/overworld/config.json → "sounds": false` (the orchestrator set it). Test sound code paths with
   `OW_SOUND_DRYRUN=1` (scripts/ow-sound then prints instead of playing). Never change volume, never
   mute/unmute, never play/pause/skip media (`playerctl` read-only: `metadata`, `status`, `position` are fine).
2. **Do not disturb the running session.** Never kill/restart: Hyprland, any `hermes*` process or the
   `hermes-gateway` service, `claude` processes you did not start, the user's kitty/Zen/Spotify windows,
   `qs -c apothecary`, `qs -c overview`, mako, waybar, hypridle, the `systemd-inhibit` holder, the
   `ws-autolabel` watcher. Do not lock, suspend, log out, `hyprctl dispatch dpms`, or change brightness.
   Never `pkill -f`/`killall` — kill only PIDs you started (`$!`), or `pkill -x` of your own process names.
   **Another, unrelated Hermes orchestration (`~/Projects/mochi-pi`) is running — never touch that directory.**
3. **Only the theme switch changes the live desktop**, and only the agents told to (hyprland-engineer at the end
   of its run, qa-reviewer). Everyone else tests with preview harnesses (`qs -p <dir>`) on top of the running
   Apothecary desktop, or with `qs -p ~/Projects/overworld-hyprland/quickshell` *only if your prompt says so*.
4. **Screenshots: only `scripts/dev-shot.sh <out.png> [x,y wxh | layer:<namespace> | full]`.** It serialises all
   agents with a lock, switches to the empty workspace 77, captures, and switches back. Never call `grim`
   directly, never `hyprctl dispatch workspace` yourself, never move the cursor (`movecursor`), never focus or
   close the user's windows. Save shots under `qa/screenshots/<agent>-<what>.png` and LOOK at them (Read the
   PNG). A "looks fine" without viewing the image is not verification. Note: Apothecary's own bar and
   widget cards are visible underneath your previews — judge only your surface (crop with a region).
5. Shells you spawn do not see Hyprland: run `source ~/Projects/overworld-hyprland/scripts/dev-env.sh` first.
6. **No sudo.** Root steps (SDDM install, dnf) go into `docs/SUDO-STEPS.md` + a script; never attempt them.
7. **No git commits, no git config, no push, no reset/checkout/stash/clean/restore.** The orchestrator commits
   after each phase.
8. **Ownership (§3).** Edit only your own paths. Need something elsewhere? Append to `docs/REQUESTS.md`:
   `- [from <you>] -> [<owner>]: <request>` and work around it meanwhile. Read-only reference:
   `~/Projects/apothecary-hyprland` (never edit it; never run its install/uninstall). Never write to `~/.minecraft`.
9. **Copyright.** Mojang assets (textures, sounds, the font, splashes) and anything derived from them
   (renders using Mojang textures, the bitmap-font TTF, icons cut from sprites) are **never committed**: they
   live in gitignored paths (`assets/mc/`, `assets/wallpapers/`, `assets/renders/`, `assets/fonts/`,
   `assets/icons/mc/`) and `scripts/fetch-minecraft-assets.sh` must be able to recreate `assets/mc/` from
   Mojang's servers (or a local `~/.minecraft`). Original work (generated pixel art in `assets/gen/`, code,
   our own text) is committed. Never use the "MINECRAFT" logo/wordmark; our wordmark is **OVERWORLD** in our
   own block lettering.
10. Never fabricate facts. Minecraft facts (block/mob of the day, trivia) must be checkable on minecraft.wiki;
    if unsure, write an original line marked `"source": "original"`.
11. Long jobs: Claude Code's Bash tool times out — run renders/builds in the background with logs and poll.
    Keep CPU-heavy work to ≤ 8 cores (`nice -n 10`), RAM < 3 GB per process; the GPU is free to use.
12. Keep a running log of what you did and verified in `docs/agent-reports/<agent>.md` (create it, update it
    after each deliverable) — if your run is cut off, you are relaunched from that file.

## 2. The concept — "Overworld"

The desktop **is** a Minecraft world and the shell **is** its HUD and menus. Every surface is a real Minecraft
GUI element that behaves like it does in the game:

| desktop thing | Minecraft thing | behaviour that must feel like the game |
|---|---|---|
| workspaces 1–9 (+10) | **hotbar** (9 slots + offhand slot for ws 10) | selection frame jumps instantly; each slot shows an **item icon for the dominant app** on that workspace with the window count as the **stack count**; on switch the **item name** (workspace title from workspaces.json) pops above the hotbar and fades after ~2 s; scroll wheel cycles slots |
| battery | **hearts** (10 hearts, half hearts) | regen pulse while charging; hearts **jiggle** below 20 % like low health; hardcore hearts when critical |
| memory | **hunger** (drumsticks) | free-RAM ratio; hunger shake when swap is used heavily |
| CPU | **armor** or **air bubbles** (designer's call) | |
| uptime | **XP level + XP bar** | level = hours of uptime, bar = progress through the hour; level-up sparkle + sound each new level |
| brew timer / media | **boss bar** at top centre | only while active; title = "Brewing: <task>" / track title |
| launcher | **creative inventory** | tabs (Search, Favourites, categories), 9-column slot grid of app icons, hover tooltips (purple border; name, grey description, blue category line), slot hover highlight, search field, scrollbar; `=` calculator and `>` run-command modes kept |
| notifications | **toasts** (advancement / recipe / system toast sprites, slide in at top-right, stack) | urgent = **"Challenge Complete!"** purple toast; normal = yellow-title advancement style; toast in/out sounds |
| notification centre | chat-history / log panel | DND = **"Peaceful"** difficulty |
| network panel | **Multiplayer server list** | Wi-Fi networks = servers (name, MOTD line = security/band, **ping-bar sprites = signal**), Join Server / Direct Connection (hidden SSID) / Refresh / Cancel; password = Minecraft text field; VPNs + wired listed as LAN worlds |
| power menu | **Game Menu (Esc pause screen)** | Back to Game · Advancements · Statistics · Options… · Lock · Sleep in Bed (suspend) · Save and Quit to Title (logout) · Respawn (reboot) · Quit Game (shutdown, with a confirm screen) |
| wallpaper picker | **Select World** screen | world rows (thumbnail, name, "Last played", "Survival Mode"), Play Selected World, **Create New World** (renders a new procedural world wallpaper in the background), Cancel |
| volume / brightness OSD | **Options slider** | "Master Volume: 75%", brightness labels "Moody" (0 %) … "Bright" (100 %) like the real option |
| workspace card | **/title** | big title + subtitle, fade-in 10 ticks, stay 70, fade-out 20 ticks (the real /title defaults) |
| brew timer + dialog | **brewing stand** GUI | bubbles + arrow progress + blaze-powder fuel; bottles fill as sessions complete |
| desktop widgets | GUI panels / signs / item frames / F3 text | see the qs-widgets prompt |
| lock screen | **title screen** | our panorama, OVERWORLD wordmark, bouncing yellow **splash text**, Minecraft text field |
| login (SDDM) | title screen with a **slowly rotating panorama** | "Singleplayer" = log in |
| closing a window | **mining the block** | crack stages over the window, break particles from the window's own pixels, material break sound, then close |
| opening a window | **placing a block** | place sound + small dust particles |
| tooltips everywhere | Minecraft tooltip | dark translucent fill, purple gradient border |

**Two modes** (keep the CLI names `light`/`dark`): `light` = **Day** (classic Java GUI: light-grey `#C6C6C6`
bevelled panels, `#373737`/`#404040` title text, white/dark bevel edges, grass-and-sky world) and `dark` =
**Night** (deepslate / obsidian dark GUI, white text with Minecraft drop shadows, moon/stars/nether accents).
A **day/night cycle** can switch them automatically at local sunrise/sunset.

**"Another level" — functionality, not only looks (all required):**
1. **Chat console** (`T`-style): `/`-commands with tab completion + history that drive the desktop
   (`/time set day|night`, `/weather clear|rain|thunder`, `/gamemode survival|creative|adventure|spectator`,
   `/tp <ws>`, `/give <app>`, `/kill`, `/locate <app>`, `/seed`, `/brew <dur>`, `/title <ws> <text>`,
   `/clear`, `/advancement`, `/stats`, `/f3`, `/reload`, `/help`); a chat log where system events appear as chat
   lines that fade after 10 s like in-game chat.
2. **Game modes:** survival = normal; creative = everything on, no hunger/heart warnings; adventure = the old
   Apothecary "gamemode" (performance: animations/blur/shadows off, widgets hidden); spectator = focus mode
   (bar and widgets hidden, gaps 0, Peaceful/DND, chat still reachable). Shown as a Minecraft **gamemode
   switcher** overlay (F3+F4 style, four icons) on SUPER+F4.
3. **Advancements + Statistics:** real achievements unlocked by real desktop events (first terminal, first brew,
   100 windows mined, 3 h uptime, Wi-Fi connected, night-owl after 02:00, …) with an advancement-tree screen
   (tabs; frames task/goal/challenge) and a statistics screen (time played, windows opened/closed, workspaces
   switched, notifications received, brews completed, screenshots taken). **No keylogging** — only counts of
   shell/Hyprland events.
4. **World effects:** day/night cycle (auto by sun times + time-of-day wallpaper variants), **weather overlay**
   (Minecraft rain/snow textures falling, lightning flash) driven by real Open-Meteo weather, overridable by
   `/weather`; **F3 debug screen** overlay with live system values in F3 format.
5. **Interactions:** block-break window close, block-place window open, screenshot = "Saved screenshot as …"
   chat line + item-pickup pop, low-battery "You died!"-style screen at ≤ 5 % (once per discharge; Respawn =
   dismiss, Title Screen = lock), XP level-up each uptime hour.
6. **Options screen** (Minecraft Options menu) that edits `~/.config/overworld/config.json` live: GUI scale
   (1/2/3/Auto), Music & Sounds sliders per category (master, ui, toasts, blocks, ambient), Video Settings
   (animations, particles All/Decreased/Minimal, weather effects), Day/Night cycle (Auto/Day/Night), widget
   opacity, Difficulty (Peaceful = DND).

## 3. Repository layout and ownership

Repo: `~/Projects/overworld-hyprland` (git, branch main). Quickshell config root `quickshell/` (linked as
`~/.config/quickshell/overworld` by install.sh; run as `qs -c overworld`).

```
BRIEF.md docs/STATUS.md                  orchestrator only
docs/REQUESTS.md docs/SUDO-STEPS.md      anyone appends
docs/agent-reports/<agent>.md            each agent its own
docs/DESIGN.md                           design-director
tokens/ (tokens.json, build.py, out/)    design-director (others request changes) — EXCEPT
tokens/sounds.json tokens/items.json     asset-forge
quickshell/Common/                       design-director (qs-core may ADD new files; others request)
quickshell/Services/* (existing files)   qs-core
quickshell/Services/GameEvents.qml       qs-features (API in §4.4 is frozen)
quickshell/shell.qml                     qs-core (phase 0 already wires Game/World/Interact)
quickshell/{Bar,Launcher,Notifications,Network,Power,Wallpapers,Osd,Brew}/   qs-core
quickshell/Widgets/                      qs-widgets
quickshell/Game/                         qs-features   (entry GameSystems.qml)
quickshell/World/                        fx-world      (entry WorldFx.qml)
quickshell/Interact/                     fx-interactions (entry Interactions.qml)
hypr/ sddm/ scripts/overworld scripts/install.sh scripts/uninstall.sh docs/KEYBINDS.md docs/INSTALL.md   hyprland-engineer
apps/ docs/APPS.md                       app-theming
assets/gen/ assets/icons/ assets/CREDITS.md tools/assetforge/ scripts/fetch-minecraft-assets.sh scripts/ow-sound   asset-forge
assets/wallpapers/ assets/renders/ tools/worldgen/ scripts/make-world.sh   world-renderer
quotes/ (splashes, block/mob of the day, advancements.json, chat help, tips)   lore-writer
qa/ README.md docs/HYPRLAND-GUIDE.md     qa-reviewer (phase 3)
```
New Quickshell modules may add `pragma Singleton` services inside their own directory (they resolve as
`qs.Game`, `qs.World`, `qs.Interact`). Each module puts its own `IpcHandler`s inside its entry component.

## 4. Runtime contract

4.1 **State dir** `~/.config/overworld/` (same layout as Apothecary's `~/.config/apothecary/`: `mode`, `enabled`,
`config.json`, `wallpaper-<mode>`, `active.conf`, `colors.conf`, `workspaces.json`, `widget-positions.json`, …)
plus `advancements.json`, `stats.json`, `chat-history.json`. Runtime files: `$XDG_RUNTIME_DIR/overworld/`.
Cache: `~/.cache/overworld/`.

4.2 **Coexistence with Apothecary.** Both themes stay installed. `overworld on` turns Apothecary off first if it is
on (remembered in `~/.config/overworld/previous-theme`); `overworld off` restores what was there before
(Apothecary on, or stock). Overworld's hook line in hyprland.conf goes after Apothecary's. Only Apothecary's
`apothecary.conf` keeps the gateway `import-environment` + restart exec-once; Overworld must not duplicate it.

4.3 **Assets & textures.** QML resolves a texture through `Theme.tex("gui/sprites/hud/heart/full")` →
`assets/mc/textures/<p>.png` when the Mojang assets are present, else `assets/gen/textures/<p>.png`
(asset-forge's original fallback art), else the magenta/black **missing texture**. Pixel art is always drawn
with `smooth: false`, at an integer **GUI scale** (`Theme.gui`, default 2; config `gui_scale` 1–4 or "auto"),
no rounded corners, nine-slice from the `.mcmeta` `gui.scaling` data (`nine_slice` border/width/height, `tile`,
`stretch`). App → item icon mapping: `tokens/items.json` (asset-forge)
`{"kitty": "command_block", "zen": "compass", …, "_default": …}` with pre-rendered isometric block / flat item
icons in `assets/icons/mc/<name>.png` (gitignored; fallback `assets/gen/icons/<name>.png`).

4.4 **Event bus (frozen API).** `GameEvents.emit(name, data)` in QML / `overworld event <name> '<json>'` in shell →
one JSON line in `$XDG_RUNTIME_DIR/overworld/events.jsonl`; listeners use
`Connections { target: GameEvents; function onEvent(name, data) {…} }`. Emit these where your component does
the thing: `window.open {cls,title}`, `window.kill {cls}`, `workspace {id}`, `screenshot {path}`,
`brew.start|brew.done|rest.done {}`, `notify {app,urgency}`, `battery {percent,charging}`, `net.connect {ssid}`,
`launcher.launch {app}`, `chat.command {cmd}`, `mode {mode}`, `gamemode {mode}`, `wallpaper.set {path}`,
`world.created {path}`, `advancement {id}`, `xp.levelup {level}`, `death {}`.

4.5 **Sounds.** `tokens/sounds.json` (asset-forge): `{"ui.click": {"files": ["mc:random/click"], "volume": 0.4,
"category": "ui"}, …}` (`mc:` → `assets/mc/sounds/<p>.ogg`, `gen:` → `assets/sounds/<p>.*`; several files =
random variant). One player for everything: `scripts/ow-sound <id>` (asset-forge) — respects `config.json`
`sounds` (false = silent) and per-category volumes, honours `OW_SOUND_DRYRUN=1`, detached `pw-play`. QML
`SoundService.play(id)` calls it. Ids anyone may use: `ui.click`, `ui.toast.in`, `ui.toast.out`,
`ui.toast.challenge`, `notify`, `notify.urgent`, `xp.orb`, `xp.levelup`, `chest.open`, `chest.close`,
`door.open`, `door.close`, `book.page`, `item.pickup`, `block.break.<stone|wood|glass|grass|wool|metal>`,
`block.place.<same>`, `block.hit.<same>`, `brew.done`, `brew.drink`, `anvil.land`, `bell`, `note.harp`,
`portal.trigger` (very quiet), `player.hurt`, `player.death`, `lightning` (quiet), `rain.ambient` (quiet, optional).

4.6 **Quickshell IPC** — every Apothecary target/function keeps working under `qs -c overworld ipc call …`
(`launcher`, `network`, `power`, `wallpapers`, `notifications`, `widgets`, `theme`, `osd`, `workspace`,
`shell`, `brew`) and new ones are added: `chat open|command <text>|say <text>`, `advancements open`,
`stats open`, `options open`, `gamemode set <m>|switcher`, `world weather <w>|daycycle <auto|day|night>|f3`,
`interact kill|place|death|respawn`. Never name an IPC function `show` (the qs CLI eats it) — use `reveal`/`open`.

4.7 **Keybinds** (hyprland-engineer finalises `docs/KEYBINDS.md`): keep every Apothecary bind (SUPER+Space/D
launcher, N network, Escape game menu, W wallpapers, SHIFT+W next, T day/night toggle, G widgets, I
notifications, SHIFT+I DND, B brew, SHIFT+B brew dialog, E superfile, Return kitty) and add: SUPER+Slash chat
with "/" prefilled, a chat key (check JaKooLit conflicts), SUPER+F3 debug screen, SUPER+F4 gamemode switcher,
an advancements key, SUPER+Q (JaKooLit killactive) → `overworld kill` (block-break close), Print → themed
screenshot wrapper.

4.8 **Motion language (Minecraft feel).** Minecraft runs at **20 ticks/s**: sprite animations (water, portal,
enchant glint, fire, cracks) step on a shared tick clock (`Theme.tick`, 50 ms) for the chunky feel; GUI screens
appear quickly (≤150 ms fade, dimmed background like the game's menu gradient `#C0101010→#D0101010`); buttons
highlight instantly on hover (white border) and play `ui.click`; the hotbar selection snaps; toasts slide in
~0.5 s, hold, slide out; /title uses tick timings; splash text pulses in scale; text has hard 1-GUI-pixel drop
shadows (shadow colour = text colour × 0.25, like the game). Hyprland: snappy "block placed" pop-in (popin
~85 %, ~250 ms, slight overshoot), quick workspace slide (~350 ms), no rounding, crisp borders, layer fades
~150 ms. Honour `config.json → reduced_motion` and the Options "animations" switch.

## 5. Feature parity checklist (Apothecary → Overworld; nothing may be lost)

Shell: bar (workspaces with notes tooltip, window title, clock+date, tray, wifi/bt/battery/volume chips, mode
toggle, notification bell, launcher button, widgets menu chip with per-card on/off + reset positions);
launcher (fuzzy, keyboard nav, categories, `=` calc, `>` run); notification daemon (popups, urgent, centre
with history, DND); network panel (scan, signal, security, password entry, connect/disconnect, airplane,
wired, VPN list, inline nmcli errors); power menu; wallpaper picker (per mode, remembered); OSD volume/
brightness (device from `scripts/backlight-dev.sh`); workspace card on switch + workspace titles/notes
(`workspaces.json`, `overworld ws …`, Claude auto-labelling `scripts/ws-autolabel.py`, pin/unpin,
reset_after); brew timer (any lengths, rest 0, dialog, scroll-to-adjust, CLI, Minecraft brewing/drink finish
sounds); desktop widgets (8 cards: Music, Weather, Calendar, SysInfo, Cava, Quote, Herb-of-day →
Block/Mob-of-the-day, Brew) — draggable by the title bar, positions persisted, per-card hide/show, opacity
config, click-through empty desktop; light/dark toggle with cross-fade; `overworld gamemode|repair|wallpaper
random` replacing JaKooLit GameMode.sh/Refresh.sh/WallpaperRandom.sh binds; translucent windows; hyprlock;
hypridle; SDDM theme (sudo step); wlogout; app theming (kitty, GTK3/4, Kvantum/qt6ct, icons, cursor, rofi,
superfile, fastfetch, cava, btop, starship, spicetify, Zen, nvim, swappy); install/uninstall; docs.

## 6. Verification standard

Run what you build. QML: preview harness (`qs -p <dir>`, log to a file, `console.warn` for debugging, zero new
QML warnings from your files), screenshot with `scripts/dev-shot.sh`, open the PNG, fix, repeat. Configs:
syntax-validate (`hyprctl configerrors` after reloading a complete file, `kitty --debug-config`,
`rofi -dump-theme`, tomllib/json parse, `timeout 2 hypridle -c`, `sddm-greeter-qt6 --test-mode`). Scripts:
`bash -n` and run them. Your agent report states exactly what was verified and what was not, with screenshot
paths.
