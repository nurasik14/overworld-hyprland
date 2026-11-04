# World effects — day/night cycle, weather, F3

Module `quickshell/World/` (entry `WorldFx.qml`, owner fx-world), helpers in `scripts/world/`. Everything here runs inside the
normal `qs -c overworld` process; nothing is a separate daemon.

```
quickshell/World/
  WorldFx.qml        entry: instantiates the layers, owns the `world` IPC target
  SunCalc.js         NOAA sunrise/sunset + the four day phases (pure JS, tested in node)
  DayCycle.qml       singleton: schedules the next boundary, applies mode + wallpaper through the script
  WeatherState.qml   singleton: which weather, pauses, the 20 TPS clock, lightning
  WeatherLayer.qml   the `overworld-weather` layer window(s)
  F3Layer.qml        the `overworld-f3` layer window(s) + F3 data
  preview/           harness: qs -p quickshell/World/preview   (links: Common, Services, World)
scripts/world/
  daycycle-apply.sh  the desktop side of a transition (wallpaper fade, `overworld light|dark`); --dry-run
  f3-static.sh       kernel / CPU / GPU / monitor / versions as one JSON line (run once on first F3)
  f3-sampler.sh      cursor 4x/s, active window + backlight 1x/s while F3 is open
```

## IPC

`qs -c overworld ipc call world <fn> [arg]`

| call | does |
|---|---|
| `weather clear\|rain\|thunder\|snow\|auto` | override the overlay (what `/weather` calls); `auto` = the real weather. Not persisted. |
| `daycycle auto\|day\|night\|off` | writes `config.json daycycle` and acts at once (what `/time set` and the Options screen call) |
| `time` | phase, sunrise / sunset, next transition (3 lines) |
| `f3 on\|off\|toggle` | the debug screen. Bind: `SUPER+F3` → `qs -c overworld ipc call world f3 toggle` |
| `f3graph on\|off\|toggle` | the CPU chart (turns F3 on) |
| `strike [hold\|release]` | one lightning stroke now (thunder only); `hold` keeps it lit for screenshots |
| `status` | one line: weather, pause reason, layers, day cycle, F3 |

(The qs CLI needs an argument for `weather`, `daycycle`, `f3`, `f3graph`; there is no zero-argument toggle.)

## Day/night cycle

```
config.json   "daycycle": "auto" | "day" | "night" | "off"     (missing = "auto")
              "weather": {"lat": .., "lon": .., "name": ..}      optional location override (same key the Weather card reads)
```

* **auto** — `overworld light` at local sunrise, `overworld dark` at sunset; the wallpaper follows the sky.
* **day** / **night** — pinned: applied once when chosen, then left alone. **off** — does nothing.
* **A manual `overworld light|dark` always wins until the next sunrise or sunset.** The cycle only acts at a boundary, and once at
  start-up if a boundary passed while the shell was not running (`~/.cache/overworld/daycycle.json` remembers the last phase; a first
  ever run records the phase and changes nothing). Between boundaries it never touches the theme.
* Sun times are computed locally (NOAA formulas, `SunCalc.js`), no network. Location: `config weather.{lat,lon}`, else the
  location the Weather card geolocated (`~/.cache/overworld/weather.json` → `location`), else Kowloon 22.3167, 114.1833.
  Checked against Open-Meteo's daily sunrise/sunset for Kowloon (06:29 / 17:44 on 2026-11-05: ours 06:29:28 / 17:44:07).
  Polar day and polar night give one constant phase.
* Phases (the picture matching the sky): `dawn` sunrise−30 min … +45 min · `day` … sunset−60 min · `dusk` … sunset+30 min · `night`.
  The theme mode flips at sunrise (Day) and sunset (Night), not at the phase edges.
* **Wallpaper**: at each phase edge, if the current picture (`~/.config/overworld/wallpaper-<mode>`, else what awww shows) is a scene
  in `assets/wallpapers/index.json`, the script looks for the entry with the same `scene` (and `world`) and the wanted `time`, and
  `awww img … --transition-type fade --transition-duration 4` fades to it (0.3 s with reduced motion). Scenes without that time (Nether,
  End, your own pictures) keep their picture. The picture is also remembered as the mode's wallpaper and `lock.png` follows it
  when there is no dedicated lock art, so the following `overworld light|dark` repaints the same image instead of an old one.
  When the mode flips, the script waits for the fade to end, then runs `scripts/overworld <mode>`.
* The script does nothing while the theme is off (no `~/.config/overworld/enabled`); log: `~/.cache/overworld/daycycle.log`.
* **Cost**: one `Timer` aimed at the next boundary, never more than 10 minutes ahead (a suspend stops Qt's monotonic timers, so the
  next wake re-evaluates); each wake is a few trigonometric calls. Nothing runs between wakes.

## Weather overlay

Layer `overworld-weather`, level **Background**: above the wallpaper (awww), below the widget layer (`bottom`) and all windows;
empty input region (click-through). When the weather is clear or paused the window is unmapped.

* **Source** — `~/.cache/overworld/weather-now.json` (written by the Weather card's `weather-fetch.py` after every Open-Meteo fetch,
  watched live). If it is older than 40 minutes (no Weather card running) the overlay runs the same fetch script every 15 minutes, so
  the cache stays the single source. `kind` rain / thunder / snow draw; cloudy and fog draw nothing. Real rain with `precip_mm` ≥ 0.3
  uses 2 layers, ≥ 2.5 uses 3.
* **Override** — `world weather …` / `/weather`. Rain = 2 layers, thunder = 3, snow = 2 (heavy real snow uses 3).
* **Looks** — `environment/rain.png` and `snow.png` from the texture tree (`Theme.tex`, original fallback art when Mojang assets are
  absent), tiled and drawn at integer scales (GUI, GUI+1, GUI+2) in up to three parallax layers: nearer = bigger and faster. Rain falls at
  an 8° slant; snow sways sideways. The sky darkens (rain 12 %, thunder 24 %, snow 3 %). Fades in and out over 1.5 s.
* **Thunder** — a double white flash (34 % then 22 % opacity, decaying over about 0.4 s) every 6–20 s, plus the `lightning` sound only
  when `config weather_thunder_sound` is true (default false; `ow-sound` is silent anyway while `sounds` is false).
* **Pauses** (nothing drawn, no timers running): `weather_effects` false · game mode adventure or spectator · a fullscreen window on the
  focused workspace (Hyprland `fullscreen` event + `hyprctl activeworkspace`) · battery below 20 % and not charging · reduced motion
  (`reduced_motion` or `animations: false`). `particles` = `decreased` caps the layers at 2, `minimal` at 1.
* **How it is cheap** — each depth layer is one tiled `Image` shifted by whole texels once per tick of one shared 20 TPS `Timer`
  (WeatherState.frame), so the scene graph redraws 20 times a second instead of at 165 Hz. Hidden = no window, no timer.
  If awww is restarted while it rains (`overworld repair`), the new wallpaper surface can sit above the overlay until the weather next
  changes (`world weather auto`).

Measured (`top -b -n 4 -d 2` on the preview process, 1920x1080 @165 Hz, 16 cores, one output):

| state | qs CPU (% of one core) |
|---|---|
| clear / paused (window unmapped) | 0.0 – 0.5 |
| rain, 2 layers | 2.0 |
| thunder, 3 layers + flashes | 2.0 – 2.5 |
| snow, 2 layers | 1.5 – 2.5 |
| F3 open (first second 3.5, then) | 0.5 – 1.5 |
| F3 + graph | 1.0 |

GPU load was not measured (no per-process GPU counter on the iGPU); the overlay only submits a new frame 20 times per second.

## F3 debug screen

Layer `overworld-f3` (Overlay, click-through, only on the focused monitor). Looks like the game: white shadowed text, every line on a
`#90505050` strip, 9 GUI px per line, left column top-left, right column right-aligned. Nothing runs while it is hidden. While shown:
`f3-sampler.sh` (one process: `hyprctl cursorpos` 4 times a second, active window and backlight once a second), `/proc/meminfo`
once a second, everything else binds to the existing services. `f3-static.sh` runs once, the first time F3 opens.

| F3 line | what it shows |
|---|---|
| `Overworld Hyprland 1.0 (Hyprland 0.56.2/vanilla)` | version = `VERSION` file in the repo root if present, else 1.0; Hyprland from `hyprctl version` |
| `165 fps T: 165 vsync fancy-clouds` | monitor refresh rate; `fancy-clouds` = animations on, `fast-clouds` = reduced motion |
| `E: 1/7` | windows on this workspace / windows in total |
| `XYZ: x / y / z` | cursor x · screen height − cursor y (up is positive, like Y) · workspace id |
| `Block: x y w×h` | active window position and size (`none` without one) |
| `Chunk:` | cursor / 16 · workspace · monitor name |
| `Facing: east (Towards positive X) (2 → 3)` | which way the last workspace switch went |
| `Client Light: n (n sky, 0 block)` | backlight 0–15 (reads the connected `intel_backlight`, read only) |
| `Biome: minecraft:kitty` | active window class (`minecraft:the_void` with no window) |
| `Local Difficulty: 0.65 // 0.00 (Day 1)` | CPU load × 6.75 (the game's maximum) · uptime in days |
| `Day cycle:` / `Weather:` / `Game mode:` | the cycle's setting and phase → next boundary · the weather and why it may be paused · game mode, Peaceful |
| right: `Kernel`, `Mem: 47% 7401/15663MB`, `Allocated: 36% … swap`, `CPU: 16x …` | kernel; used/total RAM; swap in use; cores and model |
| right: `Display: 1920x1080 @165Hz (eDP-1)` + GPU names | `lspci` names, NVIDIA name and driver from `nvidia-smi` (one call, first open) |
| right: `Targeted Block:` / `minecraft:<class>` | window title (48 chars) and class |
| right: `Battery`, `Network`, `Uptime` | UPower, active SSID (or `wired` / `disconnected`), uptime |

`world f3graph` adds the game's frame-time chart under it, here the CPU load: one column per 2 s (120 columns = 4 minutes), newest
on the right, green → yellow → red, lines at 50 % and 100 %. It only samples while it is shown.

## Config keys

| key | default | meaning |
|---|---|---|
| `daycycle` | `"auto"` | `auto` / `day` / `night` / `off` (this module reads the raw key; a missing key means auto) |
| `weather_effects` | `true` | master switch of the overlay |
| `weather_thunder_sound` | `false` | play the quiet `lightning` sound with each flash |
| `particles` | `"all"` | `decreased` = at most 2 layers, `minimal` = 1 |
| `weather.lat`, `weather.lon`, `weather.name` | unset | location for sun times and the Weather card |
| `reduced_motion` / `animations` | `false` / `true` | reduced motion hides the overlay |

## Testing

```sh
source scripts/dev-env.sh
OW_PREVIEW=1 OW_WORLD_DRYRUN=1 qs -p $PWD/quickshell/World/preview > /tmp/fxw.log 2>&1 &
qs -p $PWD/quickshell/World/preview ipc call world weather rain
```

Pins: `OW_WORLD_NOW=2026-11-05T17:43:50+08:00` fakes the clock (it keeps running) · `OW_WORLD_DRYRUN=1` (also implied by `OW_PREVIEW=1`)
makes the day cycle run `daycycle-apply.sh --dry-run` and print instead of acting · `OW_WORLD_BACKDROP=<png>` paints a picture under
the overlay in the preview · `OW_WORLD_FAKE_FS=1` pretends a window is fullscreen · plus the shell-wide `OW_CONFIG`, `OW_GAMEMODE`,
`OW_FAKE_STATS`, `OW_REDUCED_MOTION`. `SunCalc.js` can be tested in node by dropping the `.pragma library` line.
