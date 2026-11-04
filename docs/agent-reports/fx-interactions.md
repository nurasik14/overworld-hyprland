# fx-interactions report (phase 2)

Status: all six deliverables done and exercised. Reference: `docs/INTERACTIONS.md` (behaviour, config, IPC, recipes).

## Delivered

| # | deliverable | paths |
|---|---|---|
| 1 | Block-break window close (IPC `interact kill` / `killAddress` / `killClass`, `SUPER+Q` helper with fallback) | `quickshell/Interact/Miner.qml`, `FxLayer.qml`, `MineOverlay.qml`, `FragmentBurst.qml`, `InteractFx.qml`, `materials.json`, `scripts/interact/kill.sh`, `capture-palette.sh` |
| 2 | Block-place window open (`openwindow` → sound + dust, rate limit, skip rules) | `quickshell/Interact/Placer.qml` |
| 3 | Screenshot wrapper `area|window|screen|swappy` + pickup pop | `scripts/interact/screenshot.sh`, `quickshell/Interact/PickupFx.qml` |
| 4 | Low-battery hurt warning + death screen | `quickshell/Interact/Death.qml` |
| 5 | XP level-up flourish (green "+1" + orbs) | `quickshell/Interact/XpOrbs.qml` (qs-core's `LevelSparkle` glitter untouched) |
| 6 | Docs + test helpers | `docs/INTERACTIONS.md`, `scripts/interact/dev-preview.sh`, `dev-drive.sh`, `dev-battery.sh`, `quickshell/Interact/preview/` |

## Decisions

- **One effects layer, mapped on demand.** `FxLayer` (namespace `overworld-break`, Overlay, `mask: Region {}`, no keyboard) hosts crack overlay, break fragments, place dust, XP orbs and the pickup pop; it unmaps 120 ms after the last effect. Effects live in a `ListModel` (`InteractFx`), heavy payloads (palette) in a side map so the Repeater never rebuilds a running effect. Each effect has a TTL as a safety net.
- **`interact kill [address]` became three functions** because Quickshell IPC has no optional arguments: `kill()` (focused), `killAddress(a)`, `killClass(c)` (focused, only if the class matches; used for `/kill <class>` and my tests). `scripts/interact/kill.sh [addr]` is the `SUPER+Q` entry with the `killactive` fallback; agreed in REQUESTS.md.
- **Timeline.** `break_ms/50` ticks (9 at 450 ms), stage = `round(frame*9/(frames-1))`, `block.hit` every 2 ticks, `window.kill` emitted on the last frame (before the close; qs-features looks back 6 s), break sound + `closewindow address:<addr>` + burst at the end. Only `closewindow address:` is ever dispatched.
- **Colours** come from `grim -g <rect>` piped to ImageMagick (`-sample 12x8`, nothing on disk) *only while the window's workspace is on screen*; otherwise the close is instant (no overlay either). 400 ms timeout → theme palette. This is what keeps "capture only my own test window" true in practice: a test window on the hidden workspace 77 is never captured, and the tests that do sample colours run while `dev-shot` holds workspace 77 on screen.
- **Instant close** (sound kept, `window.kill` emitted, 60 ms later `closewindow`): reduced motion / `animations:false`, `interact.break:false`, adventure, spectator, window not on screen. The 60 ms keep `window.kill` ahead of Hyprland's `closewindow` on the bus.
- **Death rules.** Percent from `SystemStats` (whole %, already handles UPower and `OW_FAKE_STATS`). Hurt ≤ 15, death ≤ 5, discharging only, never creative; flags in `$XDG_RUNTIME_DIR/overworld/battery-cycle.json`, cleared when charging. At ≤ 5 % the hurt *sound* is skipped (the death sound replaces it) but the hearts still flash. Score = uptime minutes (the task says minutes; `chat.json`'s note says hours).
- **XP orbs are procedural pixel orbs**, not the `experience_orb.png` atlas: that atlas is white with a red centre, so it cannot be tinted green without a custom shader.
- **Screenshot chat line.** The task text suggests posting the chat line here; qs-features asked that `screenshot {path}` be the only thing emitted (it prints "Saved screenshot as <file>"). I followed qs-features. Without a running shell the script sends a `notify-send` instead.
- **Test hooks** (inert unless set): `OW_INTERACT_SLOWMO=N` (particles N× slower), `OW_INTERACT_DEBUG=1` (log every sound id and decision; `ow-sound` runs detached so its dry-run output is otherwise lost), `OW_INTERACT_DRYRUN=1` (Title Screen only logs).

## Verified (how)

Everything ran in `qs -p quickshell/Interact/preview` on top of the live Apothecary desktop with a private event bus (`OW_EVENTS_DIR`), `OW_SOUND_DRYRUN=1`, `OW_INTERACT_DRYRUN=1`, config in `/tmp/ow-fxi`. No sound was played, `~/.config/overworld/` still holds only `config.json`, no `overworld-test` window is left, and the preview PIDs I started are stopped.

| check | result |
|---|---|
| preview loads; final run of a full mining cycle | `Configuration Loaded`, zero warnings (one McTicker "binding loop" warning on the first run, fixed by running `_step` through `Qt.callLater`) |
| FULL config `timeout 15 qs -p quickshell` (with `OW_STATE_DIR`, private bus, dry-run) | `Configuration Loaded`; only the expected notification-daemon warning and Quickshell's own desktop-entry warnings; nothing from `Interact/` |
| mine a real window by address, 3000 ms and 1000 ms | cracks over the exact rect mid-sequence (screenshot), window closed, events `window.kill {cls,title}`, status `mined …`, sounds at the default 450 ms: `block.hit.metal` ×5 then `block.break.metal` |
| break particles take the window's colours | test kitty with a green background: the fragments on the screenshot are green (sampled by `capture-palette.sh`) |
| place dust and sound | event-driven (real `openwindow`) and via `placeAddress`; dust screenshot |
| rate limit | 4 windows in a burst → 3 `block.place.metal`; 6 `window.open` events total (events are never skipped) |
| skip rules | small floating window → `skipped: small floating window`; adventure → `skipped: adventure mode` |
| instant paths | adventure and `reduced_motion:true` (via `ConfigService`): window closed, break sound, no overlay |
| aborts | wrong class (`killClass kitty` on the focused test window) → `abort: class is overworld-test, not kitty`; unknown address → `abort: no such window`; test window killed mid-mining → `abort: window closed first`, overlay removed; nothing else closed |
| death logic via `OW_FAKE_STATS` | 12 % → hurt + flash only; 4 % → flash, `player.death`, screen, `death {}` event; restart at 4 % in the same cycle → nothing; charging → nothing and flags cleared; creative → nothing; `death_screen:false` → hurt + flash only; 40 % → nothing |
| death screen look | screenshots night/day; layout positions match the game (title y 120 px at GUI 2, message 170, score 200, buttons 414) |
| XP orbs, pickup pop | screenshots (orbs crop at 2×, map item hop), slow-motion hook for the pickup |
| `kill.sh <addr>` without the installed shell | `qs -c overworld` unavailable → fell back to `closewindow address:`, window closed in 39 ms |
| `screenshot.sh` | dry-run for all four modes (no sound/event in a dry run); real `screen` mode while `dev-shot` held workspace 77 → PNG in `qa/screenshots/fx-interactions-shots/`, event `screenshot {path}` on the private bus, `item.pickup` dry-run |
| scripts | `bash -n` on all, `materials.json` parses (`jq`) |

Screenshots (all viewed): `qa/screenshots/fx-interactions-mine-mid.png` (crack stage ~5 over a full-screen window), `-burst.png` (fragments after the break, green = sampled), `-dust.png` (place dust, bottom edge), `-death-night.png`, `-death-day.png`, `-xp-orbs.png`, `-pickup.png` (the rain in that frame is fx-world's concurrent preview), `fx-interactions-shots/Screenshot_*.png` (output of the real `screen` mode).

## Not verified

- A real `SUPER+Q` on a real window and `kill.sh` through the installed `qs -c overworld` (the IPC part ran through `qs -p … ipc call`; the fallback part ran for real).
- Keyboard and pointer on the death screen (Enter/Esc/buttons); the preview never takes the keyboard (`OW_PREVIEW=1`). Title Screen was never pressed.
- `screenshot.sh` `area`/`swappy` (interactive slurp) and `window` on a real window, and the clipboard (`wl-copy` disabled in the real run by `OW_SHOT_NOCOPY`).
- A real UPower discharge (the logic ran on `OW_FAKE_STATS`; `SystemStats` itself is qs-core's).
- Abort when focus moves to another window mid-mining (needs a second focusable test window; the focused-window check is a 3-tick mismatch counter on `Hyprland.activeToplevel.address`).
- Several monitors (rects are converted per screen from global coordinates, but only `eDP-1` exists).
- The Hyprland layer fade on `overworld-break` (until a `no_anim` layer rule exists the overlay fades in over Hyprland's default `layersIn`; in the preview run on top of Apothecary the cracks were opaque in the mid-sequence shot).

## Open issues / notes

- `GameEvents.emit` race (two emits in one tick lose the first) filed to qs-features; worked around by spacing `death {}` 200 ms after the flash.
- Layer rules, `windowsOut` shortening, binds: filed to hyprland-engineer.
- Large windows get the same 32 px crack tile repeated over the whole rect (as specified); it reads as a pattern rather than one crack. A per-"block" variation could be added by choosing the stage per tile.
- `Theme.config` ignores `OW_CONFIG` (ConfigService honours it); this module reads `ConfigService`.

## Requests filed (docs/REQUESTS.md)

hyprland-engineer (binds, layer rules, close animation), qs-features (GameEvents race, event list, `/kill <class>`), qs-core (HUD geometry assumption, OW_CONFIG note), qa-reviewer (untested real-input items).
