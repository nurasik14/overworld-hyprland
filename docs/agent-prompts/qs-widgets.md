# qs-widgets (phase 2) — the 8 desktop widget cards, Minecraft edition

You own: `quickshell/Widgets/` (all of it), `docs/WIDGETS.md`.

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

Keep the whole Apothecary widget engine (layer `overworld-widgets` at `bottom`, click-through mask = union of
cards, drag by title bar with fast-drag full-screen mask, persisted positions, double-click/IPC reset,
per-card hide/show + `widgets` IPC incl. `reveal`, `widgets.opacity` from config (~0.72), cava process only
while visible, synchronous config load) and re-skin + re-imagine each card as a Minecraft object. Cards use
`McPanel` (GUI-panel look with the dark-grey title text like "Crafting"), translucent fill, crisp pixels.

1. **Music → Jukebox**: jukebox block icon + spinning music disc (rotation stepped on the tick), album art inside
   an item frame, "Now Playing: Artist - Title" in the **rainbow-cycling** action-bar colour like the game,
   progress as an XP-style bar, prev/play/next as small Minecraft buttons (wire them, but NEVER click/press them
   in testing — the user's sleep music is in that player). Player filter as before (playerctld excluded).
2. **Weather → sky window**: big temperature, condition with Minecraft-style icons (sun/moon from
   `environment/`, rain/snow/thunder pixel icons), humidity/precip/wind, 24 h bars drawn as stacked blocks
   (column height = temp, block type by condition: snow block, water, sand…), location from the same
   Open-Meteo/IP logic. Expose the current condition for fx-world (it may read your weather cache file —
   document its path in WIDGETS.md and REQUESTS).
3. **Calendar → clock + map**: Minecraft clock item (the real 64-frame `item/clock_*.png` animation showing the
   actual time of day), "Day N" (day of year), month grid in slot style with today highlighted by the hotbar
   selection frame.
4. **SysInfo → F3-style card**: the fastfetch info lines in F3 debug text style (white text on translucent
   grey row backgrounds), CPU/RAM/disk as Minecraft bars, grass-block icon instead of the Maomao picture.
5. **Cava → note-block equaliser**: bars as stacks of note-block/redstone-lamp pixels, peak = note particle.
6. **Quote → sign + splash**: an oak sign (`entity/signs/oak.png` or the hanging sign) showing a rotating
   message from `quotes/splashes.json` (+ optional random Mojang splash from `assets/mc/texts/splashes.txt` at
   runtime when present, never copied into the repo), with the yellow pulsing splash text on the corner.
7. **Herb of the day → Block/Mob of the day**: item frame with the texture, name, 2–3 facts, tip, "since"
   version, from `quotes/blocks-of-the-day.json` (deterministic by date).
8. **Brew timer → brewing stand card** (keep every BrewTimer feature: any lengths, rest 0, pencil → dialog,
   click clock → dialog, scroll-to-adjust, sessions count, sounds via ids `brew.done`/`brew.drink`, emits
   `brew.start/brew.done/rest.done`).
Also re-skin the widgets dropdown/menu if it lives in Widgets/, and update `Widgets/preview`.

Default layout must fit 1920×1080 with the bottom HUD (keep ~110 px free at the bottom centre) and leave the
wallpaper's focal area visible. Screenshots of the whole widget layer in Day and Night
(`qa/screenshots/qs-widgets-day.png`, `-night.png`, plus close-up crops), view and iterate. Report in
`docs/agent-reports/qs-widgets.md`.
