# qs-core (phase 2) — HUD bar, launcher, toasts, network, game menu, world select, OSD, /title, brewing stand

You own: `quickshell/shell.qml`, `quickshell/Services/*` (existing files; GameEvents.qml belongs to qs-features),
`quickshell/{Bar,Launcher,Notifications,Network,Power,Wallpapers,Osd,Brew}/`, `docs/QUICKSHELL.md`.

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

Rebuild every core surface as the Minecraft element in BRIEF §2's table, keeping all functions:

1. **HUD (replaces the top bar; namespace `overworld-bar`; may become two layers, e.g. `overworld-hud`
   bottom-centre + `overworld-bar` slim top strip — keep the namespace names documented for hyprland-engineer's
   layer rules).** Bottom centre: the **hotbar** with workspaces 1–9 (+ws 10 in the offhand slot), selection
   sprite jumps instantly, each slot shows the dominant app's item icon (`tokens/items.json`, class →
   item; hermes in kitty title → its own entry) with stack count = window count, empty workspace = empty slot,
   occupied special workspace indicator, scroll to cycle, click to switch, hover = Minecraft tooltip with the
   workspace title + notes (`WorkspaceNotes`, keep the Apothecary tooltip info), item-name popup above the
   hotbar on switch (fades after 2 s). Above the hotbar: **hearts = battery** (UPower via Quickshell.Services.UPower
   or /sys; charging regen pulse; jiggle < 20 %; hardcore style ≤ 5 %), **hunger = free RAM**, **armor or
   air = CPU** (design-director's/your call, document), **XP bar + level = uptime hours** (level-up: emit
   `xp.levelup`, play `xp.levelup`). Somewhere unobtrusive (top strip or hotbar flanks): clock + date (in
   Minecraft style, e.g. "Day 309, 14:32" + real date on hover), active window title, tray, wifi/bt/volume chips,
   day/night toggle (sun/moon icon), notification bell (with unread count), launcher button (crafting table
   icon), widgets menu chip (keep per-card on/off + reset menu as a Minecraft dropdown). **Boss bar** at top
   centre for the brew timer (and media title when a player is playing, lower priority). Respect gamemode:
   spectator hides the HUD, creative suppresses heart/hunger warnings (read the gamemode from qs-features's
   state, contract: `~/.config/overworld/gamemode` file containing survival|creative|adventure|spectator,
   watch it).
2. **Launcher = creative inventory** (namespace `overworld-launcher`): tabs, 9-wide slot grid, search, tooltips,
   keyboard navigation (arrows, Enter, Tab between tabs, Esc), fuzzy search from the old fuzzy.js, `=`
   calculator (calc.js), `>` run command, favourites tab persisted, emits `launcher.launch`, `chest.open/close`
   sounds on open/close.
3. **Notifications = toasts** (`overworld-notif`): the D-Bus server stays (`NotificationService`); popups are
   toast sprites stacking from the top-right, slide in/out with `ui.toast.in/out` sounds, app icon in the toast
   icon slot, urgent = challenge style (purple title, `ui.toast.challenge`), actions as small Minecraft buttons,
   click/timeouts as before; emit `notify`. **Notification centre** (`overworld-notifcenter`) = chat-history
   style panel with Peaceful (DND) difficulty button, clear, per-app grouping.
4. **Network panel = Multiplayer screen** (`overworld-network`): all Apothecary NetworkService functions,
   ping-bar sprites for signal, server-row selection, Join Server/Direct Connection/Refresh/Cancel/Disconnect
   buttons, password text field, airplane mode toggle, wired + VPN as "LAN" rows, inline nmcli errors as red
   text; emit `net.connect`. Verify against the real adapter READ-ONLY (scan/list) — do NOT connect/disconnect.
5. **Power menu = Game Menu** (`overworld-power`): pause-screen layout, buttons as BRIEF §2 (Advancements,
   Statistics, Options open qs-features screens via their IPC: `qs -c overworld ipc call advancements open`
   etc. — or via `GameEvents.emit("ui.open", {screen})`; agree in REQUESTS.md), quit confirm screen. NEVER
   press the destructive buttons in testing.
6. **Wallpaper picker = Select World** (`overworld-wallpapers`): reads `assets/wallpapers/index.json` (fallback:
   directory listing), thumbnails, per-mode lists, keyboard nav, Play Selected World = apply via awww (keep
   Apothecary's transition + per-mode memory, emit `wallpaper.set`), **Create New World** runs
   `scripts/make-world.sh --mode <mode>` in the background with a progress screen ("Generating world…",
   "Building terrain" like the game's loading screen) and selects it when done (emit `world.created`), Delete
   World hidden or confirm-protected.
7. **OSD = options slider** (`overworld-osd`): "Master Volume: 75%", brightness "Brightness: Moody/…/Bright"
   with percentage; keep the backlight device logic.
8. **Workspace card = /title** (`overworld-wscard`): title/subtitle from WorkspaceNotes + `quotes/titles.json`
   defaults, tick timings 10/70/20, big Minecraft text with shadow; keep the IPC.
9. **Brew dialog = brewing stand GUI** (`overworld-brew`): keep all BrewDialog functionality; brewing-stand
   sprite (`gui/container/brewing_stand.png`), bubbles + arrow progress, fuel, bottles.
10. **SoundService** → calls `scripts/ow-sound <id>` (dry-run aware); all old sound names mapped to new ids.
    `ConfigService` gains the new keys used by Options (gui_scale, sound_volume.*, particles, weather_effects,
    daycycle, animations) with defaults — coordinate key names with qs-features via REQUESTS.md (qs-features
    builds the Options screen, you own the service).
11. Keep every IPC target/function from the Apothecary shell.qml working (BRIEF §4.6), update
    `docs/QUICKSHELL.md` (surfaces, namespaces, IPC, services, how to preview).

Screenshot every surface in Day and Night (`qa/screenshots/qs-core-<surface>-<mode>.png`) via dev-shot.sh
(use `layer:<namespace>` crops), open them, iterate until they look like real Minecraft GUI. Report in
`docs/agent-reports/qs-core.md` (+ the namespace list and IPC table).
