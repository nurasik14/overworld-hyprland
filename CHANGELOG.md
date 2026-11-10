# Changelog

## Unreleased

### Now Playing PiP: like, repost and save TikTok clips from the PiP (tiktok-actions)
- With a logged-in TikTok tab in Zen (background or paused is fine), the PiP's hover controls get a second row: **like**,
  **repost**, **save** to a collection (config `nowplaying.tiktokCollection`, default `"Edits"`). Each is a toggle showing the
  clip's state (filled in colour = on, outline = off; repost "unknown" until first used). Un-saving un-favourites the clip, and
  TikTok then removes it from every collection. A missing collection is never created (the clip stays in Favorites only).
- The userscript clicks TikTok's own buttons for the clip the PiP showed, and refuses when TikTok shows another clip; one
  command at a time; failures shown on the picture and in the tooltip. Hidden for YouTube, Spotify and MPRIS-only sources.
- Bridge userscript **1.3.0** (reinstall: `overworld nowplaying userscript --serve`): the like / repost / save runner, the shown
  clip's state in its reports, a 1 s heartbeat while a TikTok clip is paused **only while the PiP is on**, ⏮ / ⏭ through
  TikTok's own feed-navigation buttons first, no stall-watchdog bounce while a button press runs.
- `hypr-nowplaying` (shared): stdin command `action`, per-tab queue delivered in the `/state` reply (`actions`, `poll`), `tt`
  state sanitised into the state file, `action` record (queued / sent / done / failed / expired / refused). Commands are
  accepted only on stdin, not over HTTP.
- Tests: daemon 119, bridge 72 (a fake logged-in TikTok page, the feed buttons and the stall watchdog), service 45,
  `preview/tt-act.qml` pointer test.

### Now Playing PiP: a floating mini-player that shows the video (now-playing-pip)
- A small painting on a GUI panel, always on top (layer `overworld-nowplaying`, Overlay: above fullscreen apps; `nowplaying.layer
  "top"` keeps it below them): title, channel / artist, source icon, XP-bar progress, the cover, and for **YouTube** (watch, Shorts,
  music videos) and **TikTok** the video itself as a **silent mirror** synced to the browser (rate nudge under 0.35 s of drift, a
  seek above it, no seeks while buffering; no audio output at all). Portrait frame for vertical clips, square for music.
- Drag (per monitor, from the nearest corner), resize from the corner grip, double-click = reset; hover ⏮ ⏯ ⏭ (MPRIS), focus the
  source window, ✕. Dims when paused, fades out after `autoHideSec` with nothing playing, hides while the source is the focused
  fullscreen window. Day and Night. Off until switched on: widgets menu row, `SUPER+ALT+P`, IPC target `nowplaying`,
  `overworld nowplaying on|off|toggle|status|reveal|reset|userscript|cache|bridge`.
- `hypr-nowplaying` (shared with Apothecary): a localhost-only, token-protected daemon the shell runs only while the PiP is on;
  downloads YouTube video-only ≤ 480p with yt-dlp (newest request wins, LRU cache 400 MB), takes TikTok clips from the browser.
- `apps/zen/nowplaying-bridge.user.js`: the Zen (Violentmonkey) bridge for YouTube, YouTube Music and TikTok; install with
  `overworld nowplaying userscript --serve`. Without it, YouTube still works from Zen's MPRIS URL, Spotify and others show cover + title.
- Config keys `nowplaying.{layer, autoHideSec, maxVideoMin, hideWhenSourceFullscreen, width, cacheMB, port, video}`. Docs: docs/NOWPLAYING.md.

### Notes: sticky notes for raw, stray thoughts (sticky-notes)
- A tenth desk card, **Notes**: a pad of Paper sheets with a pin, a perforated top and a folded corner. Click the sheet and you type on it: the same sheet opens right over the card on a layer that takes the keyboard (`overworld-notes`), saved 700 ms after the last key and on close, empty sheets dropped. Page counter, flip with the arrows or the wheel, `+`, tear off with crumbs and a 5 s Undo.
- `SUPER+ALT+N` (a blank sheet), chat `/note <text>` / `/note` / `/note list`, IPC target `notes`, `overworld notes …`.
- `hypr-notes`: a standalone CLI that owns the shared pad `~/.local/share/hypr-notes/notes.json` (`list`, `add`, `add -` for stdin, `show`, `rm`, `edit` in `$EDITOR`, `clear`, a rofi `menu` on `SUPER+ALT+N` while no theme is on).

## 1.0.0 - 2026-11-05

First release. Overworld Hyprland is a fork of the Apothecary Hyprland theme (commit 26a8391), renamed and rebuilt as a Minecraft-inspired
desktop in one overnight, multi-agent build, then QA-tested live. Everything from Apothecary is kept; the two themes coexist and the CLI
switches between them. Details per area are in `docs/agent-reports/` and `qa/REPORT.md`.

### Theme system
- `overworld on | off | status | light | dark | toggle | reload | repair`. `on` switches Apothecary off first and remembers it; `off` restores
  Apothecary (in its mode) or the stock JaKooLit desktop. State survives reboots. (hyprland-engineer)
- `scripts/install.sh` / `scripts/uninstall.sh`: one hook line in `hyprland.conf`, linked layer, shell and CLI; idempotent and reversible.
- Two modes: Day (`light`) and Night (`dark`), generated from one `tokens/tokens.json` by `tokens/build.py` (design-director).

### Design system (design-director)
- `quickshell/Common/`: `Theme` singleton (GUI scale, texture lookup with Mojang, generated and missing-texture fallbacks, 20-tick clock) and the `Mc*`
  components: panel, nine-slice, sprite, animated sprite, button, slot, text with drop shadow, tooltip, text field, slider, checkbox, tabs,
  progress bar, toast, screen, splash, scrollbar, heart/hunger/armor/air rows. Old Apothecary components remain as wrappers.
- `docs/DESIGN.md`.

### HUD and screens (qs-core)
- Hotbar for workspaces 1-10 (busiest app as the item, window count as the stack), hearts (battery), hunger (RAM), air (CPU), XP level and bar (uptime),
  boss bar (brew timer or playing media), tray and status slots, /title workspace card.
- Launcher as creative inventory (tabs, 9-column grid, tooltips, `=` calculator, `>` run). Toasts, chat-history notification centre, Peaceful (DND).
  Multiplayer network screen, Game Menu, Select World wallpaper picker with Create New World, Options-slider OSD, brewing-stand dialog.
- Services: sound, config (live `config.json`), system stats, time, shell state, Hyprland state, network, notifications, workspace notes.
- Claude workspace auto-labelling (`overworld ws auto`) carried over from Apothecary.

### Desktop widgets (qs-widgets)
- Eight cards: Weather (sky window with real moon phase, 24 h block columns), Jukebox, Clock and Calendar, System (F3), Note Block (cava),
  Sign (quotes and splash), Block of the Day, Brewing Stand. Draggable, persisted positions, per-card toggles, opacity setting.

### Game systems (qs-features)
- Chat console with 19 commands, tab completion, history, fading chat log. Four game modes and the switcher overlay.
- 60 advancements in five tabs with a tree screen and toasts; statistics screen; Options screen editing `config.json` live.
- Event bus bridge so window, workspace, battery, XP, mode and Wi-Fi events reach the game logic exactly once.

### World effects (fx-world)
- Local sunrise/sunset maths drive an automatic Day/Night cycle with time-of-day wallpapers; Open-Meteo weather overlay (rain, snow, thunder with
  lightning), overridable by `/weather`; F3 debug screen with optional frame graph.

### Interactions (fx-interactions)
- Block-break window close (`SUPER+Q`) with crack stages, break particles from the window's own colours and material sounds; block-place on open;
  screenshot wrapper with chat line and pickup pop; low-battery hurt warning and "You died!" screen; XP orbs on level-up.

### Hyprland layer (hyprland-engineer)
- Decorations, animations (place pop-in, 350 ms workspace slide), window and layer rules, keybinds (every Apothecary key kept, new game keys added,
  displaced JaKooLit actions re-homed), title-screen hyprlock, hypridle, SDDM theme with rotating panorama (sudo step), themed wlogout.

### Assets and sounds (asset-forge, world-renderer, lore-writer)
- `scripts/fetch-minecraft-assets.sh`: builds `assets/mc/` from a local `~/.minecraft` or Mojang's servers; Mojang assets are never committed.
- `Overworld Mojangles` bitmap font and item icons built locally; original fallback art and sounds in `assets/gen/`; 58 sound ids in
  `tokens/sounds.json` played by `scripts/ow-sound` (silent when `sounds` is false, `OW_SOUND_DRYRUN=1` for tests).
- `tools/worldgen`: a voxel ray marcher using the game's models and textures; 8 Overworld biomes, Nether, End, your own saves; 13 Day and 17 Night
  wallpapers plus dawn/dusk variants; panorama, lock frames, `scripts/make-world.sh`.
- Text: 272 splashes, 125 blocks/mobs of the day checked against minecraft.wiki, 60 advancements, chat texts, titles, quotes.

### App theming (app-theming)
- kitty (hotbar tab bar), fastfetch (F3 style), rofi, GTK 3/4, Qt via Kvantum and qt6ct, superfile, cava, btop, swappy, starship, Zen, nvim,
  spicetify, wlogout, cursor theme; `apps/apply-mode.sh` is the switch.

### QA pass (qa-reviewer)
- 21 fixes from live testing, including: workspace titles taken over by the theme, idle CPU from 20.8 % to 2.7 %, event bus dropping lines under
  load, a kitty start race, readability and overlap problems. Regression checks: `check-config.sh`, `handover-sandbox.sh`, shell self-tests.

### Documentation (docs-writer)
- Rewritten `README.md` (feature tour, first run, CLI, config keys), new `docs/GUIDE.md` (how it works, tracing SUPER+Q, recipes, debugging),
  annotated layer files in `docs/HYPRLAND-GUIDE.md`, this changelog.

### Known limitations
See "Open issues" in `qa/REPORT.md`. Notably: GUI scale 3 at 1080p overflows the widget columns; btop needs a taller window with Monocraft;
real keyboard and pointer input, hyprlock, SDDM as a real greeter and audible sound were not tested; the SDDM theme still needs its sudo step.
