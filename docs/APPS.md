# Application theming (app-theming)

> **Theme system, switchable.** Overworld Hyprland is a theme system layered on top of the JaKooLit Hyprland
> dotfiles (and coexisting with the Apothecary theme), not a replacement for them. `overworld on` / `overworld off`
> switch it; `overworld off` runs `apps/apply-mode.sh off`, which puts every app setting back **exactly** as it was and,
> when Apothecary was the previous theme, hands the apps back to Apothecary's own `apps/apply-mode.sh <its mode>`.

Everything the user runs outside the Quickshell shell, themed as Minecraft **Day** (`light`) and **Night** (`dark`).
The CLI/internal mode names stay `light|dark|off`; user-facing names (theme files, colourschemes, Kvantum themes) are
`overworld-day` / `overworld-night`. Colours come from `tokens/out/<light|dark>/` (design-director), never hand-copied.

```
apps/install.sh            place theme files, `.pre-overworld` backups, hook lines, ~/.config/overworld/<app>/current* links.
                           VISUALLY A NO-OP: leaves everything in the *off* state, touches no gsettings/keys. Idempotent.
apps/apply-mode.sh <m>     light | dark | off [--link-only] [--no-handback] — the real switch (below).
apps/uninstall.sh          apply-mode off --no-handback, then every `.pre-overworld` backup moved back, markers stripped,
                           created files removed.
apps/lib.sh                helpers: state json, backup_file, replace_with_symlink, append_marker, set_kv/restore_kv,
                           detect_previous / capture_pre / apo_apps_wait (Apothecary coexistence).
apps/test/sandbox.sh       throw-away copy of the app configs + shims for gsettings/hyprctl/pkill/kitty → the round trip
                           can be run without touching the live desktop; apps/test/snapshot.sh fingerprints the result.
```

## How the switch works (and why it is safe next to Apothecary)

Apothecary and Overworld replace the *same* user files (`kitty.conf`, `gtk.css`, `cava/config` …). Each keeps a
`<file>.pre-<theme>` backup and a `~/.config/<theme>/<app>/current*` symlink it flips.

* **install** hooks every file but points each `current*` link at the file's own backup (the *off* state) → the user's
  desktop does not change when Overworld is merely installed. The user file chain is
  `gtk.css → overworld/gtk/current-gtk3.css → gtk.css.pre-overworld (→ apothecary/gtk/current-gtk3.css → …)`, so while
  Overworld is off Apothecary's flips still reach the file.
* **apply-mode light|dark** — on the first call after `off` (`capture_pre`): waits (≤ 25 s) for a still-running
  `apothecary off` apps restore (its script runs detached), forgets any older recorded values and records what gsettings
  and the sed'd keys hold *now* as the "pre-theme" values, and records the previous theme: `OW_PREVIOUS_THEME`, else
  `~/.config/overworld/previous-theme` (`apothecary <light|dark>` | `stock`, written by hyprland-engineer's `overworld on`),
  else "Apothecary enabled / its apps on". Then it flips every link to the mode, sets gsettings (colour-scheme, GTK theme
  Flat-Remix-GTK-Blue-Light/Dark, Papirus-Light/Dark, cursor **Overworld**, font **Overworld Mojangles 12**), `hyprctl
  setcursor Overworld 24`, the qt6ct / Kvantum / superfile / btop keys, the Zen `@import` lines, reloads kitty (colours via
  `kitty @ set-colors` on any socket + SIGUSR1 config reload).
* **apply-mode off** — links back to the backups, keys + gsettings restored from `apps-state.json`, Zen imports removed,
  then (previous theme Apothecary) `~/Projects/apothecary-hyprland/apps/apply-mode.sh <its mode>`; for `stock` nothing else.
* One apply at a time (`flock`), never restarts a program except the kitty config reload. Running GTK/Qt apps pick up
  `gtk.css`/qt6ct on their next start; Zen reads userChrome at its next start.

State: `~/.config/overworld/apps-state.json` (pre-theme gsettings + key values, `previous.theme`, backups/markers/created/
files lists), `~/.config/overworld/apps-mode` (`light|dark|off`).

## Per app

| app | repo files | what it does |
|---|---|---|
| **kitty** | `kitty/overworld.conf` (template), `kitty/tab_bar.py`, `kitty/off.conf` | Font `Monocraft` **13.5 pt** (= 18 px em, the size where the pixel font is crisp; 12×27 px cell — design-director: crisp only at 9/18/27 px, so not 11 pt), tokens palette incl. ANSI, `background_opacity 0.88`, block cursor without trail, padding 6. **Hotbar tabs**: `tab_bar_style custom` + `tab_bar.py` (linked to `~/.config/kitty/tab_bar.py`): every tab is a slot, the active one has the white selection frame, extra windows show as a stack count (`×2`). The template is rendered per mode by install.sh to `~/.config/overworld/kitty/overworld-<mode>.conf` and included last from `kitty.conf` via `include ~/.config/overworld/kitty/current.conf` (the path is the marker). |
| **fastfetch** | `fastfetch/overworld.jsonc`, `overworld-ascii.jsonc`, `creeper.txt` | F3 debug-screen vocabulary (`Version: … (fedora/vanilla)`, `Time Played`, `Items` = packages, `Dimension` = WM, `Chat` = terminal, `Mem: 53% …`, `World` = disk, a `Splash:` line from `quotes/splashes.json`). Logo = isometric **grass block** (`assets/icons/mc/64/grass_block.png`, fallback `assets/gen/icons/64/`) ×3 nearest-neighbour on a 216 × 216 px canvas = **18 × 8 cells of the 12 × 27 px kitty cell**, so `kitty-direct` stays square. ASCII creeper config for other terminals / missing art. Colours inlined from the palette per mode. |
| **rofi** | `rofi/overworld.rasi` | Creative-inventory look: grey bevelled panel titled "Search Items" (rofi has no multi-colour border, so bevels are nested boxes), black text field, 2-column app rows with the icon in a slot, white-frame hovered slot, creative-inventory-style tabs for the modes, scroller. Mojangles 12 pt. `@theme` line appended to `config.rasi` (last wins; JaKooLit menus `@import` config.rasi and override after). |
| **GTK 3/4** | `gtk/gtk3-tweaks.css`, `gtk4-tweaks.css`, `xsettingsd-{light,dark}.conf` | tokens `gtk-colors.css` (+ `gtk4-vars.css`) + Minecraft tweaks (0 radius, bevelled buttons, black text fields, purple tooltips, XP-green progress) concatenated by install.sh. `gsettings` names stay real installed themes (Flat-Remix-GTK-Blue-*, Adwaita fallback). |
| **cursor** | `cursor/` (asset-forge) | `Overworld` Xcursor + hyprcursor theme in `~/.local/share/icons/Overworld`. apply-mode sets gsettings `cursor-theme` + `hyprctl setcursor Overworld 24`; env vars (`XCURSOR_THEME`, `HYPRCURSOR_THEME`) are hyprland-engineer's (request filed). |
| **Qt: qt6ct + Kvantum** | `kvantum/` (generator `build.py`, themes `OverworldDay`, `OverworldNight`) | Kvantum themes drawn as bevelled Minecraft widgets (SVG generated from the palette); qt6ct colour scheme from tokens, `style=kvantum`, `icon_theme=Papirus-*`, fonts Overworld Mojangles 12 / Monocraft 13.5. |
| **superfile** | (tokens) | `~/.config/superfile/theme/overworld-{day,night}.toml` (token theme + chroma `github`/`monokai`); `config.toml`: `theme`, `transparent_background`, `default_open_file_preview`, `nerdfont`, `editor` only if it was empty, `zoxide_support` if zoxide exists — all restored on off. |
| **cava** | `cava/config.base`, `config.tail` | base (3-px bars) + tokens `[color]` gradient, rendered per mode; `~/.config/cava/config` is a link. |
| **btop** | (tokens) | `themes/overworld-{day,night}.theme`; `color_theme`, `theme_background=false`, `rounded_corners=false`, `graph_symbol=block` (chunky). Run it as `overworld btop` (`scripts/ow-btop`): btop needs 24 rows and Monocraft's 27 px lines leave a half-height tile only 20, so below 30 rows it reopens in its own kitty window (class `btop`) at 6.75 pt = Monocraft's crisp 9 px size (40 rows per half screen); `OW_BTOP_MIN_ROWS`, `OW_BTOP_FONT_PT` tune it. `alias btop='overworld btop'` makes plain `btop` do it. |
| **starship** | `starship/overworld.toml` | ❤ badge, Nerd icons, powerline arrows, XP-coloured duration, hearts only when the battery is low, `[Day]`/`[Night]` custom segment from `~/.config/overworld/mode`. Starship is **not installed** here: validated with tomllib only. |
| **spicetify** | `spicetify/Overworld/{color.ini,user.css}` | `[day]`/`[night]` schemes + bevelled Minecraft CSS; applied only if the CLI exists (it does not here). |
| **Zen** | `zen/` (`build.sh` → `overworld.css`, `overworld-content.css`) | Minecraft chrome (bevelled tabs/buttons, black URL bar, tooltip-style menus, 0 radius, Monocraft UI font), `about:` pages in `userContent`. Real copies in `<profile>/chrome/`; apply-mode adds `@import url("overworld.css")` and neutralises Apothecary's import (`@import` → `@ow-off-import`, an unknown at-rule) so the themes never stack; `off` reverses both. Takes effect at Zen's next start. |
| **nvim** | `nvim/colors/overworld-{day,night}.lua`, `nvim/lua/overworld/` | colourschemes `overworld-day` / `overworld-night` (554 groups, ≥ 4.5:1 syntax colours), `require('overworld').auto()` follows `~/.config/overworld/mode`. Installed under `~/.local/share/nvim/site`, never touches `~/.config/nvim`. Palettes come from tokens (`end` key quoted by install.sh: Lua keyword bug in `tokens/build.py`, request filed). |
| **wlogout** | `wlogout/{layout,style.css,gen-icons.py,icons/}` | Game-Menu buttons (Lock, Save and Quit to Title, Sleep in Bed, Hibernate, Respawn, Quit Game) with pixel item icons; menu-gradient background. Assumes `wlogout -b 3`. |
| **swappy** | `swappy/config.base` | Mojangles text, red = the `error` token. |
| icons / fonts | — | Papirus-Light / Papirus-Dark; fonts see above. Papirus folder colour not done (`papirus-folders` absent). |

## Verification

See `docs/agent-reports/app-theming.md` for the exact list of what was run, screenshots and what was not verified.

## Known gaps

* Running GTK/Qt apps and Zen keep their old look until restarted (apply-mode restarts nothing).
* Starship, spicetify are not installed on this machine → configs only validated syntactically.
* `tokens/out/*/fastfetch-colors.jsonc` and `nvim-palette.lua` have generator bugs (see REQUESTS.md); install.sh works around them.
