# now-playing-pip-apothecary report: the floating Now Playing mini-player, Apothecary port (影)

2026-11-10. The user was at the desk: no dev-shot/grim, no workspace switch, no on-screen windows, no theme switch, no sound,
no commits, no sudo, no player control. Apothecary's shell was never started (Overworld is live). Visual checks are offscreen renders, all viewed.
**Nothing in the user's live state was written**: `~/.config/apothecary/nowplaying.json` does not exist, so the PiP will start OFF.

## Changed files
**`~/Projects/apothecary-hyprland` (uncommitted)**
| what | where |
|---|---|
| Shared daemon/CLI, **byte-identical** with Overworld's (`cmp`) | `scripts/hypr-nowplaying` (new) |
| Zen userscript template, **byte-identical** (the CLI finds it relative to itself) | `apps/zen/nowplaying-bridge.user.js` (new) |
| Service: Overworld's with theme bindings changed (state path, `APO_*` env names, own `preview` flag instead of `ShellState.preview`) | `quickshell/NowPlaying/NowPlayingService.qml` (new) |
| The layer: namespace `apothecary-nowplaying`, default bottom-right 16 px from the edges (no bottom HUD), QML fade honours `reduced_motion` | `quickshell/NowPlaying/NowPlayingPip.qml` (new) |
| The look, restyled: a hanging scroll (cord + ring, rosewood rods with gold caps, paper/lacquer, silk mount with a gold hairline, ink progress with seal knob, 影/音 seal by the title, 停/静 paused/stopped seals, paper chip buttons with a vermilion play/pause, brush-stroke resize grip). Same API as Overworld's view | `quickshell/NowPlaying/NowPlayingView.qml` (new) |
| Unchanged copies: `VideoMirror.qml`, `sync.js` (byte-identical), `NowPlayingIpc.qml` (comment only) | `quickshell/NowPlaying/` |
| Wiring | `quickshell/shell.qml` (`NowPlayingPip {}`), `quickshell/Bar/WidgetsMenu.qml` (row 影 "Now Playing  (Super+Alt+P)"), `quickshell/Services/ConfigService.qml` (`APO_CONFIG` test override + documented `nowplaying.*` keys) |
| CLI `apothecary nowplaying on\|off\|toggle\|status\|reveal\|reset\|userscript\|cache\|bridge`, `apothecary nowplaying help`, `apothecary help nowplaying` | `scripts/apothecary` |
| `SUPER+ALT+P` (Overworld's key) | `hypr/keybinds.conf` |
| Layer rule: blur off, ignore_alpha 0, no_anim on | `hypr/decorations.conf` |
| Link + `init` (token); uninstall hands the link to Overworld's copy, keeps token/cache | `scripts/install.sh`, `scripts/uninstall.sh` |
| Tests / previews | `tests/nowplaying-service.test.sh`, `quickshell/NowPlaying/preview/{render.sh,render.qml,act.qml,service-test.qml,mirror-test.qml}` + links |
| Docs | `docs/WIDGETS.md` (section *Now Playing — 影*), `README.md` (bullet + Daily use line), `docs/KEYBINDS.md`, `docs/QUICKSHELL.md`, `CHANGELOG.md` |

**`~/Projects/overworld-hyprland`:** only this report and one entry in `docs/REQUESTS.md`. I found no bug in `hypr-nowplaying` or the userscript, so neither changed.

## Decisions
- **Hanging scroll** rather than a PaperPanel card: it is a picture, and a scroll is how a picture hangs in Maomao's world; the paper is the
  cards' `surface` + grain, so it still belongs with the desk cards (lacquer at night, cream ink, like every Apothecary card in dark mode).
- **Seals**: 影 (image/film) by the title for video, 音 (sound) for music; 停 (stop) on pause, 静 (still) when stopped. `tokens/check-glyphs.sh`:
  all four OK in Ma Shan Zheng, ZCOOL XiaoWei, LXGW WenKai. Every seal has a Latin `label`; all overlay words are Latin (PAUSED, LIVE, Fetching video…).
- **Paper alpha** = `widgets.opacity` with a floor of **0.88** (the panels' `surface` opacity). At 0.82 the dark render showed the wallpaper's face
  through the strip text; the scroll floats over windows, not the wallpaper.
- **Title font LXGW WenKai Medium 14** (Latin, Cyrillic, Kazakh, CJK in one face; video titles mix scripts). Time in the mono face.
- **Source glyph colours from the palette** (YouTube `error` vermilion, Spotify `success`, TikTok `plum`) instead of brand colours: DESIGN.md
  keeps pure saturated colour for the seal.
- **Buttons are paper chips** (not InkButton: its transparent fill is unreadable over video); play/pause is seal-filled, the confirm gesture.
- **Layer rule**: blur off (blurring a video layer would re-run every frame; the paper is ≥ 88 % opaque) and `no_anim on` (the fade is in
  QML; Apothecary's usual `animation fade/slide` on a full-screen masked surface would replay on every show). Rule keys verified.
- **Config keys**: Apothecary's ConfigService has no defaults object, so the keys are documented in its header and in WIDGETS.md and the
  service passes the fallbacks. **I did not add a `nowplaying` block to the user's `~/.config/apothecary/config.json`** (live user state).
- **Menu label** "Now Playing  (Super+Alt+P)": the longer "Now Playing PiP  (…)" measures 173 px at Noto Sans 12 and the menu row has 168.
- **`apothecary help nowplaying`**: `help` now takes an optional topic (only `nowplaying|pip`; anything else prints the main help as before).
- Default corner bottom-right 16 px from the edges: it overlaps the Quote and Cava cards there (bottom layer, expected; drag it).
- **Double-click reset = two taps within 400 ms** in `onTapped`, not `onDoubleTapped`: with synthetic events `tapCount` never reached 2, so the stock
  path could not be tested. The timed version behaves the same with a real mouse and is tested.
- **The resize grip may take the pointer from the scroll's own DragHandler** (`grabPermissions: CanTakeOverFromAnything`). Before this, a drag on the grip
  moved the scroll, as it still does in Overworld (request filed). The grip and `clampBox` now scale by the picture (`vidW`/`vidH`), not the whole scroll.

## Verified (and how)
- **Service + IPC** `bash tests/nowplaying-service.test.sh` (Apothecary's port; private offscreen qs, the real daemon as its child on a random port,
  temp state/runtime/cache/token/config via `APO_CONFIG`) → **29 passed, 0 failed**: starts OFF, no daemon while off, on persists and starts the daemon
  as the shell's child, TikTok report → portrait, upload → video ready, paused follows, status line, reset/reveal, auto-hide, off stops the daemon, toggle,
  nothing left after exit. No warnings from NowPlaying files in the log.
- **Mirror** `preview/mirror-test.qml` with the real cached clip → **10 PASS, 0 FAIL** (no audio output, sync, seek, exact paused frame, 1.5×).
- **Shared CLI** Overworld's `tests/hypr-nowplaying.test.sh ~/Projects/apothecary-hyprland/scripts/hypr-nowplaying` → **95 passed, 0 failed**.
  Userscript `tests/nowplaying-bridge.test.sh` → **33 passed**; `tests/nowplaying-sync.test.js` → **25 passed**; `cmp` confirms the copies identical.
  Apothecary's copy writes the userscript from its own `apps/zen/` template (temp cache/data dirs).
- **CLI** with temp `XDG_CONFIG_HOME`/`XDG_CACHE_HOME`: status (shell down), on/off flip the state file and keep saved positions, reveal → "shell not
  running" exit 1, unknown verb exit 1, `help nowplaying`, main help line, `bridge`, `cache list`. `bash -n` on apothecary, install.sh, uninstall.sh.
- **Hyprland config**: `Hyprland --verify-config` on colors + decorations.conf + keybinds.conf → config ok (a negative control with a bogus rule key fails,
  so rule keys are checked). JaKooLit has `SUPER ALT, P` only commented out. Apothecary is off, so neither file is sourced live; nothing reloaded.
- **Renders** (offscreen, temp HOME with only the mode file + font link, real wallpaper behind, all viewed), light and dark:
  `~/Projects/apothecary-hyprland/qa/screenshots/nowplaying-{landscape,portrait,spotify,hover,paused,fetching,thumb,live,nothing,narrow}-{light,dark}.png`
  (gitignored: they contain the wallpaper). As in Overworld, the "video" is a still frame of the real cached clip (VideoOutput cannot be grabbed offscreen);
  `thumb` = the 4:3 hqdefault thumbnail cropped, `spotify`/`nothing` use Maomao's portrait as the cover. Zoomed crops checked: rods/caps, cord, seal, chips.
- **Real pointer events** `render.sh <dir> act` (`preview/act.qml`, QtTest events into an offscreen window, both modes) → **15 PASS, 0 FAIL** each:
  hover shows the controls, the tooltip appears after the delay (image `nowplaying-act-tooltip-{light,dark}.png`, viewed), ✕ = close, ⏯ ⏭ ⏮ 󰏌 reach
  the player (mock), a chip click is not a drag, dragging moves it, a double-click on the strip resets and a single click does not, **the grip's corner
  follows the pointer exactly (+100 px → +100 px, boxW 360→460) with the top-left corner held**, and the clamp stops at the window edge (0 px gap).
- **Full shell offscreen** resolves every type up to the expected "No PanelWindow backend loaded" (the same limit as every layer surface).

## Not verified
- The real `apothecary-nowplaying` layer (needs Apothecary on): input mask, drag/resize with a real pointer, Overlay over fullscreen, hover, the fade,
  the source-fullscreen hide, focus button, MPRIS buttons (never pressed: they would control the user's player), the widgets-menu row as drawn.
- `apothecary nowplaying on|status` through a running Apothecary shell (the IPC verbs themselves were exercised in the private instance).
- install.sh / uninstall.sh were not run (they reload Hyprland); `bash -n` only. `~/.local/bin/hypr-nowplaying` still points at Overworld's copy (identical).

## Please try (user), after `apothecary on`
1. **SUPER+ALT+P** (or the bar's Desk widgets menu → 影 *Now Playing*). Play a YouTube video in Zen: thumbnail, *Fetching video…*, then the silent video.
   Seek / pause / change speed in the browser: it follows.
2. Hover: ⏮ ⏯ ⏭, 󰏌 jumps to Zen, ✕ turns it off. Drag it; resize from the bottom-right brush strokes; double-click the title strip to reset.
3. TikTok (needs the userscript; if it is already installed for Overworld, nothing to do): a portrait scroll.
4. Fullscreen the video: the scroll hides. Pause: 停 seal + dim. Stop: 静, then it fades after 20 s.
5. `apothecary light`/`dark` while it shows: the paper, rods and ink cross-fade.
6. `apothecary nowplaying status`, `apothecary help nowplaying`.

## Independent review
A fresh read-only reviewer got the code and the Overworld reference. It found **nothing serious**: no leftover Overworld APIs, it checked every
Theme/Seal/MusicService/WidgetsState property, the geometry adds up, and the CLI, install, layer rule and keybind are sound. Its low-severity findings:
1. *The grip lags behind the cursor* (it scaled by the whole scroll): **fixed** (scale by the picture). My pointer test then showed the grip did
   not resize at all, because the outer DragHandler kept the grab: **fixed** (see Decisions), and **the same bug exists in Overworld** (confirmed with a
   throw-away offscreen harness on its view; request filed).
2. *The mask includes the 16 px cord band and the rod ends*, so clicks just above the scroll are taken: **not changed**. Masking a child item
   cannot be checked without a compositor, and a wrong mask would make the scroll unclickable. Low impact; noted as a known limit.
3. *No visible tooltips on the chips*: **fixed** (small paper tooltip after 450 ms; rendered and tested).
4. *Shadow squashed, not offset*: **fixed**.
5. *reduced_motion only on the layer fade*: **fixed** (all the view's animations).
6. *Ad badge 4.4:1*: **fixed** (`#7A510C`). Not changed: `np_write_on` without a state dir (impossible: the CLI creates `$STATE` on start), and an IPC
   timeout with the shell running writes the file (the same in Overworld; harmless, the shell reads it on the next start).

After the fixes: the renders were redone (all 20 viewed in montages), the service test reran → **29 passed**, and act → **0 failed** in both modes.

## Known limits
- The input mask is the whole view, so the transparent band around the cord (16 px above the top rod) and the 5 px rod ends take clicks.
- The default corner covers part of the Quote and Cava cards.

## Requests filed
One entry in Overworld's `docs/REQUESTS.md` (to the orchestrator / whoever touches quickshell/NowPlaying): the PiP's resize grip moves the PiP
instead of resizing it (confirmed), with the one-line fix. It also suggests scaling the grip by the picture and covers the unconfirmed double-tap.
