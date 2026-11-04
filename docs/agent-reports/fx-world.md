# fx-world report (phase 2)

Status: **done**. Module `quickshell/World/`, helpers `scripts/world/`, doc `docs/WORLD.md`.

## Deliverables
| | path |
|---|---|
| entry + IPC target `world` (`weather`, `daycycle`, `time`, `f3`, `f3graph`, `strike`, `status`) | `quickshell/World/WorldFx.qml` |
| sun times (NOAA) + day phases | `quickshell/World/SunCalc.js` |
| day/night cycle singleton | `quickshell/World/DayCycle.qml`, `scripts/world/daycycle-apply.sh` |
| weather state / overlay | `quickshell/World/WeatherState.qml`, `WeatherLayer.qml` (layer `overworld-weather`) |
| F3 screen | `quickshell/World/F3Layer.qml` (layer `overworld-f3`), `scripts/world/f3-static.sh`, `f3-sampler.sh` |
| preview harness | `quickshell/World/preview/` (links Common, Services, World) |
| doc | `docs/WORLD.md` |

## What was verified, and how
- **Sun maths**: `SunCalc.js` run in node. Kowloon 2026-11-05: Open-Meteo says 06:29 / 17:44, ours 06:29:28 / 17:44:07. London and Sydney
  solstices, New York equinox, Reykjavik, polar day (Tromsø) and polar night (Svalbard) behave. A 48-step walk through one HK day gives the
  right phase / mode / next boundary at each step.
- **Day cycle in QML** (fake clock `OW_WORLD_NOW`, dry-run): at 17:43:50 the sunset fired 17 s later as `--time dusk --mode dark`; start-up
  catch-up (saved night/dark at noon → `--time day --mode light`), no action when the saved phase equals the current one, phase-only change
  leaves the mode alone, first run without a saved file changes nothing. `world daycycle night|auto|off` applies at once; bad values answer a usage line.
- **`daycycle-apply.sh`**: `--dry-run` against `assets/wallpapers/index.json` picks the right variant for the scene (plains day → dusk,
  desert night → dawn), keeps pictures that are not in the index or have no such time, exits when the theme is off. **NOT run for real**:
  the live `awww` fade and `overworld light|dark` were never executed (they would change the user's live desktop). The `awww img` line and the
  `scripts/overworld` call are copies of what the CLI itself does.
- **Weather overlay** (preview over a Day plains wallpaper, `dev-shot`): rain, snow, thunder flash frame and the calm thunder frame look right;
  the overlay is below Apothecary's widget cards and bar (layer order OK), click-through. Pauses verified through `world status` with pins:
  `weather_effects` false (live file edit), game mode adventure / spectator (creative draws), battery 15 % discharging pauses but 15 % charging
  and 50 % do not, reduced motion, `OW_WORLD_FAKE_FS=1`; `particles` minimal / decreased cap the layers at 1 / 2 live. The **real** fullscreen
  detection (Hyprland `fullscreen` event + `hyprctl activeworkspace` → `hasfullscreen`) is only checked by reading the JSON shape (key exists, false
  on ws 77), not with a real fullscreen window. The thunder sound call was only checked with `OW_SOUND_DRYRUN=1 scripts/ow-sound lightning` (id exists, muted by `sounds:false`).
- **F3**: live values appear (cursor, workspace, backlight 1 → "Client Light: 1", memory, battery, SSID, uptime, GPU names, driver), Day and Night shots,
  graph with a synthetic load (nice'd busy loops) shows green → yellow → red columns. The sampler process dies with F3 and with qs (checked with `ps`).
- **CPU** (`top -b -n 4 -d 2 -p <pid>`, preview process): clear 0.0–0.5 %, rain 2.0 %, thunder 2.0–2.5 %, snow 1.5–2.5 %, F3 0.5–1.5 %, F3 + graph 1.0 %.
  The `hyprctl` forks of the F3 sampler (4/s) are separate processes and were not added up. GPU not measured.
- **Full config**: `OW_PREVIEW=1 OW_WORLD_DRYRUN=1 OW_STATE_DIR=… OW_EVENTS_DIR=… timeout 15 qs -p quickshell` → no message from any World file
  (only the expected notification-server and desktop-entry warnings).

## Screenshots (`qa/screenshots/`)
`fx-world-rain.png` (rain over a Day wallpaper) · `fx-world-snow.png` · `fx-world-thunder.png` (flash held with `world strike hold`) ·
`fx-world-thunder-calm.png` · `fx-world-f3-day.png` · `fx-world-f3-night.png` (with the CPU graph).
Each shows Apothecary's bar and cards underneath; the wallpaper is the preview's own backdrop (`OW_WORLD_BACKDROP`).

## Decisions
- **Default `daycycle`**: "auto" in this module (missing key = auto), which is safe because the cycle acts only at sunrise/sunset/phase edges, never at start-up
  without a recorded boundary crossing. qs-core's `ConfigService.defaults.daycycle` is still "off": requested to switch (REQUESTS.md).
- **Mode flips at sunrise/sunset, the picture changes at phase edges** (dawn −30 min … +45, dusk −60 … +30) so the dawn/dusk variants have a time to show.
- At a flip the script fades the wallpaper first (4 s) and only then runs `overworld light|dark` (which repaints the same, already remembered, image):
  a Day UI over the night picture lasts at most 4 s, but nothing flashes. Slow fade for phase edges inside a mode as well.
- Weather: Background layer level (not bottom), so ordering against the widget layer does not depend on map order. Known limit: an awww restart can
  put the wallpaper above the overlay until the weather changes.
- `/weather` override is in-memory only (like the game); cloudy/fog draw nothing; reduced motion hides the overlay instead of freezing it.
- F3 mapping (docs/WORLD.md): XYZ = cursor x / screen height − cursor y / workspace, Block = window geometry, Facing = direction of the last
  workspace switch, Biome = window class, Light = backlight 0–15, Local Difficulty = CPU × 6.75, Allocated = swap, Targeted Block = title. Extra honest lines:
  Day cycle, Weather, Game mode.
- Debug/test hooks kept in the code on purpose: `world strike [hold|release]`, `OW_WORLD_NOW`, `OW_WORLD_DRYRUN`, `OW_WORLD_FAKE_FS`, `OW_WORLD_BACKDROP`.

## Open issues / not done
- No keybind yet for F3 (hyprland-engineer, requested): `qs -c overworld ipc call world f3 toggle`. The CLI needs an argument; no zero-argument toggle exists.
- Layer rules for `overworld-weather` / `overworld-f3` (no animation, no blur) requested from hyprland-engineer.
- `VERSION` file at the repo root is read for the F3 title line when present (else "1.0"); nobody owns it yet.
- Real sunrise/sunset flip with live awww + `overworld` untested end-to-end; do it once the theme is installed (`world daycycle auto` while the sun phase differs from the
  current mode, watch `~/.cache/overworld/daycycle.log`).

## Requests filed (docs/REQUESTS.md)
hyprland-engineer (F3 bind, layer rules, apply-script contract, optional CLI forwarding) · qs-core (daycycle default "auto", `weather_thunder_sound`, property names I read) ·
qs-features (the implemented IPC signatures) · app-theming/asset-forge (nothing needed).
