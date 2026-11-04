# fx-interactions (phase 2) — mining windows, placing windows, screenshots, death screen

You own: `quickshell/Interact/` (entry `Interactions.qml`, already instantiated), `scripts/interact/`
helpers, `docs/INTERACTIONS.md`.

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

1. **Block-break window close** — IPC `interact kill [address]` (hyprland-engineer binds SUPER+Q to
   `overworld kill`, which calls this IPC and falls back to `hyprctl dispatch killactive` if the shell is not
   running; agree the exact interface in REQUESTS.md and document it). Sequence (~450 ms total, configurable,
   `reduced_motion` → instant close): read the target window geometry (`hyprctl activewindow -j` / by
   address), grab a small capture of it (`grim -g` IS allowed for this runtime feature inside your QML/script,
   but in TESTING only capture your own test window — see below), show an overlay layer
   (`overworld-break`, overlay, no input) exactly over the window with the `block/destroy_stage_0..9` crack
   textures tiled at 16 px × GUI scale, stepping on 20 TPS ticks; play `block.hit.<material>` per stage and
   `block.break.<material>` at the end (material by class: glass for browsers, wood for file managers/editors,
   stone default, wool for chat apps, metal for terminals — mapping in a JSON); then close the window
   (`hyprctl dispatch closewindow address:<addr>`), and burst **break particles**: 30–60 small square
   fragments whose colours are sampled from the window capture, flying out with gravity for ~0.6 s. Emit
   `window.kill {cls}`. Never close anything but the targeted window; abort if the active window changed.
2. **Block-place window open** — listen to Hyprland `openwindow` events: after the window maps, small dust
   particle puff (block-place particles) at its rect + `block.place.<material>` (rate-limited: skip when > 3
   windows open within 1 s, skip floating popups/menus/notifications, skip in adventure/spectator). Emit
   `window.open`.
3. **Screenshot wrapper** `scripts/interact/screenshot.sh [area|window|screen]` (Print key binds go through
   it): uses grim/slurp/swappy like JaKooLit's ScreenShot.sh behaviour (read it in
   `~/.config/hypr/scripts/ScreenShot.sh`, keep its save location), then plays `item.pickup`, posts the chat
   line "Saved screenshot as <file>" (`GameEvents.emit("chat.say", …)` or via the CLI event) and emits
   `screenshot`. In testing run only the `screen` mode with output into qa/screenshots via an env override,
   never interactive slurp.
4. **Low battery death screen** — at ≤ 5 % discharging (once per discharge cycle; never when charging; never
   in creative; config `death_screen` true/false): full-screen red-tinted Minecraft death screen ("You
   Died!", death message from `quotes/chat.json`, "Score: <uptime minutes>", buttons Respawn = dismiss,
   Title Screen = lock (`loginctl lock-session` — DO NOT press it in testing)), `player.death` sound; at ≤ 15 %
   a one-time `player.hurt` + hearts flash request to the HUD via `GameEvents.emit("battery", …)`. IPC
   `interact death` / `interact respawn` for testing.
5. **XP level-up flourish** (if qs-core's HUD doesn't do the visual, coordinate): green "+1" orb particles
   rising from the XP bar on `xp.levelup`.
6. `docs/INTERACTIONS.md`.

Testing rule: create your OWN test window (`kitty --class overworld-test -e sleep 600 &` — it will appear on
the user's current workspace; that's acceptable but kill it by PID immediately after; better: `hyprctl
dispatch exec "[workspace 77 silent] kitty --class overworld-test -e sleep 600"` so it opens on the empty
dev workspace) and mine ONLY that window by address. Capture the crack sequence mid-way with dev-shot.sh
(DEVSHOT_SETTLE=0.15). Never target the user's windows. Report in `docs/agent-reports/fx-interactions.md`.
