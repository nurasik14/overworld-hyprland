# Changelog

## Unreleased

### Notes card: the Book and Quill writing screen (notes-book)
- The Notes card is now the **open page of Minecraft's Book and Quill** instead of a pinned sheet of Paper: the real `book.png` page at the GUI scale (read from `assets/mc`, never copied; a drawn page stands in without it), your note in black Minecraft text inside the game's text box, **"Page 2 of 5"** top right, the real **page-turn arrows** (hover = the highlighted sprite) at the bottom, **+** for a new page, the wheel still flips. Hover the page: **✕** tears it out (bits of the page fall, Undo for 5 s). The card is 160×204 GUI px; saved positions are kept and clamped onto the screen. The Projects card is unchanged.
- The editor is the game's **Book and Quill edit screen**, one scale step bigger over the card: the game's cursor (`_` / thin bar), page arrows (▶ on the last page starts a new page), and under the book **New page · Tear out · Done** in the game's button style. **Esc** = Done, **PgUp / PgDn** or **Alt+←/→** flip pages. Saving, the 4000-character limit, the CLI, IPC and the data file are unchanged.
- Tests: `preview/notes-render.qml act` gained 16 checks for the book screen (arrows, PgUp/PgDn, Alt+arrows, New page / Tear out / Done); `tests/widgets-layout.test.js` uses the new card size. `PaperSheet.qml` is gone.

### Clock & Calendar card: interactive, with your Google Calendar events (calendar-interactive)
- The card (now 190×182 GUI px) shows the events of your Google Calendar. **Hover** a day: slot highlight and a Minecraft tooltip with that day's events (time, coloured tag, title). Days with events carry a **stack count** in the slot's corner. **Click** a day: the month folds into its week and the **agenda** opens below (scroll with the wheel, hover a row for the details, click an event to open it in the browser). **Double-click** a day or press **+**: a quick-add panel over the card takes a natural line (`14:00 Meeting @MMW2450`, `9:30-11 Lab`, `all day Exam`) with a live preview, and creates the event. Month arrows and the wheel change month (week in the agenda view); the month name = today.
- Under the clock: "Next: 14:00 Lab" and how many events are left today, yellow when one starts within 15 minutes; the CityU teaching week ("Wk 13") next to "Day N". Footer states: synced / last sync / grey "offline · last sync 14:02" (the cached events stay) / "Not connected".
- New shared CLI **`hypr-gcal`** (`sync list today next status add parse open`, one copy per theme repo, `~/.local/bin/hypr-gcal` linked by `install.sh`) and `overworld calendar|gcal …` (+ `overworld help calendar`). It only **reads** Google (the only write is `add`; `HYPR_GCAL_DRYRUN=1` prints the command instead); event titles are cached locally in `~/.cache/hypr-gcal/events.json` and go nowhere else. The cache is written in place under a lock and a failed sync (offline, VPN) keeps the last good events. The default backend is Hermes' `google_api.py`, run with a Python that has the Google libraries; `HYPR_GCAL_BACKEND` or `~/.config/hypr-gcal/config.json` point it elsewhere.
- IPC target `calendar` (`sync day today next prev add status list upcoming open close newEvent openEvent`), the quick-add layer `overworld-calendar` (keyboard Exclusive like the Notes editor; one modal at a time), `CalendarService` syncs every 10 min, after a resume and after an add.
- Tests: `tests/hypr-gcal.test.sh` (CLI), `Widgets/preview/calendar-test.qml` and `calendar-render.qml` through `calendar-render.sh` (service, renders, real clicks / keys), `tests/widgets-layout.test.js` (the taller card still fits at GUI 1–2).

### Day cycle: pin dawn or dusk
- `/time set dawn|dusk`, `overworld daycycle dawn|dusk`, IPC `world daycycle dawn|dusk`, and the Options button (Auto → Day →
  Dusk → Night → Dawn) pin the current scene's dawn or dusk picture with Day (dawn) or Night (dusk) mode. Before, those
  pictures only appeared through the automatic cycle and could not be chosen. Scenes without the variant keep their picture.

### Now Playing PiP: long YouTube videos get their picture in parts (nowplaying-chunks)
- Videos longer than `nowplaying.maxVideoMin` (default 20) used to show only the cover. Behind the author's VPN even a 120-min limit
  did not help, because each fetch is capped at 300 s and ran at ≈ 160 KB/s. Now such videos (not live, **no length limit**) are fetched in **parts around the
  position**: a 5-min part where you are (the picture appears after about a minute), then 40-min parts that overlap the previous one by
  8 s + the keyframe pre-roll, the next one when less than 5 min is left ahead. A seek outside the fetched range starts again there.
  `maxVideoMin` now only decides "whole file or parts".
- 360p, video only (`partHeight`), normal cache files `youtube-<id>.part-<startMs>-<endMs>.mp4` (true timeline range, found again after
  a restart) under the same `cacheMB` LRU. Parts more than 10 min behind are deleted; the shown part and the next one never are.
- Where a part really starts is **measured, not assumed**: yt-dlp cuts at the keyframe before the asked start and hides the extra frames
  in an MP4 edit list (3.707 s for a cut at 50:00, 3.175 s at 50:28). The daemon reads the edit list and keeps those frames
  (`ffmpeg -ignore_editlist`). Frame-matched against an exactly cut copy: within one frame.
- The PiP plays parts with **two players** (`MirrorStack.qml`): the next part is preloaded, starts in sync when the browser reaches it,
  and takes over 1 s before the current part ends, with no flash. Status line `video parts 2/3 ready`.
- Config `partFirstMin` 5, `partMin` 40, `partAheadMin` 5, `partHeight` 360. `hypr-nowplaying serve --part-first-min/--part-min/
  --part-ahead-min/--part-height`; `status` lists the part ranges, `cache list` the part files. An MPRIS-only long YouTube video sends its
  position with `want` (every 5 s, at once on a jump or pause). The userscript is unchanged (still 1.4.1).
- Tests: daemon 165 (+21, a fake yt-dlp that cuts a real test video like yt-dlp), service 80 (+8), sync 44 (+19),
  `preview/parts-test.qml` (real parts across a boundary).

### Now Playing PiP: choose which tab / app it shows (nowplaying-sources)
- With several things playing or paused (two YouTube tabs, YouTube + TikTok, + Spotify…), hover the PiP: a **source chip**
  `YouTube 2/3` top left. Click = a list **inside the PiP** (Auto + one row per source: ▶/⏸, site, title); the wheel over the chip
  cycles. **Auto** = the old rule; choosing a row **pins** it until that source goes away (then Auto again); the pin survives a shell
  reload, not a logout. `overworld nowplaying sources` / `pick <n|next|prev|auto>`, IPC `nowplaying sources` / `pick`.
- Sources = every bridge tab (YouTube, YouTube Music, TikTok) + every MPRIS player not already shown as a tab (deduped by title).
  Zen has one MPRIS player for all its tabs, so tabs on other sites cannot be listed one by one.
- Controls act on the **shown** source: a pinned tab that Zen's MPRIS does not follow gets ⏯ ⏮ ⏭ through the bridge (its own
  `<video>`, YouTube's next button, TikTok's feed step); a background `play()` the browser refuses is reported, not retried.
- Bridge userscript **1.4.0** (reinstall: `overworld nowplaying userscript --serve`): per-tab play / pause / toggle / next /
  previous, `done` results, a 2 s keepalive for paused tabs and a 1 s heartbeat for a pinned one **only while the PiP is on**, two
  reconnect checks after a daemon restart.
- `hypr-nowplaying` (shared): `tabs` (every fresh tab, sanitised like `bridge`) and `pin` in state.json, stdin `pin`, media actions
  in the per-tab queue (any site, not bound to a clip), `keepalive` in the reply, `status` lists the tabs.
- Bridge **1.4.1**: `@sandbox JavaScript` so it also runs under **Tampermonkey in Google Chrome** (page world: YouTube's player
  object and media session reachable). Chrome's MPRIS has no URL, so a Chrome YouTube tab needed the bridge to get its video.
- Fix: the PiP stayed hidden as "source fullscreen" after leaving a fullscreen video (seen with Chrome): `lastIpcObject` is a
  snapshot that nothing refreshed on a fullscreen change; the service now calls `refreshToplevels()` on Hyprland `fullscreen` /
  `activewindowv2` events.
- Fix (orchestrator, tested here): a **maximized** source window (Hyprland `fullscreen = 1`) no longer hides the PiP; only real
  fullscreen (bit 2) does.
- Tests: daemon 144, bridge 91, service 72, `preview/src-act.qml` pointer test (17).

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
switches between them. QA details are in `qa/REPORT.md`.

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
