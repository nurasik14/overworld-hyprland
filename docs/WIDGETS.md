# Desktop widgets (`quickshell/Widgets/`) — qs-widgets

The desktop widget layer: eight **Minecraft objects** on the wallpaper (layer `bottom`, namespace `overworld-widgets`,
click-through where empty). Every card is a `WidgetCard` = `Common/McPanel` (the real GUI panel with the dark-grey title,
centre filled at `Theme.widgetOpacity`, config `widgets.opacity`, default 0.72) + show/hide fade + drag handle. Everything is authored
in GUI px (`Theme.px`, default 2 × at 1920×1080) with the design system's text (`McText`), buttons, slots, progress bars and
sprites; nothing is re-implemented locally except the few widget-specific pieces listed under *Layout*.

Toggle with `widgets toggle` (SUPER+G); the bar chip menu (`Bar/WidgetsMenu.qml`, qs-core) switches single cards.
How the theme switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

## Layout (1920×1080; bar 0–36; the bottom-centre ~110 px stay free for the HUD)

```
quickshell/Widgets/
  DesktopWidgets.qml     Variants{Quickshell.screens} → PanelWindow per screen, WlrLayer.Bottom, anchors all edges,
                         exclusionMode Ignore, transparent, mask = union of the visible cards (+ full-screen while dragging)
  WidgetLayout.qml       the eight cards on their slots (an Item: also used by the offscreen render harness)
  WidgetCard.qml         McPanel + fade/rise 250 ms OutQuad (stagger 40 ms × index) + title-bar drag + double-click reset
  BlockPatch.qml         a square cut out of a block texture, 1 texel = 1 GUI px (weather columns, note-block cells)
  KeyedSprite.qml        sprite drawn additively in the game (sun / moon): black → transparent (shaders/blackkey.frag.qsb)
  Weather/  WeatherCard.qml  SkyWindow.qml        Music/  MusicCard.qml        Calendar/  CalendarCard.qml
  SysInfo/  SysInfoCard.qml                       Cava/   CavaCard.qml         Quote/     QuoteCard.qml
  BlockOfDay/  BlockOfDayCard.qml                 BrewTimer/  BrewTimerCard.qml
  Services/  (pragma Singleton, auto-registered, no qmldir)
    WidgetsConfig.qml   config.json view: sounds, reduced_motion, brew.{work,break}; stateDir / cacheDir / scriptDir   (was ApoConfig)
    WidgetsState.qml    visible (persisted), demo, positions, per-card switches, cardOpacity, IpcHandler "widgets"
    WeatherService.qml + weather-fetch.py    MusicService.qml (MPRIS)    SysInfoService.qml + sysinfo.py
    QuoteService.qml    BlockOfDayService.qml    BrewTimer.qml (IpcHandler "brew")    CavaService.qml    duration.js
  assets/weather/*.png  gen_weather_icons.py    original 16×16 pixel icons (sun moon partly_day partly_night cloud fog rain snow sleet thunder)
  shaders/blackkey.frag(.qsb)    rebuild: /usr/lib64/qt6/bin/qsb --qt6 -o shaders/blackkey.frag.qsb shaders/blackkey.frag
  preview/  shell.qml (the layer) · render.qml (offscreen) · skies.qml (all sky conditions) · selftest.qml · shot.sh
```

| card | default slot (x y, px) | size (GUI px) | what it is |
|---|---|---|---|
| **Weather** | 24 60 | 190×150 | sky window + 24 h columns of blocks |
| **Jukebox** | 24 372 | 190×106 | MPRIS player as a jukebox, record, item frame, action bar, XP bar |
| **Brewing Stand** | 24 596 | 190×84 | the brew timer as the brewing GUI |
| **Block of the Day** | 24 776 | 190×138 | item frame + facts + tip (`quotes/blocks-of-the-day.json`) |
| **Clock & Calendar** | `w−404` 60 | 190×156 | the real clock item + "Day N" + month of slots |
| **System** | `w−404` 384 | 190×148 | F3 debug text + CPU/RAM/disk boss bars |
| **Note Block** | `w−404` 692 | 190×82 | cava equaliser built from note blocks / redstone lamps |
| **Sign** | `w−404` 868 | 190×78 | oak sign (`quotes/quotes.json`) + pulsing splash |

`WidgetLayout` builds the slots as stacks in GUI px (left column 12 GUI px from the left edge, right column flush to 12 GUI px from
the right edge, first card at 30 GUI px, 6 GUI px between cards), so they follow the GUI scale (`gui_scale`) and the screen width; the
pixel numbers above are for 1920×1080 at GUI scale 2, where every card is 380 px wide. The left column ends at y 1052, the right at y
1024: the HUD area at the bottom centre stays free. Verified renders at GUI 2 and GUI 1 (`OW_GUI=1`).

## Cards

- **Weather → sky window.** `SkyWindow` is a framed window (oak planks) onto the sky at the weather's location: sky colour by
  condition and day/night, the **sun** (`environment/celestial/sun`) or the **moon with its real phase**
  (`environment/celestial/moon/<phase>`, synodic month from the 2000-01-06 new moon) travelling its arc by the *local* hour,
  drifting pixel clouds, the game's own `environment/rain` / `snow` textures falling in tick steps, lightning flashes for
  thunder, fog bands, stars on clear nights, a grass (snow-capped when snowing) strip. Right of it: the big temperature
  (`McText units: 3`), the condition with a pixel icon (`assets/weather/*.png`: sun, moon, partly cloudy day/night, cloud, fog,
  rain, snow, sleet, thunder — original art), Rain / Humidity / Wind, and below the window the **next 24 hours as stacked blocks**:
  column height = temperature (1–6 blocks), block = condition — *sand* clear day, *lapis* clear night, *sandstone* / *blue wool*
  partly cloudy, *light-grey wool* overcast, *smooth stone* fog, *water* rain, *snow block*, *packed ice* sleet, *gold block*
  thunder. Hover a column: `14:00 · 26° · Light rain · 40%`. Error state: "Weather unavailable" + Retry.
  Location: `config.json weather.{lat,lon,name}` → IP geolocation (ipapi.co, ip-api.com; rejected when its time-zone differs from
  `/etc/localtime`, i.e. a VPN exit) → Kowloon 22.3167, 114.1833. Refresh every 30 min; the cache is read synchronously at startup.
- **Music → Jukebox.** Jukebox block icon and a **spinning music disc** (a record picked from the track title, rotated in 7.5° steps
  on the 20 TPS clock while playing), the **album art in an item frame** (sampled down to 52×52 texels like a map), elapsed /
  length, **prev · play/pause · next** as small Minecraft buttons, the action-bar line **"Now Playing: Artist - Title" in the
  game's rainbow colour** (scrolls on the tick when too long) and an **XP-style progress bar** (click/drag to seek when the player
  allows it). Player: spotify first, else any playing player, else the first; `playerctld` ignored; position polled each second.
  Empty state: idle jukebox, "Nothing playing". Demo (`OW_WIDGETS_DEMO=1` / `widgets demo on`) shows a mocked track when no
  player exists. The buttons are wired to `MprisPlayer` but were never pressed during development (BRIEF §1.1).
- **Calendar → clock + map.** The real **`item/clock_00…63`** animation frames: frame 0 is noon, 32 midnight, chosen with the game's
  own celestial-angle formula `(2d + (0.5 − cos(πd)/2))/3`, `d = frac(dayTime/24000 − 0.25)`, `dayTime 0 = 06:00`; refreshed every
  10 s. "**Day N**" = day of the year, the time and the weekday, month arrows (click the month name = back to today), the month
  as a grid of inventory-style slots (Monday first), weekends in yellow like stack counts, **today inside the hotbar selection
  frame** (`hud/hotbar_selection`, nine-sliced with the 4 px border).
- **SysInfo → F3.** The fastfetch facts (name, user@host, OS, uptime, kernel, packages, shell + terminal, WM) as F3 text: white
  Minecraft text with the grey hard shadow on translucent `#90505050` rows, one 9 GUI px row per line, left aligned like the game;
  a grass block where the Maomao picture was; CPU, RAM and disk as **boss bars** (green < 70 %, yellow < 90 %, red above) with the
  value in the title. CPU from two `/proc/stat` samples, RAM `/proc/meminfo`, disk `/home` mount else `/`; bars refresh every 5 s only
  while the card is shown, static facts every 10 min (package count cached 10 min in `~/.cache/overworld/packages`).
- **Cava → note-block equaliser.** `~/.cache/overworld/cava.conf` is written at startup (raw, ascii 0–100, 24 bars, 30 fps) and
  `cava -p` runs **only while the card is shown** (layer visible *and* this card on). 24 columns × 7 rows of 6×6 GUI px block patches:
  low rows note blocks, upper rows lit redstone lamps, unlit cells dark; stacks fall a row per tick; each column's **peak is a
  note particle** (`particle/note`, tinted with the game's note colour for that pitch) that holds 8 ticks then sinks. ≈1.5 s of
  silence = dark grid + "Silence…"; "cava not running" if the binary fails.
- **Quote → sign + splash.** An oak sign: the real `entity/signs/oak` front face tiled at 1 texel = 1 GUI px, black sign lettering,
  message from `quotes/quotes.json` (attribution right-aligned), and the **yellow pulsing splash** (`McSplash`, the title screen's
  formula) on the card's top-right corner, text from `quotes/splashes.json` (seasonal entries only inside their date range, preferred
  there) **plus Mojang's `assets/mc/texts/splashes.txt` when that file exists** (read at runtime, one in four; never copied). Click the
  sign = next message + new splash; both rotate every 10 min.
- **Herb → Block / Mob of the day.** `BlockOfDayService` = `quotes/blocks-of-the-day.json` `entries[(dayOfYear + offset) % n]`, so the
  pick is deterministic by date (left click next, right click previous). Item frame with the texture (first animation frame, square
  crop; mobs show their spawn egg `item/<id>_spawn_egg`), name, kind (Block / Item / Mob / Biome), "Since <version>", the facts one
  at a time (rotate every 12 s, "Fact 1/3"), and the tip.
- **Brew → brewing stand.** Blaze-powder slot + fuel bar (`container/brewing_stand/fuel_length`, burns down with the phase), a well
  with the game's **bubbles** (heights 29/24/20/16/11/6/0, a step per 2 ticks while brewing) and the **arrow** filling downwards
  (`brew_progress`), the time (`mm:ss`, `h:mm:ss` from an hour), the summary line, Start/Pause/Resume + reset + pencil buttons, and
  three **bottle slots** (empty bottle → potion with glint as sessions complete, a stack count past three). Every BrewTimer feature
  is kept: any lengths (`25` · `50m` · `1h30` · `90s` · `1:30`, grammar `Services/duration.js`, mirrored by `brew_parse` in
  `scripts/overworld`), rest `0` = none, pencil / click the clock → brew dialog (`Brew/BrewDialog.qml`), scroll on the clock = brew
  ±1 min and on the "brew · rest" line = rest ±1 min (Shift ±5) while idle (saved after 700 ms through `overworld brew set`), sessions
  count, states `idle | working | breaking | paused`, finished brew rolls into the rest (or idle when rest is 0). On finish the
  sound id **`brew.done`** (brewing stand) or **`brew.drink`** (rest over) plays through `Theme.playSound` → `scripts/ow-sound`
  (silent when `config.json sounds:false`), `notify-send -a Overworld "Brewing complete" …`, and the events **`brew.start`**,
  **`brew.done`**, **`rest.done`** go on the bus (`GameEvents`, BRIEF §4.4).

## IPC

```
qs -c overworld ipc call widgets toggle | reveal | hide      # persisted in ~/.config/overworld/widgets-visible
#   (NB `widgets show` is swallowed by the qs CLI — `show` collides with `qs ipc show` — so the alias is `reveal`)
qs -c overworld ipc call widgets demo on|off                 # mocked track on the Jukebox when no player exists
qs -c overworld ipc call widgets status                      # "visible (demo)"
qs -c overworld ipc call widgets layout                      # every card back on its slot
qs -c overworld ipc call widgets card <weather|music|calendar|sysinfo|cava|quote|block|brew>    # toggle one (`herb` = alias of block)
qs -c overworld ipc call widgets cards | menu
qs -c overworld ipc call brew start 50m | startWith 50m 10m | toggle | pause | reset | add 5m | open | sound brew|rest | status | settings
# CLI: overworld brew help   (`-p <preview dir>` instead of `-c overworld` for the preview instance)
```

## State, caches, config

| path | what |
|---|---|
| `~/.config/overworld/widgets-visible` | `true` / `false`, read at startup, written by reveal/hide/toggle |
| `~/.config/overworld/widgets-hidden.json` | list of switched-off card ids |
| `~/.config/overworld/widget-positions.json` | `{cardId: [x, y]}` for dragged cards |
| `~/.config/overworld/config.json` | `widgets.opacity`, `weather.{lat,lon,name}`, `brew.{work,break}`, `sounds`, `reduced_motion`, `gui_scale` |
| `~/.cache/overworld/weather.json` | last good forecast + location (Open-Meteo JSON, `stale: true` when served from cache) |
| `~/.cache/overworld/weather-now.json` | **for fx-world:** `{"kind": "clear|cloudy|fog|rain|thunder|snow", "code": <WMO>, "is_day": bool, "temp": °C, "precip_mm": mm, "wind": km/h, "city": str, "stale": bool, "updated": epoch}`, rewritten by `weather-fetch.py` after every fetch (startup, every 30 min, Retry) |
| `~/.cache/overworld/packages`, `cava.conf` | package count text (10 min) · generated cava config |

In-process consumers (fx-world runs inside the same `qs` instance) may read `WeatherService.kind`, `.code`, `.isDay`, `.temp`
after `import qs.Widgets.Services`; the file above is for anything outside QML. Kind mapping: 95/96/99 thunder · 71–77, 85, 86 snow ·
51–67, 80–82 rain · 45/48 fog · 2/3 cloudy · else clear.

## Behaviour of the engine (kept from Apothecary)

- **Click-through.** The PanelWindow `mask` is a `Region` whose children are `Region { item: <card> }` for every visible card (null
  while the layer or the card is hidden). Outside the rectangles the desktop receives everything; inside, cards get hover/click.
- **Dragging.** Grab a card's title bar (the top 17 GUI px). While a drag is active `WidgetsState.dragging` adds a full-screen region
  to the mask, so a fast flick cannot leave the card's input region. Position is saved on release; **double-click the title bar** =
  back to the slot; IPC `widgets layout` resets all.
- **Opacity.** Only the panel's centre fill is translucent (`Theme.widgetOpacity`, live from `config.json`); bevels, text, icons
  stay opaque.
- **Costs when hidden.** cava is stopped, sysinfo polling stops, tick clocks (`McTicker`) release, the weather/quote/block timers are
  slow (30 min / 10 min / 12 s while visible).
- **Reduced motion** (`config reduced_motion`, Options "animations" off): fades are instant, the sky/disc/marquee/bubbles/splash stop on
  their first frame.

## Running the preview (never touches the live shell)

```
source scripts/dev-env.sh
OW_MODE=light qs -p quickshell/Widgets/preview                    # the layer itself (dark for Night); OW_WIDGETS_DEMO=1 mocked track
quickshell/Widgets/preview/shot.sh <name> [light|dark] [region]   # start it, scripts/dev-shot.sh → qa/screenshots/qs-widgets-<name>.png, stop it
qs -p quickshell/Widgets/preview/skies.qml                        # every sky condition in a grid
# offscreen, no compositor at all (software renderer: no ShaderEffects, i.e. no sun/moon/note particles/water tint):
OW_RENDER_OUT=/tmp/x.png OW_RENDER_BG=<wallpaper.png> OW_MODE=dark OW_WIDGETS_DEMO=1 QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/render.qml
# logic self-test (throw-away HOME; see the header of selftest.qml)
```

Preview-only env pins (no effect unless set): `OW_WIDGETS_OPACITY` (card fill; the live desktop's own cards would shine through a
0.72 fill in screenshots), `OW_WIDGETS_LAYER=top` (a `bottom` layer is covered by other agents' test windows), `OW_WIDGETS_DEMO`,
plus the design system's `OW_MODE`, `OW_GUI`, `OW_REDUCED_MOTION`.

Known harmless log lines: `quickshell.dbus.properties … playerctld … NoActivePlayer` (Quickshell's Mpris probing the playerctld
bus) and `kf.iconthemes: Icon theme … not found` (Qt platform theme).
