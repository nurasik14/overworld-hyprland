# Desktop widgets (`quickshell/Widgets/`) — qs-widgets

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `overworld on` and off with `overworld off`
> (the stock desktop returns in about 5 s, no logout); `overworld status` shows which state is active.
> The desktop widgets exist only while the theme is on. `SUPER+G` hides or shows them without turning the theme off. How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

The desktop widget layer: eight framed paper cards on the wallpaper (layer `bottom`, click-through where
empty), toggled with `widgets toggle` (SUPER+G). Every card is a `WidgetCard` (= `Common/PaperPanel` +
show/hide animation) placed at the exact 1920×1080 slot of `docs/DESIGN.md` §7.

Screenshots (dev session, user's waybar + qs-core's dev bar stacked on top, so the top title bars are
covered there — in the real shell the bar is 0–36 and the cards start at y 60):
`qa/screenshots/qs-widgets-light.png`, `qa/screenshots/qs-widgets-dark.png` (Music card in demo mode:
no MPRIS player was running). Screenshots are not committed (they contain the copyrighted wallpaper).

## Layout

```
quickshell/Widgets/
  DesktopWidgets.qml        Variants{Quickshell.screens} → PanelWindow per screen, WlrLayer.Bottom,
                            namespace overworld-widgets, anchors all edges, exclusionMode Ignore,
                            color transparent, mask = union of the visible cards' rects
  WidgetCard.qml            PaperPanel + WidgetsState.visible → opacity 0↔1 + 10 px rise, 450 ms OutQuint,
                            40 ms stagger per `index` (reading order), reduced_motion → 0 ms / no rise
  Weather/WeatherCard.qml   Music/MusicCard.qml   Calendar/CalendarCard.qml   SysInfo/SysInfoCard.qml
  Cava/CavaCard.qml         Quote/QuoteCard.qml   HerbOfDay/HerbCard.qml      BrewTimer/BrewTimerCard.qml
  Services/                 pragma Singleton services (auto-registered; no qmldir):
    ApoConfig.qml           ~/.config/overworld/config.json view: sounds, reduced_motion, weather{lat,lon,name},
                            brew{work,break}; stateDir / cacheDir / scriptDir
    WidgetsState.qml        visible (persisted) + demo flag + IpcHandler "widgets"
    WeatherService.qml      + weather-fetch.py        MusicService.qml (MPRIS)      SysInfoService.qml + sysinfo.py
    QuoteService.qml        HerbService.qml           BrewTimer.qml (IpcHandler "brew")   CavaService.qml
  preview/                  standalone harness: shell.qml + symlinks Common → ../../Common, Widgets → ..
    shot.sh                 restart preview + screenshot helper (see "Running the preview")
```

| card | slot (x y w h) | title · subtitle · seal | data |
|---|---|---|---|
| Weather | 24 60 460 300 | 天气 · WEATHER · 印 | Open-Meteo via `weather-fetch.py` |
| Calendar | 1516 60 380 260 | 日历 · CALENDAR · 印 | JS Date |
| Music | 24 376 300 420 | 音乐 · *player identity* · 猫 | `Quickshell.Services.Mpris` |
| SysInfo | 1476 336 420 300 | 系统 · *user@host* · 印 | `sysinfo.py` |
| Brew timer | 24 812 300 160 | 煎 · BREW · 药 | `BrewTimer` singleton |
| Cava | 1536 652 360 180 | 声 · CAVA · 印 | `cava -p ~/.cache/overworld/cava.conf` |
| Herb of the day | 770 812 380 220 (centred: w/2−190) | 药 · HERB OF THE DAY · 药 | `quotes/herbs.json` |
| Quote | 1436 848 460 120 | 言 · QUOTE · 印 | `quotes/quotes.json` |

Right/bottom slots are re-based on other resolutions: `x = width − (1920 − x)`, `y = height − (1080 − y)`.

## Cards

- **Weather** — glyph + temperature (Cormorant 56), city, local time at the location, condition word
  (accent), `Precipitation / Humidity / Wind` mono lines, "feels N°", 24-bar hourly strip (ink bars, midnight
  bar dimmed, hover → `14:00 · 26° · 40% rain`). Error state "Weather unavailable · 雲" + Retry.
  WMO `weather_code` → Nerd `nf-md-weather_*` glyph + word table lives in `WeatherService.glyphFor/wordFor`.
- **Music** — translucent paper (`PaperPanel.transparent`), cover from `trackArtUrl` (rounded 4, soft shadow;
  paper square with 音 when no art), title / artist, prev · play-pause · next, seekable ink progress line with a
  seal knob (when `canSeek && positionSupported`), elapsed / length. Player: spotify first, else any playing
  player, else the first; `playerctld` is ignored. Position is polled each second while playing
  (`player.positionChanged()` + re-read) and also follows the player's own `positionChanged` signal.
  Empty state "靜 · Nothing playing" over a faint enso. **Demo**: `APO_WIDGETS_DEMO=1` or
  `widgets demo on` shows a mocked track (cover = `assets/art/portrait-maomao.png`) when no player exists.
- **Calendar** — Mon–Sun grid (LXGW WenKai), weekends in `accent2`, out-of-month days faded, today = seal
  behind the number, header `October 2026 · 十月`, previous / today / next buttons.
- **SysInfo** — Maomao portrait on the left (`assets/art/fastfetch-maomao[-dark].png`, column collapses when the
  file is missing); rows OS · Kernel · Uptime · Packages · Shell · WM · Terminal (mono 12, nf-md glyphs); ink bars
  CPU (two `/proc/stat` samples 350 ms apart) · RAM (`/proc/meminfo`) · Disk (`/home` if a mount, else `/`).
  Bars refresh every 5 s only while the layer is visible; static facts every 10 min; package counts cached
  10 min in `~/.cache/overworld/packages`.
- **Cava** — writes `~/.cache/overworld/cava.conf` at startup (`raw`, ascii 0–100, 24 bars, 30 fps, autosens,
  `;` delimiter) and spawns `cava -p`; 24 ink bars with 2 px rounded tops, 120 ms height smoothing; idle
  (≈1.5 s of silence) rests the bars at 2 px with a "silence · 静" caption. The process is stopped while the
  layer is hidden and restarted when shown. "cava not running" if the binary fails.
- **Quote** — random entry every 10 min and on click. EB Garamond italic (18/16/15 px by length), attribution
  right-aligned (empty for the user's line "Do things out of love, not for love"), `cjk` original above when
  present. Falls back to the user's line if `quotes.json` is unreadable.
- **Herb of the day** — `herbs[dayOfYear % n]`; name_cjk (brush font, auto-switches to the JP brush for 薬/kana),
  kind badge (草 herb = success, 毒 poison = seal, both = both), name_en, reading, fact (2 lines), Maomao's note
  (EB Garamond italic, 猫 seal). Plate (`assets/pd/plates/*.webp`, black-ink RGBA mask) tinted with
  `Theme.text` via `MultiEffect.colorization`; the image column collapses when `plate` is null or the file is
  missing. Left click → next herb, right click → previous.
- **Brew timer** — brew 25 / rest 5 by default; both lengths are any duration (`25`, `50m`, `1h30`, `90s`, `1:30`,
  rest `0` = none; grammar in `Services/duration.js`, mirrored by `brew_parse` in `scripts/overworld`), saved in
  config `brew.work` / `brew.break`. States `idle | working | breaking | paused`; ink ring (`QtQuick.Shapes` arc,
  vermilion for work, celadon for rest) around `mm:ss` (`h:mm:ss` from an hour up), label 煎药 · BREWING/RESTING,
  Start/Resume/Pause (primary when idle) + reset + pencil (set) icons.
  Setting: click the clock / pencil, or `SUPER+SHIFT+B` → the brew dialog (`quickshell/Brew/BrewDialog.qml`, layer
  `overworld-brew`: two fields + preset chips, ⏎ save + start, ↑/↓ ±1 min); while idle, scroll on the clock =
  brew ±1 min and on the "brew · rest" line = rest ±1 min (Shift ±5). Every save runs `overworld brew set`.
  On finish: a sound (`brew.sound`: `minecraft` = brewing-stand `brew1/2.ogg` when the brew is done and `drink.ogg`
  when the rest is over, fetched by `scripts/fetch-minecraft-sounds.sh` into the gitignored
  `assets/sounds/minecraft/`; `classic` or missing files = `assets/sounds/brew-done.wav`; nothing when
  `config.json {"sounds": false}`) + `notify-send -a Overworld "Medicine is ready" "50 min brewed. Rest for 10 min."`;
  a finished brew rolls into the rest (or back to idle when rest is 0), a finished rest returns to idle.

## IPC

```
qs -c overworld ipc call widgets toggle | reveal | hide      # persisted in ~/.config/overworld/widgets-visible
#   (NB `widgets show` is swallowed by the qs CLI — `show` collides with `qs ipc show` — so the alias is `reveal`)
qs -c overworld ipc call widgets demo on|off                 # mocked music card when no player
qs -c overworld ipc call widgets status                      # "visible (demo)"
qs -c overworld ipc call brew start 50m | startWith 50m 10m | toggle | pause | reset | add 5m | open | sound brew|rest | status | settings
# CLI: overworld brew help   ·   preview on a headless output: quickshell/Brew/preview/shell.qml
```
(`-p <preview dir>` instead of `-c overworld` when talking to the preview instance.)

## State, caches, config

| path | what |
|---|---|
| `~/.config/overworld/widgets-visible` | `true` / `false` — read at startup, written by show/hide/toggle |
| `~/.config/overworld/config.json` | `weather.{lat,lon,name}`, `brew.{work,break}`, `sounds`, `reduced_motion` (watched) |
| `~/.cache/overworld/weather.json` | last good forecast (served with `stale: true` when offline / API down) |
| `~/.cache/overworld/packages` | package count text, 10 min |
| `~/.cache/overworld/cava.conf` | generated cava config |

Weather location order (`weather-fetch.py`): config → `https://ipapi.co/json/` → `http://ip-api.com/json/` →
Kowloon 22.3167, 114.1833. An IP result whose time-zone differs from `/etc/localtime` is rejected (VPN exit
node abroad); on this machine the VPN exits in Singapore, so the card shows Kowloon with
`source: "fallback (timezone mismatch …)"`. Refresh every 30 min; the cache is read synchronously at startup.

## Click-through

The PanelWindow `mask` is a `Region` whose children are `Region { item: <card> }` for every card (null while
the layer is hidden, which makes the whole layer click-through). Everything outside the eight rectangles
reaches the desktop; inside, the cards receive hover/click (weather strip hover, music seek, quote/herb click).
Verified by construction only — no synthetic-input tool (ydotool/wtype) is installed to click through
programmatically.

## Running the preview

```
source scripts/dev-env.sh
qs -p quickshell/Widgets/preview                    # standalone layer (Theme resolves the repo via shellDir/../../..)
APO_WIDGETS_DEMO=1 qs -p quickshell/Widgets/preview # with the mocked music card
quickshell/Widgets/preview/shot.sh <name> [VAR=val] # restart + capture qa/screenshots/qs-widgets-<name>.png
```
`preview/shell.qml` is a `ShellRoot { DesktopWidgets {} }`; `preview/Common` and `preview/Widgets` are symlinks so
`import qs.Common` / `import qs.Widgets…` resolve with the preview directory as config root (a relative
`import "../"` would not give singleton instances — DESIGN.md §12).

`shot.sh` picks an *explicit* empty workspace id (Hyprland's `workspace empty` jumps to a populated workspace
when the current one is already empty), verifies the active workspace has 0 windows right before `grim`
(never captures the user's windows), hides qs-core's copy of the layer through its IPC for the capture and
restores it (and writes `widgets-visible = true` afterwards), then switches back. When the user is actively
switching workspaces the capture is skipped rather than forced.

Known harmless log lines: `quickshell.dbus.properties … playerctld … NoActivePlayer` (Quickshell's Mpris module
probing the playerctld bus when no player is controlled) and `kf.iconthemes: Icon theme … not found` (Qt
platform theme, not ours). The layer itself produces no QML warnings.

## Decisions / gaps

- Both `qs -c overworld` (qs-core's shell, which already does `DesktopWidgets {}`) and the preview can run at
  once; they are independent instances with independent `WidgetsState` (the persisted file is shared).
- Music card: no MPRIS player was available during QA (Spotify may not be started by agents), so the committed
  screenshots use the demo track; the real path (player pick, art, controls, seek) is wired against the
  documented `MprisPlayer` API but was not exercised with a live player.
- Weather "Precipitation" shows the hourly `precipitation_probability` (%) for the current hour, matching the
  reference card; `current.precipitation` (mm) is exposed on the service but not shown.
- Herb names in Traditional Chinese (e.g. 烏頭) fall back glyph-by-glyph from Ma Shan Zheng to Noto Sans CJK —
  acceptable for a decorative title; the Latin name carries the meaning.
- Brew: IPC `start` takes any duration (bare number = minutes). Nothing is left running after QA (`brew reset` verified).

## Per-card switches, dragging, transparency (added after user feedback)

- **Bar chip 󰕮** (right side, before the sun/moon): click → *Desk widgets* menu: `全 All widgets` (= SUPER+G) and one
  seal checkbox per card, plus *Reset positions*. Middle-click the chip = all on/off. Click outside or Esc closes.
  State: `~/.config/overworld/widgets-hidden.json` (list of switched-off card ids).
  IPC: `qs -c overworld ipc call widgets card <weather|music|calendar|sysinfo|cava|quote|herb|brew>` toggles one,
  `widgets cards` lists them, `widgets menu` opens the menu.
- **Dragging:** grab a card's lacquer title bar. While a drag is active the widget layer takes pointer input on the
  whole screen (`WidgetsState.dragging` adds a full-screen region to the input mask), so a fast flick can no longer
  leave the card's own input region and drop it. Double-click the title bar = back to its slot.
- **Transparency:** desktop cards fill at 72 % (`WidgetsState.cardOpacity`; text, title bars and seals stay opaque;
  the blurred shadow is dropped below 85 % so it doesn't smudge through). Override in
  `~/.config/overworld/config.json` → `{"widgets": {"opacity": 0.6}}` (0.2–1.0, applied live).
