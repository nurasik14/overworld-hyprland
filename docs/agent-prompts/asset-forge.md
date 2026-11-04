# asset-forge (phase 1) — fonts, icons, sounds map, fallback art, cursor, fetch script

You own: `assets/gen/`, `assets/icons/`, `assets/CREDITS.md`, `assets/fonts/`, `tools/assetforge/`,
`scripts/fetch-minecraft-assets.sh`, `scripts/ow-sound`, `tokens/sounds.json`, `tokens/items.json`,
`apps/cursor/` (cursor theme source + build script), and you may install generated fonts/cursors into
`~/.local/share/fonts/overworld/` and `~/.local/share/icons/` (user-level only).

Mojang assets are already extracted in `assets/mc/` (see BRIEF §0). Use a uv project in `tools/assetforge/`
(Pillow, numpy, fonttools). Order matters — other agents are waiting on items 1–3, so do them first and fast.

1. **Font `Overworld Mojangles`** (first, ≤20 min): build a TTF from the jar's bitmap font providers
   (`assets/mc/font/default.json` / `include/default.json` → `textures/font/ascii.png`, `nonlatin_european.png`
   (has Cyrillic), `accented.png`), with the real per-glyph advance widths (scan columns like the game does,
   +1 px spacing), square pixel outlines on an 8-px-high grid (units per em chosen so 8 px = 1 em at size 8×n),
   proper ascent/descent, space width 4. Also a **Bold** style (the game draws bold as the glyph again
   offset +1 px — emulate). Write to `assets/fonts/OverworldMojangles-{Regular,Bold}.ttf` (gitignored) and
   install into `~/.local/share/fonts/overworld/`, `fc-cache`, verify with `fc-list | grep -i mojangles` and
   render a test string (Latin + Cyrillic "Привет, Қазақстан" — note Kazakh letters ә ғ қ ң ө ұ ү һ і may be
   missing; report which, Theme falls back to Monocraft per glyph) with ImageMagick to
   `qa/screenshots/asset-forge-font.png` and look at it.
2. **`scripts/ow-sound <id>` + `tokens/sounds.json`** (BRIEF §4.5): map every listed id to real files from
   `assets/mc/sounds.json` (e.g. ui.click → `random/click`, ui.toast.in/out → `ui/toast/in|out`,
   challenge → `ui/toast/challenge_complete`, xp.orb → `random/orb`, xp.levelup → `random/levelup`,
   chest → `block/chest/open|close`, break/place/hit per material from `dig/*` and `step/*`, book.page →
   `item/book/page_turn*`, item.pickup → `random/pop`, brew → `block/brewing_stand/brew*`, drink →
   `random/drink`, etc.) with sensible volumes and categories; add `gen:` fallbacks pointing at
   `assets/gen/sounds/` — synthesize small original fallback sounds (click, pop, orb chime, level-up arpeggio,
   break crunch, toast whoosh) with numpy so the theme works without Mojang assets. `ow-sound` features:
   random variant, per-category volume from `config.json` (`sound_volume: {master, ui, toasts, blocks,
   ambient}` 0–100), `sounds:false` → silent exit 0, `OW_SOUND_DRYRUN=1` → print the file and volume, never
   block (detached `pw-play --volume`), list mode `ow-sound --list`. NEVER play audibly yourself (dry-run only).
3. **`tokens/items.json` + icons**: map ~60 common app classes/desktop-ids to Minecraft items/blocks that
   fit their meaning (kitty/terminals → command_block, zen/firefox/chrome → compass, spotify/youtube-music →
   music_disc_cat etc., superfile/thunar/nautilus → chest, nvim/code/codium → writable_book, obsidian →
   enchanted_book, discord/telegram → bell or paper, steam/tlauncher/minecraft → grass_block, btop → redstone
   comparator, settings/nwg-look/pavucontrol → redstone/lever, obs → spyglass, gimp/inkscape → painting /
   brush, hermes (kitty title contains Hermes) → enchanting_table, zoom/teams → spyglass/goat_horn,
   libreoffice → book, mpv/vlc → jukebox, …) plus `_default` (e.g. `stone`) and `_empty`. Write
   `tools/assetforge/render_icons.py`: blocks rendered as **isometric inventory icons** like the game (top
   face lit 1.0, left 0.8, right 0.6, from the model JSON textures in `assets/mc/models/block/*.json`), items
   as flat textures; output 16×16 base + pre-scaled 32/48/64 px nearest-neighbour to `assets/icons/mc/`.
   Also original fallback icons in `assets/gen/icons/` (generated pixel art, not copies). Contact sheet
   `qa/screenshots/asset-forge-icons.png` — look at it.
4. **Fallback art `assets/gen/textures/…`** (original, committed): generate original pixel-art equivalents for
   the core GUI sprites the shell will use, at the SAME relative paths and sizes as the Mojang ones (with
   matching `.mcmeta`): `gui/sprites/widget/{button,button_highlighted,button_disabled,slider,slider_handle,
   slider_handle_highlighted,text_field,text_field_highlighted,checkbox*,scroller*}`,
   `gui/sprites/hud/{hotbar,hotbar_selection,hotbar_offhand_left,heart/*,food_*,armor_*,experience_bar_*}`,
   `gui/sprites/toast/*`, `gui/sprites/tooltip/*`, `gui/sprites/boss_bar/*`, `gui/sprites/server_list/*`,
   `gui/sprites/icon/ping_*`, `block/destroy_stage_0..9`, `environment/{sun,moon_phases,rain,snow}`,
   a generic `gui/inventory-panel` and `misc/missing.png` (magenta/black). Style: similar *function*, our
   own pixels. Contact sheet → `qa/screenshots/asset-forge-fallback.png`.
5. **Cursor theme `Overworld`**: original pixel-art cursors (arrow, hand/pointer, text I-beam, crosshair as
   the game's cross for `crosshair`, wait = hourglass/clock frames, resize arrows, grab) at 24/32/48 px,
   built both as **hyprcursor** (`hyprcursor-util`) and **Xcursor** (write the Xcursor binary format from
   Python — no xcursorgen) with the full alias set (left_ptr, default, pointer, hand2, text, xterm,
   crosshair, watch, wait, progress, grab, grabbing, *-resize, not-allowed…). Source + build script in
   `apps/cursor/`; install to `~/.local/share/icons/Overworld/` but DO NOT activate it (hyprland-engineer /
   app-theming will). Preview sheet → `qa/screenshots/asset-forge-cursor.png`.
6. **`scripts/fetch-minecraft-assets.sh`**: recreate `assets/mc/` exactly as phase 0 did — prefer a local
   `~/.minecraft/versions/*/<v>.jar` + `~/.minecraft/assets/objects` (read-only), else download the latest
   release client jar + asset index + sound objects from Mojang (`piston-meta.mojang.com`,
   `resources.download.minecraft.net`, sha1-verified), extract textures/texts/font/models/blockstates/lang +
   sounds + sounds.json, write `assets/mc/VERSION`. `--sounds-only`, `--force`, idempotent. Test it into a
   temp dir (`OUT=… scripts/fetch-minecraft-assets.sh` → diff counts against assets/mc), do not overwrite
   assets/mc while others read it. It should also run the font + icon build steps (`--build`).
7. `assets/CREDITS.md` rewritten for Overworld (Mojang assets: fetched, not redistributed; Monocraft OFL;
   our generated art: project licence).

Write `docs/agent-reports/asset-forge.md` as you go (each deliverable: path, how verified).
