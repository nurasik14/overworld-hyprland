# Interactions — mining windows, placing windows, screenshots, the death screen

Owner: fx-interactions. Code: `quickshell/Interact/` (entry `Interactions.qml`, instantiated by `shell.qml`), helpers in `scripts/interact/`.
Everything here is a Minecraft behaviour mapped onto a real desktop event (BRIEF §2): closing a window is **mining a block**, opening
one is **placing a block**, a screenshot is **picking up a map**, 5 % battery is **dying**, a new uptime hour is an **XP level**.

## What happens

| desktop event | what you see and hear | events on the bus |
|---|---|---|
| **close a window** (`SUPER+Q` → `scripts/interact/kill.sh`, `/kill`, IPC `interact kill`) | `block/destroy_stage_0…9` crack textures tiled at 16 px × GUI scale over the exact window rect, one frame per 20 TPS tick (~450 ms), `block.hit.<material>` every 2 ticks; then `block.break.<material>`, the window closes and 30–60 square fragments in the window's own colours burst out and fall (~0.6 s) | `window.kill {cls,title}` (one tick before the close) |
| **open a window** (Hyprland `openwindow`) | `block.place.<material>` and a small puff of grey dust along the window's lower edge and sides (~0.5 s) | `window.open {cls,title}` (always, even when the effect is skipped) |
| **screenshot** (`Print` → `scripts/interact/screenshot.sh`) | `item.pickup` pop sound; a map item hops up in the middle of the screen and flies into the hotbar; chat line "Saved screenshot as <file>" | `screenshot {path}` (qs-features turns it into the chat line, so this module does not post one) |
| **battery ≤ 15 %, discharging** (once per discharge cycle) | `player.hurt`; the HUD hearts blink for 1 s | `battery {percent,charging:false,flash:true}` |
| **battery ≤ 5 %, discharging** (once per cycle) | full-screen red death screen: "You died!", a death message from `quotes/chat.json`, "Score: <uptime minutes>", **Respawn** (dismiss) and **Title Screen** (`loginctl lock-session`); `player.death` | `death {}` |
| **new uptime hour** (`xp.levelup`) | "+1" and green/yellow XP orbs rising from the XP bar (qs-core's `LevelSparkle` glitter around the level number stays) | – |

Materials (which sound set a window gets): `quickshell/Interact/materials.json`, first matching `class`/`title` regex wins, default `stone`.
Browsers and media players → glass, terminals → metal, file managers / editors / document viewers → wood, chat and mail apps → wool,
image/3D tools and Minecraft → grass. Edit the file and restart the shell.

## Config (`~/.config/overworld/config.json`)

| key | default | effect |
|---|---|---|
| `interact.break_ms` | 450 | length of the cracking sequence (9 ticks at 450); minimum 100 |
| `interact.hit_every` | 2 | ticks between `block.hit` sounds |
| `interact.break` | true | false = every close is instant (sound only) |
| `interact.place` | true | false = no place sound / dust |
| `death_screen` | true | false = no death screen (the 15 % hurt warning stays) |
| `reduced_motion` / `animations:false` | false | close is instant (no overlay, no particles, the break sound still plays), no dust, no orbs, no pickup pop |
| `particles` | "all" | "all" 100 %, "decreased" 50 %, "minimal" 20 % of the particle counts |

Game modes: **creative** — no hurt warning, no death screen. **adventure** and **spectator** (performance / focus modes) — closes are
instant (break sound, no overlay, no particles), no place effect; the HUD-bound flourishes are hidden in spectator.

## IPC — target `interact`  (`qs -c overworld ipc call interact <fn> [arg]`)

| function | does |
|---|---|
| `kill()` | mine the **focused** window. Aborts if focus moves to another window while mining (3 consecutive ticks of a different active address) |
| `killAddress(address: string)` | mine the window with that Hyprland address (`0x55…`), focused or not |
| `killClass(cls: string)` | mine the focused window **only if** its class equals `cls` (case-insensitive) — safe for `/kill <class>` and for tests |
| `place()` / `placeAddress(address)` | run the place effect (sound + dust) for the focused window / a window, without any of the skip rules |
| `death()` / `respawn()` | show / dismiss the death screen by hand (ignores battery, flags, creative) |
| `hurt()` | the 15 % warning: `player.hurt` + hearts flash |
| `levelup(level: int)` / `pickup()` | the XP flourish / the screenshot pickup pop |
| `status(): string` | e.g. `idle fx=0 death=false kill:[mined kitty 0x…] place:[placed kitty (metal)]` |

**The interface agreed with hyprland-engineer:** `SUPER+Q` runs `scripts/interact/kill.sh` (or `overworld kill`, which should exec it). The script
calls `qs -c overworld ipc call interact kill` (1.5 s timeout) and, if the shell is not running, falls back to `hyprctl dispatch killactive`.
With an address (`kill.sh 0x55…`) it uses `killAddress` / `closewindow address:…`. Only `closewindow address:<that window>` is ever dispatched
by the shell — never `killactive`, a class, or "the active window" at close time.

## Safety rules the code follows

* One mining at a time (a second `kill` while one runs is ignored). A watchdog drops a stuck sequence after `break_ms + 3.5 s`.
* Aborts without closing anything when: no such window / class mismatch (`killClass`) / the focused window changed (focus-mode kill) / the window
  closed by itself (`closewindow` event) while its cracks were showing.
* The screen is only sampled (`grim -g <window rect>`, in memory, 12×8 point samples, nothing written) when the window is on the workspace that is
  on screen; otherwise the close is instant. The 96 sampled colours are the particles' palette; if grim/magick are missing or the capture takes
  longer than 400 ms a theme palette is used.
* Place effect is skipped (the `window.open` event still goes out) for: > 3 windows within 1 s, adventure/spectator, class empty (X11 popups),
  pinned or hidden, floating and smaller than 420×260, a window on a workspace that is not on screen, special workspaces.
* The effects layer (namespace `overworld-break`, Overlay, empty input region, no keyboard) exists only while an effect plays and is unmapped
  120 ms after the last one. Each effect has a time-to-live as a safety net.

## Death screen details

* Thresholds use `SystemStats.percent` (whole percent): hurt at ≤ 15, death at ≤ 5, both only while discharging and never in creative.
* "Once per discharge cycle" is remembered in `$XDG_RUNTIME_DIR/overworld/battery-cycle.json` (`{"hurt":bool,"died":bool}`) and cleared when the
  charger connects, so restarting the shell at 4 % does not show the screen twice, but unplugging and draining again does.
* Layout = the game's `DeathScreen`: gradient `#60500000 → #A0803030` over the whole output, title at 2× scale at y = 60 GUI px, cause at 85,
  score at 100 (`Score:` white, value yellow), buttons 200 GUI px wide at `height/4 + 72`. Enter, Esc or **Respawn** dismiss; **Title Screen**
  locks the session and dismisses. Namespace `overworld-death` (Overlay, keyboard-exclusive while open, on the focused output).
* Score = uptime in minutes (`quotes/chat.json` says hours; the task for this module says minutes, minutes win).

## Screenshot wrapper

`scripts/interact/screenshot.sh [area|window|screen|swappy]` — JaKooLit's `ScreenShot.sh` behaviour: files go to
`$(xdg-user-dir PICTURES)/Screenshots/Screenshot_<dd-Mon_HH-MM-SS>_<rand>.png` (here `~/Media/Screenshots`), the PNG is also copied with `wl-copy`.
`area` = slurp, `window` = the active window's rect, `screen` = everything, `swappy` = slurp, clipboard only, edit in swappy.
Then: `ow-sound item.pickup`, event `screenshot {path}`; if the shell is not running a `notify-send` says where the file went. Escape in slurp
cancels silently. Test overrides: `OW_SHOT_DIR`, `OW_SHOT_NOCOPY=1`, `OW_SHOT_DRYRUN=1` (prints the grim lines, no sound/event), `OW_EVENTS_DIR`.
Suggested binds: `Print` area · `ALT+Print` window · `SHIFT+Print` screen · `SUPER+SHIFT+S` swappy.

## Files

```
quickshell/Interact/
  Interactions.qml   entry: effect layers, Miner/Placer/Death, XP + pickup listeners, IPC `interact`
  Miner.qml          the block-break close state machine (query → capture → mine → break)
  Placer.qml         openwindow → window.open + block-place sound and dust
  Death.qml          battery rules + the death screen window
  FxLayer.qml        one click-through overlay per output (overworld-break) hosting the effects
  InteractFx.qml     singleton: effect registry, materials.json lookup, particle factor, sound/log wrapper, OW_INTERACT_SLOWMO
  MineOverlay.qml · FragmentBurst.qml (break fragments + place dust) · XpOrbs.qml · PickupFx.qml
  materials.json     class → material
  preview/shell.qml  harness (symlinks Common, Services, Interact)
scripts/interact/
  kill.sh            SUPER+Q (IPC with fallback)      screenshot.sh   Print keys      capture-palette.sh   the window's colours
  dev-preview.sh · dev-drive.sh · dev-battery.sh        test helpers (below)
```

## Testing recipes (nothing here touches the live session)

```sh
scripts/interact/dev-preview.sh start                    # private event bus + dry-run sound/lock, log in /tmp/ow-fxi/preview.log
# slow motion mid-crack shot: interact.break_ms 3000 in /tmp/ow-fxi/config.json, then
KARGS="-o background=#2a8f3a" scripts/interact/dev-drive.sh 1.6 qa/screenshots/x.png full kill
# burst: break_ms 600 and OW_INTERACT_SLOWMO=3 at start, settle ≈ 1.25      dust: … 0.05 … place
scripts/interact/dev-preview.sh ipc death                # death screen;  `ipc respawn`, `ipc levelup 31`, `ipc pickup`
scripts/interact/dev-battery.sh "4%" '{"battery":4,"charging":false,"uptime":3.5}'   # one throw-away run, prints the decisions
OW_INTERACT_DEBUG=1 …                                    # logs every sound id as "interact sound <id>"
```
`dev-drive.sh` opens exactly one `overworld-test` kitty on workspace 77 and mines it by address, so no user window is ever a target.
