# fx-world (phase 2) — day/night cycle, weather overlay, F3 debug screen

You own: `quickshell/World/` (entry `WorldFx.qml`, already instantiated), `scripts/world/` helpers,
`docs/WORLD.md`.

Phase-1 outputs you build on (read them first): `docs/DESIGN.md` + `quickshell/Common/*` (Mc* components —
use them, do not re-implement them; request changes from design-director via docs/REQUESTS.md, or add a local
component inside your own directory), `tokens/` (palettes), `tokens/sounds.json` + `scripts/ow-sound`
(sound ids), `tokens/items.json` + `assets/icons/` (app → item icons), `quotes/*.json` (lore-writer texts),
`assets/wallpapers/index.json` (world-renderer), `docs/agent-reports/*.md` (what each phase-1 agent actually
delivered and its caveats). The Apothecary original of every file you replace is in
`~/Projects/apothecary-hyprland` — keep every behaviour it had (BRIEF §5) unless your prompt says otherwise.
Test with your own preview harness under your directory (`<Dir>/preview/shell.qml` with `qs -p`; symlink the
sibling dirs it imports, see the existing `quickshell/Brew/preview` and `quickshell/Common/preview`), and at
the end also load the FULL config once: `timeout 15 qs -p ~/Projects/overworld-hyprland/quickshell > log 2>&1`
(it runs on top of the live Apothecary desktop; the notification daemon name is taken — that warning is
expected) and make sure nothing from your files errors. Kill only the PIDs you started.

1. **Day/night cycle**: config `daycycle: "auto"|"day"|"night"|"off"` (default "off" until the user opts in?
   — no: default "auto" is the fun choice, BUT it must never fight a manual `overworld light|dark` within the
   same sun phase: manual choice holds until the next sunrise/sunset). Sun times computed locally (NOAA
   formula) from the weather location (same IP-geo/Open-Meteo location logic and cache as the Weather widget;
   fallback Kowloon 22.3167, 114.1833). At the transition: `overworld light|dark` (hyprland-engineer's CLI) and,
   when the current wallpaper is a scene with time variants in `assets/wallpapers/index.json`, switch to the
   matching dawn/day/dusk/night variant with a slow awww fade. IPC `world daycycle <m>`, `world time`
   (prints phase + next transition). Must cost ~0 CPU between transitions (one Timer to the next event).
2. **Weather overlay** (layer `overworld-weather`, `background`/`bottom` level ABOVE the wallpaper but BELOW
   the widget layer and windows, click-through, no input region): Minecraft rain (`environment/rain.png`
   streaks, falling at a slant, layered parallax, 20 TPS-ish), snow (`environment/snow.png`, slow drift),
   thunder (occasional full-screen white flash at low opacity + optional quiet `lightning` sound — sound off
   by default), clear = nothing rendered (layer hidden). Source: Open-Meteo current weather code (reuse the
   Weather widget's cache if available, else fetch every 15 min), override by IPC `world weather
   clear|rain|thunder|snow|auto` (used by `/weather`). Performance budget: < 3 % of one core and no
   continuous GPU load when hidden; pause when a window is fullscreen, in gamemode adventure/spectator, when
   config `weather_effects` is false, and when on battery below 20 % (document). Implement with a
   ShaderEffect or a few large tiled Images moved per tick (not thousands of Items). Measure CPU with
   `top -b -n 3 -p <qs pid>` while raining in your preview and report numbers.
3. **F3 debug screen** (layer `overworld-f3`, overlay, click-through, IPC `world f3` toggle): left column + right
   column in the real F3 layout/format with live values refreshed every tick/second as appropriate:
   "Overworld Hyprland <version> (Hyprland 0.56.2/vanilla)", "<fps> fps" (monitor refresh), "XYZ:" (cursor
   position from `hyprctl cursorpos`, refreshed ≤ 4 Hz), "Block:" (active window position/size), "Facing:"
   (workspace + direction of last switch), "Biome:" (active window class), "Light:" (backlight %), "Local
   Difficulty:" (CPU load), right side: Java → "Kernel", Mem: used/total %, Allocated, CPU model + cores,
   Display: 1920x1080 (GPU names from `lspci`/nvidia-smi if cheap), "Targeted Block:" (window title),
   battery, network SSID, uptime. Text = white with grey translucent row backgrounds exactly like F3.
   Optional F3 pie/graph toggle (`world f3graph`): a frame-time-style bar graph of CPU usage.
4. `docs/WORLD.md`: how each effect works, config keys, costs.

Screenshots: rain over a Day wallpaper, snow, thunder flash frame, F3 in Day + Night
(`qa/screenshots/fx-world-*.png`). For the overlay shots, show your preview with the overlay; Apothecary's
widget layer underneath is fine. Report in `docs/agent-reports/fx-world.md`.
