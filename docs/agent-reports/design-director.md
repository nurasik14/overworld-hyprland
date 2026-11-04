# design-director report (phase 1)

Status: all five deliverables done. The API is ready for phase 2; start from `docs/DESIGN.md`.

## Deliverables

| # | deliverable | path |
|---|---|---|
| 1 | Tokens, builder, generated outputs | `tokens/tokens.json`, `tokens/build.py`, `tokens/out/{light,dark}/*`, `tokens/out/contrast.md` |
| 2 | Theme singleton | `quickshell/Common/Theme.qml` |
| 3 | Components | `quickshell/Common/`: McNineSlice, McSprite, McPanel, McButton, McIconButton, McSlot, McItemIcon, McText, McOutlineText, McTooltip, McTextField, McSlider, McCheckbox, McToggle, McScrollbar, McTabs, McProgressBar, McToast, McScreen, McSplash, McDivider, McStatRow, HeartsRow, HungerRow, ArmorRow, AirRow, McAnimatedSprite, McTicker |
| 3 | Deprecated wrappers (old APIs on the new look) | PaperPanel, InkButton, InkText, TitleBar, Seal, InkDivider, PaperBackground |
| 3 | Support files | `shaders/mcpalette.frag` + `.qsb`, `assets/missing.png` (both original work) |
| 4 | Preview harness | `quickshell/Common/preview/shell.qml` |
| 5 | Design doc | `docs/DESIGN.md` |

## Decisions phase 2 should know

- **Common does not import Services.** Components call `Theme.playSound(id)`, which runs `scripts/ow-sound` (the one player, §4.5), instead
  of `SoundService.play`. This departs from the prompt's wording. An import would have broken any preview harness without a `Services`
  symlink, and made the Common and Services modules depend on each other. Behaviour is the same once qs-core rewires SoundService.
- **McPanel is procedural**, using the exact pixel map of `gui/demo_background.png`, so Night skins and see-through fills work.
- **McText is a real `Text`** with a shadow child, so all Text API works. §-strings go in `codes:`, not `text:`.
- **GUI scale "auto"** = floor(min(w/960, h/540)), so 2 at 1920x1080. The game's own Auto would give 4.
- **Monocraft is crisp at 9 px × n, not 8 px × n** (grid is 120 units per pixel at upem 1080). The prompt said multiples of 8. Mojangles is 8 px × n;
  Monocraft gets its own size through `Theme.monoPx`.
- **"rainbow" cycles the whole string's hue**, as the game does for "Now Playing", not per character. Value is 0.95 rather than the game's 0.6, for legibility.
- **Splash colour is `#FFFF00`**, the game's title-screen constant, rather than §e `#FFFF55`.
- **The game has no pressed button sprite**, so `pressed` looks like hover. A focus ring was added for keyboard use (the game has none).
- **McScreen `background: "menu"`:** the 1.21 `gui/menu_background` is a translucent dark overlay, not dirt, so the world shows through.
- **Night grey sprites** (tabs) use a palette-swap shader, `nightRemap`. It maps to the Night palette whatever the current mode.
- **`shared.textures` legacy keys removed** (`paper`, `lacquer`, `seal_*`…). Those files no longer exist and nothing reads the keys (grep).
- Preview-only environment pins: `OW_MODE`, `OW_GUI`, `OW_REDUCED_MOTION`, `OW_NO_MOJANG`, `OW_PAGE`, `OW_SELFTEST`. The first four are read by Theme; none has any effect
  unless set.

## Verified

Last run 06:3x HKT on the final tree, unless noted.

| check | how | result |
|---|---|---|
| Contrast | `python3 tokens/build.py --check`: text roles and ANSI on every ground, both modes | 213 pairs per mode, 0 failing. Day ANSI 7/15 are dark greys. Worst: Day 4.57 (ANSI), Night 4.78 |
| No role key lost | compared generated keys with git HEAD for palette.json, hyprland, hyprlock, gtk, gtk4, zen, wlogout, rofi, starship, superfile, btop | 0 lost, 76 added per mode |
| Generated configs | build.py validators, tomllib, `rofi -dump-theme` | pass |
| Panel fidelity | image diff of McPanel at 248×166 against `gui/demo_background` | 0 differing pixels |
| Nine-slice fidelity | image diff of McNineSlice at 200×20 against `widget/button` | 0 differing pixels |
| Preview loads, Day and Night, pages 1-3 | log | `Configuration Loaded`, zero warnings |
| Full shell | `timeout 10 qs -p ~/Projects/overworld-hyprland/quickshell` | `Configuration Loaded`, 0 warnings from Common |
| Component logic | `OW_SELFTEST=1`, PASS/FAIL lines | 39 pass, 0 fail |
| Sound path | FIFO as `OW_CONFIG` proved `Theme.playSound` spawns `ow-sound`; dry-run only (run at 02:5x) | spawned, no `pw-play`, silent |
| Reduced motion | two captures 1 s apart, `OW_REDUCED_MOTION=1` (run at 02:5x) | 0 pixels changed |
| Tick motion | same, without the pin (run at 02:5x) | 1567 pixels changed; jiggling hearts row moved, static row 0 |
| Tick clock | self-test | 10 ticks in 500 ms; ticker acquires and releases |
| Tooltip placement | exact-position assertions plus viewing the screenshot | reparents to window, flips left, clamps to top |
| App icons | slots with `app:` + window titles (kitty, zen, spotify, nvim, hermes) | correct items via `_title_rules` |
| No-Mojang fallback | `OW_NO_MOJANG=1` (run at 02:5x) | works; gaps filed to asset-forge |
| GUI scale 3 and auto | `OW_GUI=3`, `OW_GUI=auto` (run at 02:5x) | crisp, correct layout |
| Live session | process list and config after each run | overview and apothecary shells untouched, config still `sounds:false`, mode file never written |

Screenshots, all viewed: `qa/screenshots/design-preview-day.png`, `-night.png`, `-day-2.png`, `-night-2.png`, `-day-gui3.png`, `-day-nomojang.png`,
`design-tooltip-placement.png`, `design-legacy-shell.png`.

Bugs found by these checks and fixed: `McScreen.open()` couldn't take focus while invisible; static tooltips never reparented, and misplaced themselves until layout
settled (one assertion passed wrongly until the screenshot showed it); notched boss bars lost their colour; the selected-slot frame was overdrawn by neighbours;
`Theme.widgetOpacity` read `widget_opacity` when the real config key is `widgets.opacity` (found by cross-checking the phase-2 prompts).

## Not verified

The safety rules forbid moving the pointer, and the preview never takes keyboard focus, so **no real input event has reached these components**:

- Real pointer hover, click and drag. Logic behind them is tested from code (`activate()`, `_setFromX`, `_setPos`, tooltip placement), and hover states through forced
  properties, but the `MouseArea` wiring itself has not fired.
- Real keyboard: Tab focus, Enter/Space, Esc on McScreen, arrow keys on McSlider, typing in McTextField. Cursor and focused looks were checked with `highlighted`.
- The mode cross-fade while running: each process is pinned to one mode, so the 500 ms fade was not watched.
- `gui_scale` and `reduced_motion` from `config.json` itself. The same code paths ran through the env pins, because the config must stay untouched during the build.
- The Night palette-swap shader on the Vulkan/other RHI backends: it compiled for GLSL, HLSL and MSL, and was only run on this machine's backend.

qa-reviewer should exercise the first two on the real shell.

## Open issues

- `tokens/make-textures.sh` and `tokens/check-glyphs.sh` are dead Apothecary scripts (they generate `assets/pd/`, CJK checks). Left in place; only they mention
  themselves now. Safe to delete.
- Unported modules through the wrappers look Minecraft but can overflow: Mojangles at 16 px is wider than the old 12-13 px fonts, and some still draw CJK titles. Expected
  until phase 2 rewrites them.
- The glint is alpha-blended at 0.7. The game blends additively, which would need another shader. Looks close enough on the items checked.

## Requests filed (docs/REQUESTS.md)

- qs-core: rewire `SoundService` to `scripts/ow-sound`.
- asset-forge: fallback tooltip sprites need the 8 px transparent margin; `toast/advancement` and `recipe` centres must be plain; add fallbacks for the animated
  textures and menu backgrounds.
- hyprland-engineer: new `$ow_borderActive/Inactive`, beziers `block` and `toast` in motion tokens, blur and shadow tokens off.
- app-theming, hyprland-engineer: Monocraft crisp at 9/18/27 px; `tokens/build.py` CSS prefix fixed to `ow`.
- qs-widgets: `quickshell/Widgets/preview` fails to load (no `Services` link for `BrewTimer.qml`, unrelated to Common); use `Theme.widgetOpacity`.
