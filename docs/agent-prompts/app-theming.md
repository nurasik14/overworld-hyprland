# app-theming (phase 2) — every app wears the Overworld look

You own: `apps/` (all), `docs/APPS.md`.

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

Regenerate/rewrite every Apothecary app theme as Minecraft Day/Night (tokens from `tokens/out/<mode>/`; ask
design-director via REQUESTS.md for missing roles; you may add app-specific generators inside apps/):
kitty (font `Monocraft` 11, palette from tokens incl. ANSI, background_opacity 0.88, cursor block, tab bar
styled like hotbar slots if feasible), rofi (creative-inventory look), superfile (theme + config), fastfetch
(logo = isometric grass block from `assets/icons/mc/` via kitty-direct sized to the 9×20 px cell — compute
cells to keep it square — + ASCII creeper/grass-block fallback; keys styled like F3), cava, btop (theme),
starship (prompt with item glyphs: ❤ hearts? Nerd icons; `[Day]/[Night]` segments), spicetify (Overworld
color.ini + user.css, configs only if CLI absent), Zen browser (userChrome/userContent: Minecraft greys,
pixel bevel tabs, Monocraft UI font where sensible — keep it usable), nvim colourscheme (overworld-day/night),
GTK3/4 (gtk.css colours; `gsettings` theme name stays a real installed theme), Kvantum (Overworld Day/Night:
bevelled grey Minecraft buttons/panels in the SVG), qt6ct, icons (Papirus; folder colour optional), **cursor**
(asset-forge's `Overworld` cursor theme → `HYPRCURSOR_THEME`/`XCURSOR_THEME` via hyprland-engineer's
env file — write the request; you set gsettings cursor-theme in apply-mode), swappy, wlogout (Game-Menu
style buttons). `apps/install.sh` + `apps/apply-mode.sh <day|night|off>` (keep the light/dark/off API) must
round-trip: off restores exactly what was there before Overworld was applied — and when Apothecary was the
previous theme, `off` must hand the apps back to Apothecary's apply-mode (`~/Projects/apothecary-hyprland/
apps/apply-mode.sh <its mode>`) rather than to stock; coordinate with hyprland-engineer's `previous-theme`.
DO NOT apply to the live apps during the build except for one final verification round trip at the end:
`apps/apply-mode.sh light` → screenshots of kitty (open a test kitty with `--class overworld-test` on ws 77
via `hyprctl dispatch exec "[workspace 77 silent] kitty --class overworld-test …"`, run fastfetch in it),
then hand back to Apothecary dark (`~/Projects/apothecary-hyprland/apps/apply-mode.sh dark`) and verify the
user's kitty/GTK settings equal the pre-test values (record them first). Validate every config
(`kitty --debug-config`, `rofi -dump-theme`, tomllib, json, `btop --version` loading theme path, nvim
`--headless +colorscheme`). Report in `docs/agent-reports/app-theming.md`.
