# qs-features (phase 2) — chat console, game modes, advancements, statistics, options

You own: `quickshell/Game/` (entry `GameSystems.qml`, already instantiated by shell.qml),
`quickshell/Services/GameEvents.qml` (its API is frozen — BRIEF §4.4; you may improve internals),
`scripts/ow-game.py` or similar helpers under `scripts/game/`, `docs/GAMEPLAY.md`.

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

Build the "another level" game systems from BRIEF §2 items 1, 2, 3 and 6. All screens are real Minecraft
screens (McScreen with the dimmed menu background, Minecraft buttons, sounds), fast and keyboard-driven.

1. **Chat console** (layer `overworld-chat`, bottom-left above the HUD like the game): open via IPC
   `chat open` (empty) / `chat command` (prefilled "/"), Enter sends, Esc closes, Up/Down history (persisted
   `~/.config/overworld/chat-history.json`), Tab completion of commands, sub-commands, workspace ids, app
   names (desktop entries), window classes. Commands (each documented in `/help` from `quotes/chat.json`):
   `/time set day|night|<auto>` (→ `overworld light|dark`, or fx-world daycycle IPC), `/weather
   clear|rain|thunder|auto` (→ fx-world IPC `world weather`), `/gamemode <m>`, `/tp <ws>`, `/give <app>`
   (launch desktop entry), `/kill [class]` (→ `overworld kill` / Interact IPC), `/locate <app>` (focus its
   window, say where it is: "The nearest kitty is at workspace 3"), `/seed` (random wallpaper), `/brew <dur>`
   (→ `overworld brew start`), `/title <ws> <text>` (→ `overworld ws <n> <text>`), `/clear` (notifications),
   `/advancement list|grant|revoke` (grant/revoke = testing aid), `/stats`, `/f3`, `/reload`, `/say`, `/me`,
   `/msg <text> in <dur>` (schedules a reminder notification = a real feature), `/help [cmd]`. Chat log overlay:
   last ~10 lines visible with 10 s fade like the game; system events appear as lines ("[Overworld] Saved
   screenshot as …", "Nurasik has made the advancement [Getting an Upgrade]" with the green bracket hover,
   joined/left lines). Other modules post lines via `GameEvents.emit("chat.say", {text, color})` — document it.
2. **Game modes**: state file `~/.config/overworld/gamemode` (survival default) + IPC `gamemode set <m>` /
   `gamemode switcher` → the F3+F4-style **gamemode switcher** overlay (4 icons, Tab/arrow cycling while
   SUPER held is hard in QML — use arrows/Tab + Enter, Esc). Apply: survival = normal; creative = normal +
   hunger/heart warnings suppressed (HUD reads the file); adventure = the old Apothecary performance
   gamemode → call `overworld gamemode on`/`off` (hyprland-engineer owns that CLI; request the exact verbs);
   spectator = hide HUD + widgets, gaps 0 (`hyprctl keyword` via the CLI), DND on; leaving restores. Emit
   `gamemode`.
3. **Advancements**: engine (QML singleton or a small Python daemon — prefer QML; if Python, start it from
   GameSystems and kill it on exit) that loads `quotes/advancements.json`, listens to GameEvents + Hyprland
   events (`Quickshell.Hyprland` raw events for window open/close/workspace) + periodic checks (uptime, time of
   day, battery) and persists progress to `~/.config/overworld/advancements.json` (atomic in-place writes).
   Unlock → toast via the notification toast style (emit `advancement`, play `ui.toast.challenge` for
   challenges else `ui.toast.in`, chat line). **Advancements screen** (`advancements open`): tabs per tab,
   the tree with frame sprites (`advancements/{task,goal,challenge}_frame_{obtained,unobtained}`), connecting
   lines, tooltip on hover with title/description/progress, background tile per tab (stone, dirt, sand,
   netherrack, end stone textures), drag to pan.
4. **Statistics screen** (`stats open`): General / Items / Mobs-style tabs: time played (session + total),
   windows opened/closed(mined), workspaces switched, notifications, brews, screenshots, distance "walked" =
   workspace hops… counts persisted in `~/.config/overworld/stats.json`. No keylogging.
5. **Options screen** (`options open`): Minecraft Options layout (Video Settings…, Music & Sounds…, Controls
   → shows the keybind table read-only from docs/KEYBINDS.md or `hyprctl binds -j`, Accessibility → reduced
   motion), writes `config.json` keys in place (jq-style in-place writes, never mv), GUI scale applies live,
   Difficulty Peaceful = DND, Done button. Coordinate config key names with qs-core (ConfigService owner) in
   REQUESTS.md.
6. IPC (BRIEF §4.6) for chat, advancements, stats, options, gamemode. `docs/GAMEPLAY.md`: every command,
   advancement trigger table, files.

Testing: drive everything by IPC + `overworld event …` (fake events to unlock a test advancement on a COPY of
the state: point the engine at a temp state path via an env var or config key while testing, then delete it
— the real advancements.json must start clean for the user). Screenshots of chat, switcher, advancements,
stats, options in Day + Night. Report in `docs/agent-reports/qs-features.md`.
