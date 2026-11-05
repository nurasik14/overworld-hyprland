# readme-showcase report (follow-up: demo photos + capability showcase)

Run: 2026-11-05 afternoon, user at the desk. No new screenshots, no theme switching, no sound, no commits, no sudo. All images are built
from existing files with ImageMagick (`qa/screenshots/qa-*`, `fx-*`, `qs-core-*`, `apps-*`, `hyprland-engineer-*`, `asset-forge-cursor`,
`assets/renders/panorama/strip.png`, `assets/wallpapers/`, `assets/gen/wordmark/overworld.png`). Build scripts live in `/tmp/rs/` (not kept).

## Deliverables
- `README.md`: OVERWORLD wordmark, Day|Night hero, Day/Night animation, a **Showcase** (HUD, Screens, Game systems, World effects, Interactions,
  Wallpapers and worlds, Lock and login, Apps, Cursor), then the previous content (theme system, feature tour, install, first run, keybinds,
  CLI, config, layout, docs, credits) kept. The old "Screenshots" section (Apothecary leftovers + "not committed") was removed; credits got the
  Mojang-assets-for-demonstration note.
- `docs/screenshots/`: the 11 Apothecary `.webp` files were deleted (`git rm --cached` was run on them too, so the deletion is staged; nothing committed)
  and replaced by 46 new files, 4.3 MB in total (target 12 MB).
- `.gitignore`: untouched. `git check-ignore docs/screenshots/*` returns nothing (not ignored).

## Verification
- Every candidate was viewed (Read) before use; a script extracted every image path from README.md and `test -f`'d each: 47/47 resolve
  (46 in `docs/screenshots/` + the wordmark), and every file in `docs/screenshots/` is referenced.
- Keys and commands in captions were taken from docs/KEYBINDS.md and quotes/chat.json (`/weather`, `/title`, `/locate`), not invented.
- The two animations (`45-day-night.webp`, `46-weather-cycle.webp`, 127 and 182 KB) are animated WebP built from the QA stills (2 and 3 frames).
- Not verified: how GitHub renders the HTML tables (no browser/preview used; plain `<table>`, `<img width>`, `<sub>`).

## Image list
| file | size | bytes |
|---|---|---|
| `01-hero-day-night.webp` | 1600x900 | 209 KB |
| `02-desktop-day.webp` | 1600x900 | 233 KB |
| `03-desktop-night.webp` | 1600x900 | 184 KB |
| `04-hud-closeup.webp` | 1040x240 | 46 KB |
| `05-xp-levelup.webp` | 640x240 | 121 KB |
| `06-launcher-day-tooltip.webp` | 880x560 | 156 KB |
| `07-launcher-calc-night.webp` | 880x560 | 90 KB |
| `08-toasts.webp` | 480x243 | 2 KB |
| `09-chat-history.webp` | 540x1000 | 114 KB |
| `10-chat-adventure-mode.webp` | 1600x900 | 215 KB |
| `11-gamemode-switcher.webp` | 700x300 | 68 KB |
| `12-spectator-mode.webp` | 1280x720 | 111 KB |
| `13-advancements.webp` | 840x700 | 45 KB |
| `14-statistics.webp` | 900x1080 | 30 KB |
| `15-options-day.webp` | 800x420 | 99 KB |
| `16-options-sounds-night.webp` | 800x420 | 65 KB |
| `17-game-menu.webp` | 560x440 | 42 KB |
| `18-select-world.webp` | 1280x720 | 61 KB |
| `19-multiplayer-network.webp` | 700x1080 | 31 KB |
| `20-osd-volume.webp` | 560x200 | 68 KB |
| `21-osd-brightness.webp` | 560x200 | 73 KB |
| `22-title-workspace-card.webp` | 760x240 | 145 KB |
| `23-brewing-dialog.webp` | 760x470 | 53 KB |
| `24-brewing-bossbar-chat.webp` | 1600x900 | 242 KB |
| `25-f3-debug.webp` | 1600x900 | 208 KB |
| `26-weather-rain.webp` | 1280x720 | 116 KB |
| `27-weather-snow.webp` | 1280x720 | 156 KB |
| `28-weather-thunder.webp` | 1280x720 | 100 KB |
| `29-death-screen.webp` | 1280x720 | 85 KB |
| `30-mining-day.webp` | 560x330 | 33 KB |
| `31-mining-night.webp` | 560x330 | 25 KB |
| `32-kitty-fastfetch.webp` | 1160x660 | 35 KB |
| `33-nvim-statusline.webp` | 1160x370 | 131 KB |
| `34-gtk3-day.webp` | 600x560 | 36 KB |
| `35-gtk3-night.webp` | 600x560 | 36 KB |
| `36-kvantum-night.webp` | 1000x872 | 32 KB |
| `37-kvantum-day.webp` | 1000x872 | 28 KB |
| `38-wlogout.webp` | 1280x720 | 11 KB |
| `39-cursors.png` | 640x488 | 6 KB |
| `40-lock-screen-simulated.webp` | 960x540 | 40 KB |
| `41-sddm-login-testmode.webp` | 960x540 | 65 KB |
| `42-panorama-strip.webp` | 1600x300 | 87 KB |
| `43-your-own-saves.webp` | 900x1271 | 162 KB |
| `44-wallpapers-sheet.webp` | 1600x1016 | 198 KB |
| `45-day-night.webp` | 960x540 | 127 KB |
| `46-weather-cycle.webp` | 960x540 | 182 KB |

Sources: 01-03 qa-01 day/night; 04 qa-01-night crop; 05 qa-36; 06 qa-02-day; 07 qa-03b-night; 08 qa-07-day; 09 qa-08-night; 10 qa-26; 11 qa-18-night;
12 qa-24; 13 qa-15-day; 14 qa-16-night; 15 qa-17-options-day; 16 qa-17-options-sounds-night; 17 qa-05-night; 18 qa-06-day; 19 qa-04-night;
20 qa-09-night; 21 qa-10-day; 22 qa-11-night; 23 qa-12-night; 24 qa-27; 25 qa-19-f3-night; 26 qa-20-rain-night; 27 qa-21-snow-day; 28 qa-22-thunder-night;
29 qa-23-death-day; 30/31 qa-28-mining crops; 32 qa-30; 33 qa-33 (crop); 34/35 apps-gtk3; 36/37 apps-kvantum; 38 qa-34 wlogout; 39 asset-forge-cursor;
40 hyprland-engineer-lock-sim-day; 41 hyprland-engineer-sddm-night; 42 assets/renders/panorama/strip.png; 43 world-renderer-sheet-saves;
44 montage of 16 wallpapers from `assets/wallpapers/{light,dark}` (labels = file names); 45/46 animations.

## Privacy scrubs (pixelated, 12 % downscale/upscale, text unreadable)
- 01-03, 25 (qa-01 day/night, F3 night): Weather card location line, Jukebox album art, Jukebox track/artist marquee.
- 24 (qa-27): same three, plus the Zen window title in the status strip at the bottom left (a YouTube tab title).
- 26-29 (rain, snow, thunder, death) and 20 (volume OSD): same three.
- 25 (F3): also the right-hand F3 column's battery/network-adjacent lines and the part over the calendar card.
- 19 (network): all four Wi-Fi names (incl. a campus SSID and a CityU public one), the VPN name; "eduroam"-like generic names are blurred too. Interface
  names `enp44s0` / `wlp0s20f3` and security/band lines are left (no MAC/IP anywhere).
- 41 (SDDM): one text line under the clock (account/user line).
- Left on purpose: the in-game name "Nurasik"; `nurasik12@nurasik12` in the System card and fastfetch (it is already in LICENSE as the copyright holder; blur it
  if you prefer); the boss bar "Now Playing: RAINING IN KYOTO (Lofi HipHop) ..." in a few images (a public YouTube track; its art and the Jukebox text are blurred);
  the `dev-env.sh` file name in the nvim status line.
- Not used because they contained personal paths or a real project: the btop shot (terminal too small), the `ls -la` terminal shot (hypr-on-night), the
  quick chat shots with `/home/nurasik12/Projects/...` dry-run lines, qa-04-day (replaced by a scrubbed night version only).

## Rejected candidates
Apothecary bar/cards under the preview (`qs-core-*`, `qs-features-*`, `design-*`, `fx-interactions-burst/mine-mid/dust/pickup/xp-orbs/shots`, `hypr-on-*`,
`apps-*-live`, `qs-core-power-confirm-dark`, `qs-core-wallpapers-create-dark`), the rofi QA shot (shows rofi theme warnings), btop (size warning), superfile
(empty), the GUI-scale-3 shots (overflow, see qa/REPORT.md), stats tab 2 (empty).

## Open issues / gaps
- **No clean capture** of: the quit confirm screen, the "Create New World" loading screen, a real hyprlock frame (the lock image is a labelled simulation),
  a mining stage on a real app window (only a flat-colour QA window; the tiled crack pattern looks busy), block-place dust, the screenshot pop. These are
  described in text only. If you want them, a fresh `scripts/dev-shot.sh` run (when you are away from the desk) would add them.
- The F3 shot has F3 text colliding with the Weather card (that is how F3 draws over the cards; qa/REPORT.md notes it).
- Nvim shot is a crop (a lualine/lazy.nvim notification from the user's own plugins sat above it).
- Images were not blurred for the hero's System card username (see above).

## Requests filed
None.
