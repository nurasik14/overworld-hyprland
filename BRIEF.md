# Overworld Hyprland — shared design & engineering brief

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (the stock desktop returns in about 5 s, no logout); `overworld status` shows which state is active.
> This brief is the original build contract; the on/off switch it specifies (§4) is what shipped. How the switch works: [README](README.md#a-theme-system-you-can-switch-on-and-off).

Read this whole file before touching anything. It is the contract between every agent on the project.

## 0. Machine & user facts (verified)

- Fedora 44, Hyprland 0.56.2, Quickshell 0.3.2 (`qs`), one monitor eDP-1 1920x1080 @165Hz, scale 1, NVIDIA RTX 4050 + Intel iGPU, 16 GB RAM.
- Base dotfiles: **JaKooLit Fedora-Hyprland** (`~/.config/hypr/hyprland.conf` sources `configs/*` then `UserConfigs/*`). Current bar: waybar + `waybar-weather`; notifications: swaync; wallpaper daemon: `awww` (swww fork, `awww img ...`); `qs -c overview` already runs; hypridle runs; SDDM theme "silent" (Qt6).
- Terminal: kitty. Shell prompt: starship. Editor: nvim. File manager today: thunar (we add **superfile** `spf` v1.5.0, already installed, config at `~/.config/superfile`). Browser: Zen (flatpak, profile `~/.config/zen/z4vyrl25.Default (release)`). Spotify rpm + spicetify configured. btop, cava, playerctl, nmcli (NetworkManager), wlogout, rofi, cliphist, grim/slurp/swappy, magick (ImageMagick 7), ffmpeg, pw-play, numpy (system python3 = /usr/bin/python3) all present.
- Installed by us: fonts in `~/.local/share/fonts/overworld/` (see §6), Real-ESRGAN at `~/.local/bin/realesrgan-ncnn-vulkan` (models in `~/.local/opt/realesrgan/models`, works on the GPU: use `-n realesrgan-x4plus-anime -m ~/.local/opt/realesrgan/models`).
- Installed via sudo by the user: `kvantum` (`kvantummanager`), `papirus-icon-theme` (Papirus, Papirus-Dark, Papirus-Light in /usr/share/icons), `google-noto-serif-cjk-fonts` (+ the VF package; `google-noto-sans-cjk-fonts` also present). `papirus-folders` is NOT installed — if folder colours are wanted, copy Papirus into `~/.local/share/icons/` and run the upstream papirus-folders script against that copy (no sudo).
- GTK today: theme Flat-Remix-GTK-Blue-Dark, icons breeze, cursor Bibata-Modern-Ice, font "Noto Sans 10". Available in ~/.icons: Bibata-Modern-Ice, Flat-Remix-Blue-{Dark,Light}.
- Weather location: try IP geolocation (e.g. `https://ipapi.co/json/` or `http://ip-api.com/json/`); fallback **Kowloon, Hong Kong (22.3167, 114.1833)**; user override in `~/.config/overworld/config.json` → `{"weather":{"lat":..,"lon":..,"name":".."}}`. Forecast API: Open-Meteo (no key).

## 1. Hard safety rules (every agent)

1. **Never edit files under `~/.config/hypr/configs/`, `~/.config/hypr/UserConfigs/`, `~/.config/waybar`, `~/.config/swaync`, `~/.config/kitty`, etc. in place.** The theme is a *layer* that lives in this repo and is linked in by `scripts/install.sh`. The only permitted edits to JaKooLit files are the ones listed in §4 (one `source=` line + one `exec-once`), done by install.sh, idempotently, with a marker comment `# overworld`.
2. A full pre-theme backup exists at `~/hypr-backup-2026-10-29` (git repo, `restore.sh`). Do not modify it.
3. **No sudo.** If something truly needs root (SDDM theme install, dnf), write the command into `docs/SUDO-STEPS.md` and a script the user can run; never attempt it.
4. Do not kill or restart: `hermes-gateway.service`, the user's kitty windows, Zen, Hyprland itself. You MAY start/stop your own test processes (`qs -p …`, `qs -c overworld`). Do not stop waybar/swaync during development — test the shell on top of them; only `overworld on` (run by the user / QA at the end) swaps them.
5. Copyrighted art (novel/manga/anime images) is **never committed**: it goes in `assets/art/` or `assets/wallpapers/` (gitignored) and `assets/fetch-art.sh` must be able to re-download it. Public-domain assets (Wikimedia Commons scans, generated textures, synthesized sounds) may be committed with credits in `assets/CREDITS.md`.
6. Never fabricate quotes, sources, herb facts or API responses. If you cannot verify a line from the novel/anime, write an original in-character line and mark it `"source":"original"`.
7. Shells you spawn do not see Hyprland. Run `source ~/Projects/overworld-hyprland/scripts/dev-env.sh` first in each shell (gives `hyprctl`, `grim`, `qs`, `awww` access). Screenshot with `grim -o eDP-1 path.png` (or `grim -g "$(slurp)"` is NOT usable non-interactively — use `-g "x,y wxh"`).
8. Stay inside your file-ownership area (§3). If you need a change in another area, write the request to `docs/REQUESTS.md` (append, with your agent name) instead of editing.
9. Commit your own work with git when done (`git add <your paths> && git commit`), message prefixed with your agent name. Never `git add -A`, never force-push, never rewrite history.

## 2. The concept

**Title:** Overworld Hyprland — 薬屋のひとりごと / The Overworld Diaries, focused on **Maomao (猫猫)**.

**Premise.** The desktop is Maomao's workbench in the Rear Palace: paper, ink, herbs, lacquer, and the red seals of the inner court. UI surfaces are *things from that world* — a hanging scroll (panels), a medicine cabinet with labelled drawers (launcher), folded paper notes (notifications), a vermilion seal (focus/confirm/urgent accents), ink-wash (transitions). Two moods, switchable at runtime:

| mode | name | feel |
|---|---|---|
| `light` | Overworld (薬屋) | daytime workbench: rice-paper cream, sumi ink, Maomao's teal-green robe, herb greens, plum, a touch of vermilion seal and antique gold |
| `dark` | Inner Palace (後宮) | lacquer night: near-black lacquer browns, vermilion, antique gold, jade green, paper-cream text |

**Visual reference the user supplied** (qxb3 "ink" rice, see `.refs/qxb3-ink` and `docs/reference-ink.png`): sumi-e silhouette wallpaper, beige paper ground, **widgets as framed cards with a black title bar containing a centered title and three small square "window dots"**, monospace-ish type, cava bars, a transparent music card with album art, big weather card, calendar, fastfetch. **Keep that structure (title-bar framed cards on the desktop) but make it Overworld:** title bars become lacquer/ink with a tiny red seal at the right instead of plain squares; frames get a 1px inner hairline (double-rule like a scroll mount); paper texture under the cards; CJK titles with Latin subtitles.

**Signature gesture:** the **red seal stamp (印)** — a small square vermilion seal with a white glyph (薬 / 猫 / 印) marks the focused workspace, the active window border corner (not possible in Hyprland; use border colour instead), the confirm button, and critical notifications ("imperial order" red-sealed note). Soft **ink-spread** animations everywhere (slow, eased; nothing bounces).

**Character art focus:** Maomao. Priority of sources: light-novel illustrations (Touko Shino / しのとうこ, Hero Bunko / Shufunotomo; J-Novel Club EN) → manga (Nekokurage, Big Gangan edition) → anime (TOHO animation / OLM) stills & key visuals. The user accepts AI-upscaled novel scans with art-directed crops or decorated borders to fit 1920x1080; wide anime key visuals are the backup set. Multiple wallpapers per mode, user switches with a picker.

**Typography roles** (fonts already installed, see §6): CJK display = *Ma Shan Zheng* (brush, titles/seals) and *ZCOOL XiaoWei* (elegant display); CJK body = *LXGW WenKai*; JP flavour = *Shippori Mincho B1* / *Yuji Syuku* (sparingly, e.g. 薬屋のひとりごと wordmark); Latin display serif = *Cormorant Garamond*; Latin body = *EB Garamond* for quotes, *Noto Sans* for UI text; mono = *JetBrainsMono Nerd Font* (icons come from Nerd Font glyphs). Never render meaning in CJK only — a Latin label or tooltip must carry the meaning.

**Text content:** rotating quotes from `quotes/quotes.json` (Dhammapada, Analects, short series lines, and the user's unattributed line "Do things out of love, not for love"); "Herb/Poison of the day" from `quotes/herbs.json`; clock shows the traditional two-hour period (時辰: 子23–1 丑1–3 寅3–5 卯5–7 辰7–9 巳9–11 午11–13 未13–15 申15–17 酉17–19 戌19–21 亥21–23); workspaces labelled 一 二 三 四 五 六 七 八 九 十.

**Motion:** slow and soft. Hyprland beziers (names to use everywhere): `ink = 0.22, 1, 0.36, 1` (ease-out quint), `brush = 0.65, 0, 0.35, 1` (ease-in-out), `drift = 0.33, 1, 0.68, 1`. Windows open 6–7 (×100ms) with `ink`, popin 85%; workspaces slide with `drift` 8; fade 5; layers `slide`/`fade` 5–6; border angle animation **off** (no rainbow borders). In QML use 350–600 ms with `Easing.OutQuint` / `OutCubic`; opacity + 8–16 px translate; never spring/overshoot.

## 3. Repository layout and ownership

Repo: `~/Projects/overworld-hyprland` (git). `.refs/` has `dots-hyprland` (end-4, Quickshell "ii" config — read `dots/.config/quickshell/ii` for patterns) and `qxb3-ink` (AGS; read its scss for the card style). Both are read-only inspiration; **do not copy files wholesale, do not copy their art**.

```
BRIEF.md                 this file (orchestrator)
docs/DESIGN.md           design system (design-director)
docs/REQUESTS.md         cross-agent requests (anyone appends)
docs/SUDO-STEPS.md       things the user must run with sudo (anyone appends)
docs/KEYBINDS.md         final keybind table (hyprland-engineer)
tokens/tokens.json       single source of truth for both modes (design-director)
tokens/build.py          generates tokens/out/{light,dark}/* (design-director)
tokens/out/<mode>/       hyprland-colors.conf, kitty.conf, rofi-colors.rasi, gtk.css, colors.qml? (no—QML reads tokens.json), superfile-theme.toml, cava.conf-snippet, btop.theme, starship-colors, spicetify color.ini, zen.css vars, nvim lua palette, fastfetch palette, waybar? (no waybar)
quickshell/              Quickshell config root (symlinked to ~/.config/quickshell/overworld)
  shell.qml              entry (qs-core)
  Common/                Theme singleton, Fonts, Motion, PaperPanel, TitleBar, Seal, InkButton, InkDivider (design-director writes v1; qs-core may extend, qs-widgets may NOT edit — request instead)
  Services/              ThemeState, HyprlandState, NetworkService(nmcli), WeatherService, QuoteService, HerbService, BrewTimer (qs-core; qs-widgets may ADD new files here but not edit existing)
  Bar/  Launcher/  Notifications/  Network/  Power/  Wallpapers/  Osd/     (qs-core)
  Widgets/               desktop widget layer: DesktopWidgets.qml + Music/ Weather/ Calendar/ SysInfo/ HerbOfDay/ BrewTimer/ Quote/ Cava/  (qs-widgets)
hypr/                    overworld.conf (entry), on.conf, off.conf, animations.conf, decorations.conf, rules.conf, keybinds.conf, hyprlock.conf, hypridle.conf  (hyprland-engineer)
sddm/overworld/         SDDM Qt6 theme (hyprland-engineer)
apps/                    kitty/ rofi/ superfile/ fastfetch/ cava/ btop/ gtk/ qt/ kvantum/ icons/ cursor/ starship/ spicetify/ zen/ nvim/ wlogout/ swappy/ + apps/install.sh + apps/apply-mode.sh  (app-theming)
scripts/overworld       the CLI (hyprland-engineer): on|off|status|light|dark|toggle|wallpaper (next|prev|pick|<path>)|reload|session-start
scripts/install.sh       links everything into ~/.config (hyprland-engineer), calls apps/install.sh
scripts/uninstall.sh     reverses install.sh (hyprland-engineer)
scripts/make-wallpapers.sh, scripts/make-sounds.py   (art-curator)
assets/fetch-art.sh      downloads copyrighted art into assets/art (art-curator)
assets/CREDITS.md        every asset → source, author, licence (art-curator; others append)
assets/pd/               public-domain scans/textures (design-director: textures; art-curator: plates)
assets/sounds/           synthesized wood-block / guqin cues, .wav/.ogg (art-curator)
assets/art/, assets/wallpapers/{light,dark}/   gitignored
quotes/quotes.json, quotes/herbs.json           (art-curator)
qa/                      QA reports and screenshots (qa-reviewer)
```

## 4. Runtime contract (how the pieces talk)

- **State dir:** `~/.config/overworld/` — `mode` (file containing `light` or `dark`), `enabled` (exists ⇢ theme on), `config.json` (user overrides), `wallpaper-<mode>` (path of current wallpaper per mode), `active.conf` (symlink → `hypr/on.conf` or `hypr/off.conf`), `colors.conf` (symlink → `tokens/out/<mode>/hyprland-colors.conf`).
- **Hyprland hook (the only JaKooLit edits, made by install.sh):** append to `~/.config/hypr/hyprland.conf`: `source = ~/.config/hypr/overworld.conf # overworld` where `~/.config/hypr/overworld.conf` → repo `hypr/overworld.conf`, which does `source = ~/.config/overworld/active.conf`. `on.conf` sources colors.conf, decorations, animations, rules, keybinds, and `exec-once = ~/.local/bin/overworld session-start` (which, if enabled, waits for and stops waybar/swaync/waybar-weather, starts `qs -c overworld`, sets wallpaper via awww, plays the login cue). `overworld off` flips the symlink, `hyprctl reload`, stops qs, restarts waybar+swaync — the user's old desktop must come back fully without logout.
- **Theme mode switch:** `overworld light|dark|toggle` writes `mode`, re-links `colors.conf`, `hyprctl reload`, sets the mode's wallpaper with awww (transition `--transition-type grow --transition-duration 1.2 --transition-fps 165 --transition-bezier .22,1,.36,1`), then runs `apps/apply-mode.sh <mode>` (kitty `kitty @ --to unix:... set-colors`/symlink, gsettings color-scheme, gtk.css symlink, Kvantum, spicetify apply, superfile theme, btop, zen css…). Quickshell watches the `mode` file (FileView watchChanges / Process inotify) and cross-fades its palette in ≤600 ms.
- **Quickshell IPC** (qs-core implements; hyprland-engineer binds keys): `qs -c overworld ipc call <target> <fn>` with targets/functions:
  `launcher toggle`, `network toggle`, `power toggle`, `wallpapers toggle`, `widgets toggle`, `notifications toggle` (notification centre), `notifications dnd`, `theme toggle`, `theme set <light|dark>`, `brew start <minutes>`, `brew toggle`, `osd volume|brightness`.
- **Default keybinds (reserve these; hyprland-engineer may add more, must document in docs/KEYBINDS.md; must `unbind` JaKooLit conflicts inside on.conf only):** SUPER+Space launcher · SUPER+N network panel · SUPER+Escape power menu · SUPER+W wallpaper picker · SUPER+T theme toggle · SUPER+G toggle desktop widgets · SUPER+I notification centre · SUPER+E superfile in kitty (`kitty --class spf -e spf`) · SUPER+B brew timer · SUPER+Return kitty (keep JaKooLit's).
- **Fonts** are referenced by family name only (installed system-wide for this user). **Icons**: Nerd Font glyphs (JetBrainsMono Nerd Font) for status; Papirus (when installed) for app icons via `Quickshell.Io`/`DesktopEntries`.
- **Sounds**: `assets/sounds/{login,notify,notify-urgent,brew-done,seal}.wav` played with `pw-play` (never block the UI; respect `config.json → {"sounds":false}`).

## 5. Feature checklist (all accepted by the user)

Shell (Quickshell replaces waybar + swaync while enabled):
1. Top bar: workspaces as 一二三… with red-seal active marker; window title; clock `HH:MM · 午 (11–13)` + date; tray; wifi/bt/battery/volume chips; mode toggle button; notification bell; a tiny 猫 glyph button that opens the launcher.
2. Launcher = **medicine cabinet**: grid of labelled wooden drawers (apps), search drawer at top, fuzzy search, keyboard nav, categories as cabinet columns; launch via DesktopEntries.
3. Notifications: paper-note popups (slide+fade, `ink` easing), urgent = red-sealed "imperial order"; notification centre panel with history, DND toggle. Must implement the D-Bus daemon via `Quickshell.Services.Notifications` (so swaync must not run simultaneously).
4. **Network panel**: lists Wi-Fi networks from `nmcli -t -f ...`, signal bars, security icon, connected state, click → password field (PasswordEcho) → `nmcli dev wifi connect <ssid> password <pw>`; disconnect; rescan; airplane toggle; wired status; VPN list (`nmcli con show`). Show errors from nmcli inline.
5. Power menu (lock/logout/suspend/reboot/shutdown) themed; lock = hyprlock.
6. Wallpaper picker: scroll-style panel with thumbnails from `assets/wallpapers/<mode>`, sets via awww, remembers per mode.
7. OSD for volume/brightness (ink bar).
8. Desktop widget layer (layer `bottom`, click-through where empty, toggle SUPER+G): Music card (transparent, album cover from MPRIS artUrl, title/artist, prev/play/next, progress bar, like the reference), Weather card (Open-Meteo, big temperature, condition, precipitation/humidity/wind, 24h bars like the reference), Calendar card, SysInfo/fastfetch card (distro, kernel, uptime, packages, shell, WM, CPU/RAM/disk bars), Cava card (spawn `cava` with raw output), Quote card, Herb-of-the-day card, Brew timer card (focus timer "Brewing medicine", 25/5 default, wood-block cue on finish).
9. Theme toggle light/dark with cross-fade.

System:
10. Hyprland: soft/slow animations, decorations (rounding 6–8, 1–2px border, mode colours, blur for layers, dim inactive 0.05, shadows soft), layer rules for qs layers, window rules (spf/floating pickers), keybinds.
11. hyprlock: Maomao art per mode, clock with 時辰, date, quote, password field as a seal/scroll, user avatar optional.
12. hypridle: dim → lock → dpms, sane laptop timings.
13. SDDM Qt6 theme matching (installed by the user with sudo from `docs/SUDO-STEPS.md`).
14. wlogout themed as fallback; Zen userChrome; spicetify; nvim colourscheme; btop; cava; fastfetch (Maomao image via kitty icat/ `logo type: kitty-direct`, fallback ascii); starship prompt with herb/seal glyphs; kitty themes; GTK3/4 + Kvantum/qt6ct + icons (Papirus with folder colour) + cursor; superfile theme + config + hotkeys.
15. `overworld` CLI, install/uninstall, docs/README with screenshots, credits, fetch-art script.
16. Sounds: login cue (short guqin-like pluck), notify (soft wood-block), urgent (two blocks), brew-done (three ascending plucks).

## 6. Fonts installed (family names)

`Ma Shan Zheng`, `ZCOOL XiaoWei`, `Long Cang`, `LXGW WenKai` (+ Light, Medium), `Shippori Mincho B1`, `Yuji Syuku`, `Cormorant Garamond` (variable), `EB Garamond` (variable), `JetBrainsMono Nerd Font` (+ Mono/Propo), `Noto Sans CJK SC/JP…`, `Noto Serif CJK` (variable), `Noto Sans`, `FantasqueSansM Nerd Font`.

## 7. Verification standard

Every engineer agent must actually run what they build: `qs -p <dir>` or `qs -c overworld` in the background, take a `grim` screenshot into `qa/screenshots/<agent>-<what>.png`, look at it (vision tool), fix, and report the real screenshot paths. Config-only agents (hyprland, apps) must validate syntax (`hyprctl reload` output has no errors — run it only after writing a *complete* file; `kitty --config <file> --debug-config`, `rofi -dump-theme`, `spf --help`, `python3 -c tomllib`, `qmllint` if present) and screenshot the real apps where feasible. Report what was verified and what was not.
