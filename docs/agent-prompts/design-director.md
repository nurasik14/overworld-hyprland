# design-director (phase 1) — Minecraft design system + Common QML components

You own: `tokens/` (except tokens/sounds.json, tokens/items.json), `quickshell/Common/`, `docs/DESIGN.md`.

Goal: give every other agent a faithful **Minecraft Java GUI design system** to build with, in both modes
(light = Day, dark = Night), as tokens + reusable QML components + a preview that proves them. Phase-2 agents
(qs-core, qs-widgets, qs-features, fx-*) start as soon as you finish, so the component API must be complete,
documented and stable. Budget: aim to finish in ~60–75 minutes.

Study first (15 min max): the real sprites in `assets/mc/textures/gui/sprites/**` and their `.png.mcmeta`
(nine-slice data), `assets/mc/textures/gui/*.png` (e.g. `gui/demo_background.png`, `gui/container/*`), font
providers `assets/mc/font/*.json`, and the existing `quickshell/Common/*.qml` + `Services/ConfigService.qml`
API (Theme singleton: mode file watching, tokens loading, `repoCandidates`, cross-fade). Keep the useful
mechanics (mode file watch, synchronous token load, `#rrggbbaa`→Qt colour swap, cross-fade) and replace the
look.

Deliverables:
1. `tokens/tokens.json` + `tokens/build.py` + `tokens/out/{light,dark}/*` regenerated with a Minecraft
   palette: GUI greys (`#C6C6C6` panel, `#FFFFFF`/`#555555` bevel, `#8B8B8B` slot, `#373737` slot shadow),
   text colours (`#404040` title on light panels, `#FFFFFF` + shadow `#3F3F3F` on dark), the 16 Minecraft
   chat/formatting colours (§0–§f: `#000000 #0000AA #00AA00 #00AAAA #AA0000 #AA00AA #FFAA00 #AAAAAA #555555
   #5555FF #55FF55 #55FFFF #FF5555 #FF55FF #FFFF55 #FFFFFF`) as named roles, XP green `#80FF20`, tooltip
   `#F0100010` fill with `#5000FF`→`#28007F` border, enchant purple, grass/sky/water/nether/end accents, and a
   Night palette (deepslate/obsidian panels). Keep every role key that existing generated outputs and apps
   use (hyprland colors, kitty incl. 16 ANSI, rofi, gtk.css, superfile, cava, btop, starship, spicetify, zen,
   nvim, fastfetch, hyprlock vars, sddm) so app-theming and hyprland-engineer can regenerate; run the
   contrast check (WCAG 4.5 for text roles on every ground in both modes, ANSI included; light-mode
   ANSI 7/15 must be dark greys). Fonts: `ui` = `Overworld Mojangles` with fallback `Monocraft` (Theme picks
   the first family present in `Qt.fontFamilies()` — asset-forge is building Mojangles in parallel),
   `mono` = `Monocraft`, sizes as multiples of 8 px × GUI scale.
2. `quickshell/Common/Theme.qml` rewritten: palette roles, `gui` (integer GUI scale from config
   `gui_scale` 1–4|"auto", default 2), `px(n)` = n × gui, `tex(path)` resolution exactly as BRIEF §4.3
   (detect Mojang assets once via a marker such as `assets/mc/textures/gui/sprites/widget/button.png`
   readable by FileView), `tick` (global 20 TPS counter driven by one Timer, paused when nothing listens is
   fine), motion constants for §4.8, `reducedMotion`. Keep `assetsDir`, `repoDir`, `stateDir`, mode API and
   every property the existing modules read, or provide compatible aliases (old names like `durBase`,
   `easeInk`, `fontUi`, `radius`, `space`) so nothing breaks before phase 2 rewrites them.
3. Common components (each with a doc comment listing its API), at minimum:
   `McNineSlice` (draws any nine-slice/tile/stretch sprite by path using its mcmeta data, pixel-perfect),
   `McPanel` (inventory-style bevelled panel, Day + Night skins, optional title text in GUI title style,
   `fillOpacity` for see-through widgets, `default property alias content`), `McButton` (real `widget/button`,
   `button_highlighted`, `button_disabled` sprites, centred label with shadow, hover = highlight instantly,
   click → `SoundService.play("ui.click")` if SoundService exists else a signal, keyboard focus ring,
   `wide`/`small` sizes), `McIconButton` (small square button with an item icon), `McSlot` (18×18 slot with
   item icon, stack count bottom-right with shadow, hover white overlay `#80FFFFFF` like the game),
   `McItemIcon` (resolves `tokens/items.json` names → icon, pixel scaling), `McText` (Minecraft text: hard
   drop shadow offset 1 GUI px, colour codes `§a`… parsing optional, bold/italic, `rainbow` mode for "Now
   playing"), `McTooltip` (purple-bordered tooltip, multi-line: title/description/category), `McTextField`
   (black field with grey border, white text, blinking `_` cursor at tick rate, placeholder grey,
   password echo), `McSlider` (the options slider: `widget/slider` + handle sprites, label "Name: value"),
   `McCheckbox`/`McToggle` (`widget/checkbox` sprites and ON/OFF button style), `McScrollbar`
   (`widget/scroller`), `McTabs` (creative-inventory tab sprites, top row, selected tab joins panel),
   `McProgressBar` (XP bar + boss-bar colours from `hud/experience_bar_*`, `boss_bar/*`), `McToast`
   (toast frame sprites `toast/advancement`, `toast/recipe`, `toast/system`, icon + yellow/purple title +
   description), `McScreen` (full-screen GUI layer helper: dimmed menu-gradient background, centred title,
   Esc to close, fast fade), `McSplash` (yellow splash text, rotated −20°, pulsing scale), `McDivider`,
   `HeartsRow`/`HungerRow`/`ArmorRow` (generic HUD stat rows from `hud/heart/*`, `hud/food_*`,
   `hud/armor_*`, with half values, jiggle/regen animations on the tick), `Tick`-driven
   `McAnimatedSprite` (strip-animated textures like `block/water_still`, `block/nether_portal`,
   `misc/enchanted_glint_item` using their .mcmeta frametime).
   Keep the old components (PaperPanel, InkButton, InkText, TitleBar, Seal, InkDivider, PaperBackground)
   compiling — reimplement them as thin wrappers over the new Mc* look so unported modules already look
   Minecraft, then mark them `// DEPRECATED: use Mc…` in the header.
4. `quickshell/Common/preview/` harness (`qs -p quickshell/Common/preview`) showing every component in Day and
   Night, all states (hover/pressed/disabled, focus, tooltip, toast, slider, tabs, hearts at 7.5/10 and
   jiggling, XP bar, boss bar, splash). Screenshots `qa/screenshots/design-preview-day.png` and
   `-night.png` via `scripts/dev-shot.sh` — view them, compare with the real sprites, iterate until they
   look like real Minecraft UI (crisp pixels, correct bevels, no blurry scaling, no rounded corners).
5. `docs/DESIGN.md` rewritten: concept, palettes (with contrast table), GUI scale rules, nine-slice rules,
   motion table (ticks), component API reference with a usage snippet each, sprite path cheat-sheet (where
   the hotbar, hearts, toasts, buttons, tabs, ping bars, world list, slider, boss bars, advancement frames,
   statistics icons live in `gui/sprites/`), "do / don't" list.

Verify: preview loads with zero warnings from Common files; the existing shell still loads:
`timeout 10 qs -p ~/Projects/overworld-hyprland/quickshell > log 2>&1` → `Configuration Loaded` and no
errors from Common (other modules' missing-texture warnings are fine). Write `docs/agent-reports/design-director.md`.
