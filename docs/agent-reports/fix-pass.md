# fix-pass (phase 4) — log

Constraint change at 13:25: user at the desk → no dev-shot, no `qs -p` with layers, no mode/gamemode/config changes,
no workspace switches. QML validated with the compositor-free offscreen harness
(`QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/render.qml`, `OW_GUI=<n>`, throw-away `HOME`) — it opens no
layer and touches nothing live. NOTE: at 13:23 `qs list --all` showed no `qs -c overworld` instance running (only
`overview`), so there was no live hot-reload log to read; the shell log of the last run showed no errors.

## 1. GUI scale 3 widget overflow — done
- New `quickshell/Widgets/layout-plan.js` (pure JS) + `WidgetLayout.qml` uses it; `WidgetCard.fits`; `WidgetsState.hasPos`.
- Scale 1/2: identical to the old two stacks. When a stack would reach the HUD chips (bottom 22 GUI px; centre column 62),
  cards are re-dealt over up to 3 columns (brute force, ≤65k assignments, once per size/scale change).
- Reality check: at 1080p / scale 3 all 8 cards (942 GUI px of height + gaps vs ~950 of room) cannot fit even in 3 columns, so
  the last card (Sign) gets `fits=false` and stays hidden until dragged. 7/8 shown; scale 4 shows 4/8. 2560x1440 gui 3: 8/8.
- Verified: `node tests/widgets-layout.test.js` (no overlap, no card below the HUD limit, scale 1/2 unchanged);
  offscreen renders `/tmp/fixpass/layout-gui{2,3}.png` viewed.
- Caveat: `~/.config/overworld/widget-positions.json` has a saved `quote` position `[1513,832]` (drawn at scale 2); a saved
  position always wins, so at scale 3 the Sign sits there (overlapping System). Double-click its title bar to reset.

## 2. btop in a half-height split — done
- `scripts/ow-btop` (also `overworld btop`): btop needs 24 rows, Monocraft's 27 px lines give a 540 px tile 20. Under
  `OW_BTOP_MIN_ROWS` (30) rows inside kitty it reopens btop in its own kitty (class `btop`) at 6.75 pt = Monocraft's crisp
  9 px size (40 rows per half screen); elsewhere it just execs btop. Documented in docs/APPS.md (btop row) + `overworld help`.
- Verified: `bash -n`. Not run live (it would open a window on the user's desktop). A new window rather than an in-place
  resize because kitty remote control is off and I did not want to enable it.

## 3. Select World rows after a mode flip — done
- Cause: `lister` (find) was still running when the mode flipped again, so `running = true` was ignored and its stale
  answer (old folder) filled `files`. Now `onDirChanged` clears `files`, sets `listAgain` when a find is in flight and
  `Process.onExited` re-runs it; stale results are dropped (`WallpaperPicker.qml`).
- Verified: syntax only (qmllint) + the live shell hot-reloaded it with no new warning. The flip race itself not reproduced
  (needs mode flips, forbidden now).

## 4. `ipc wallpapers next|prev` — done
- Picker closed → runs `overworld wallpaper next|prev` (no picker); picker open → moves the selection as before; `open`
  is still separate. `shell.qml`, docs/QUICKSHELL.md.

## 5. Multiplayer list showing one row — done (cause confirmed read-only)
- `nmcli -t dev wifi list --rescan no` read just now: **1 row (the connected AP)**, a few minutes later 7 — it is NM's scan
  cache: while connected wpa_supplicant barely scans, so entries age out. Nothing was wrong in the parser.
- Fix: `NetworkService.scanOnOpen()` (called by the panel on open): one `nmcli dev wifi rescan` (no connect/disconnect;
  "scanning not allowed yet" is silenced), re-reads the list at 2.5/5/7.5 s, and `parseWifi` keeps the previous rows
  while a stale one-row answer arrives in that window. Verified: harness parsed 7 networks after the change, no QML warning;
  I did not run any rescan myself.

## 6. `overworld gamemode` — done
- No argument → `status`. `toggle` explicit (the SUPER+SHIFT+G bind already says `toggle`). Verified by running it
  (prints `survival`, state unchanged). Help text updated.

## 7. F6 screenshot binds — done
- hypr/keybinds.conf: unbinds SUPER/SUPER+SHIFT/SUPER+CTRL/SUPER+ALT/ALT + F6 (JaKooLit's Laptops.conf) and rebinds to the
  wrapper (screen, area, screen after 5 s / 10 s, window). `Hyprland --verify-config` ok; one `hyprctl reload` at the
  end; `hyprctl configerrors` empty; `hyprctl binds -j` shows all five F6 binds → screenshot.sh. docs/KEYBINDS.md.

## 8. Brew-done icon — done
- `BrewTimer.notify` passes `Theme.iconUrl("brewing_stand")` as a file path (Mojang icon → gen fallback → missing texture),
  not a theme name. Verified: the icon file exists; not fired (would play/notify).

## 9. TimeService hot-reload warning — done
- `now` is guarded against `clock.date` being undefined during the rebuild. Live check: log had two
  `TimeService.qml[14:5] Unable to assign [undefined] to QDateTime` from earlier reloads; after the fix I touched the file
  (hot reload) and no new warning appeared.

## 10. Asset fallbacks — done (partly by design)
- All sprite lookups go through `Theme.tex` / `Theme.iconUrl`, which end in `Common/assets/missing.png`, so no QML
  warning. Checked offscreen with `OW_NO_MOJANG=1`: widget layout, plus a harness that instantiates every static
  `sprite:` / `Theme.tex()` / item icon name referenced in the QML — zero warnings (also with Mojang assets).
- Added originals (`tools/assetforge/gen_extras.sh`, ImageMagick, no Mojang pixels): icons potion, blaze_powder,
  brewing_stand, ender_chest, golden_apple, nether_star; textures block/{dirt,oak_planks,birch_planks,item_frame},
  painting/kebab, entity/signs/oak, particle/glitter_0..7, brewing stand GUI + 3 sprites. Contact sheet viewed
  (/tmp/fixpass/extras.png).
- Still the missing texture without assets/mc: `gui/advancements/window`, `advancements/*`, `container/creative_inventory/tab_*`,
  `icon/language`, `icon/ping_*` (and any dynamic names not found by static grep).

## 11. fetch-minecraft-sounds.sh — done: nothing called it (checked); deleted; .gitignore comment updated.

## 12. F3 strip — already present
- `F3Layer.qml` F3Row draws a per-line `#c8383838` strip (qa-reviewer's fix; the game's is `#90505050`). Kept the darker
  colour for readability over the cards, comment now says so.

## State at the end
- `overworld status`: enabled yes, dark, survival; `qs -c overworld` running (started 13:26 by someone else), log has no
  errors from my files; Overworld still ON. config.json, sounds (false), mode, media, rofi config untouched.
- Removed a stray `Services` symlink my harness created in the repo root.
