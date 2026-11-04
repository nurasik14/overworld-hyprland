# app-theming report (phase 2) — DONE

Everything is in `apps/` + `docs/APPS.md` (read that for the per-app table and how the switch works).

## Deliverables
| area | paths |
|---|---|
| switch | `apps/lib.sh`, `install.sh`, `apply-mode.sh <light\|dark\|off> [--link-only] [--no-handback]`, `uninstall.sh`, test harness `apps/test/{sandbox,snapshot}.sh` |
| kitty | `kitty/overworld.conf` (template), `kitty/tab_bar.py` (hotbar tabs), `kitty/off.conf` |
| fastfetch | `fastfetch/overworld.jsonc` (F3 style + isometric grass block, 18x8 cells = 216 px square), `overworld-ascii.jsonc` + `creeper.txt` |
| rofi | `rofi/overworld.rasi` (creative inventory) |
| GTK3/4 | `gtk/*-tweaks.css`, `xsettingsd-*.conf` (sub-agent) |
| Kvantum | `kvantum/{build.py,build.sh,verify.py,gallery/,OverworldDay,OverworldNight}` (sub-agent) |
| qt6ct, superfile, btop, cava, swappy, starship | handled in install/apply-mode + `cava/config.{base,tail}`, `swappy/config.base`, `starship/overworld.toml` |
| Zen | `zen/{build.sh,userChrome-rules.css,userContent-rules.css,overworld*.css}` (sub-agent) |
| nvim | `nvim/colors/overworld-{day,night}.lua`, `nvim/lua/overworld/` (sub-agent) |
| spicetify, wlogout | `spicetify/Overworld/`, `wlogout/` (sub-agent) |
| cursor | asset-forge's `apps/cursor/` + gsettings/`hyprctl setcursor` in apply-mode; env request filed |

## Decisions that differ from the prompt
* **kitty font 13.5 pt, not 11**: design-director found Monocraft crisp only at 9/18/27 px (13.5 pt = 18 px at 96 dpi; cell 12x27). The fastfetch logo is sized to that cell (the prompt's 9x20 cell is for the old font).
* **install.sh is visually a no-op** (leaves links in the off state; no gsettings). Only `apply-mode light|dark` activates. Needed because Apothecary is live and shares every file.
* **Pre-theme values are re-captured on every off->on transition**, not at install, so `off` restores what the apps held when Overworld came on.
* **Zen**: while on, Apothecary's `@import` lines are neutralised (`@ow-off-import`) so the themes never stack; `off` restores them verbatim.
* GTK/Qt UI font = Overworld Mojangles 12 pt (16 px), fixed font Monocraft 13.5 pt; gtk-theme names stay real installed themes (Flat-Remix-GTK-Blue-*).
* Generator bug worked around in install.sh: `tokens/out/*/nvim-palette.lua` has `end = ...` (Lua keyword) -> quoted via sed (request to design-director filed by the nvim sub-agent in REQUESTS.md).

## Verified
* **Sandbox round trip** (`apps/test/sandbox.sh`: copy of the real configs + shims for gsettings/hyprctl/pkill; nothing live touched): install -> light -> dark -> off with handback to the real Apothecary `apps/apply-mode.sh` -> uninstall; after uninstall every file hash/link target equals the pre-install snapshot. Also `OW_PREVIOUS_THEME=stock` path and re-install idempotence.
* **Live round trip at the end** (the one allowed): pre-test snapshot of kitty/rofi/GTK/xsettingsd/qt6ct/Kvantum/superfile/btop/cava/starship/swappy/wlogout/fastfetch/Zen + gsettings, `apps/install.sh` (diff = only the 3 hook lines), `apply-mode.sh light` (previous theme auto-detected "apothecary dark"; gsettings -> Flat-Remix-GTK-Blue-Light / Papirus-Light / cursor Overworld / font Overworld Mojangles 12), test kitty `--class overworld-test` + fastfetch screenshot, `apply-mode.sh off` -> handed back to Apothecary dark: gsettings back to Flat-Remix-GTK-Blue-Dark / Papirus-Dark / Bibata-Modern-Classic / Noto Sans 10 / prefer-dark, all content hashes equal to pre-test, `~/.config/apothecary/apps-mode`=dark; then `apps/uninstall.sh`: the 253-entry file/link tree of those config dirs is byte-identical to before. `hyprctl configerrors` empty. (The user's 2 kitty windows + dropterm were config-reloaded by SIGUSR1 twice, as in Apothecary's own apply.)
* Config validation: kitty config parsed through kitty's own `load_config` (0 bad lines; 0.47 has no `--debug-config`), `rofi -dump-theme` (both modes, with colours), fastfetch runs of all 4 rendered configs, tomllib on starship + superfile themes, btop theme key set identical to Apothecary's working theme and values hex, nvim `-u NONE -c 'colorscheme overworld-day|night'` (554 groups, exit 0), GTK3/GTK4 CSS parse via gi (sub-agent), Kvantum XML + element-id check (sub-agent), `bash -n` on all scripts.
* Full shell load `timeout 15 qs -p quickshell`: "Configuration Loaded", 0 errors (my files are not QML).
* Screenshots (all viewed) in `qa/screenshots/`: `apps-kitty-night.png`, `apps-kitty-day.png`, `apps-kitty-live-day.png` (real config on the live round trip), `apps-rofi-{day,night}.png`, `apps-gtk3-{day,night}.png`, `apps-gtk4-night.png`, `apps-kvantum-{day,night}.png`, `apps-wlogout-{day,night}.png`, `apps-zen-mock-{light,dark}.png` (static Chromium mock, NOT Zen).

## Not verified / open issues
* **Zen**: never loaded in Zen (must not be restarted); CSS only syntax-checked + a Chromium mock. Takes effect at Zen's next start.
* **starship, spicetify**: CLIs not installed -> toml/ini validated only. The `[Day]/[Night]` custom command and hearts battery module were not executed.
* btop and superfile were not screenshotted (theme/keys validated, not seen). Kvantum: disabled widgets look faded, adjacent unselected tabs have no divider (sub-agent notes). GTK4 look seen only on a small test window; running GTK/Qt apps keep their old look until restarted.
* fastfetch in the test showed `Shell: kitty` / `Chat: Hyprland` because it ran under `sh -c`; in a normal shell it reports zsh/kitty.
* The previous-theme file (`~/.config/overworld/previous-theme`) does not exist yet (hyprland-engineer's): detection falls back to "Apothecary enabled / apps on", which works only while Apothecary is still on when the first apply runs; see the request.
* Papirus folder colour not done. Cursor theme untested inside Hyprland beyond `hyprctl setcursor Overworld 24` returning (asset-forge's note stands).
* wlogout assumes `wlogout -b 3`; Respawn icon is a flower-ish glyph (not a totem).

## Requests filed (docs/REQUESTS.md)
* -> hyprland-engineer: apps handover contract (previous-theme file before `apothecary off`, apps off hands back itself, install idempotent/no-op, cursor env vars XCURSOR_THEME/HYPRCURSOR_THEME/size, fonts used).
* -> design-director (filed by the nvim sub-agent): `tokens/build.py nvim()` must emit `["end"] = ...`.
