# hyprland-engineer (phase 2) — Hyprland layer, CLI, coexistence, lock/idle/SDDM, install

You own: `hypr/`, `sddm/`, `scripts/overworld`, `scripts/install.sh`, `scripts/uninstall.sh`,
`scripts/install-sddm.sh`, `scripts/backlight-dev.sh`, `scripts/ws-autolabel.py`, `docs/KEYBINDS.md`,
`docs/INSTALL.md`, `docs/SUDO-STEPS.md` (append).

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

1. **Coexistence + switch (BRIEF §4.2)** — the fork still behaves like Apothecary (own state dir, hook line,
   backups named `pre-overworld`). Make `overworld on` hand over cleanly from a running Apothecary (call
   `apothecary off`, or better a direct handover that avoids restarting waybar/mako in between if you can do
   it with Apothecary's public CLI/files only — never edit the Apothecary repo), remember `previous-theme`;
   `overworld off` restores exactly the previous state (Apothecary on in its mode, or stock). Hyprlock
   config swap must chain correctly (Apothecary moved the stock hyprlock.conf to `.pre-apothecary` and linked
   its own; Overworld must restore Apothecary's link on off, not the stock one). Remove the gateway
   import-environment/restart exec-once from `hypr/overworld.conf` (Apothecary's still provides it). Make
   `scripts/install.sh` idempotent and coexistence-safe (adds `source = ~/.config/hypr/overworld.conf #
   overworld` after the apothecary line, links `~/.config/quickshell/overworld`, `~/.local/bin/overworld`,
   state dir defaults — must not clobber the existing `~/.config/overworld/config.json`), `uninstall.sh`
   reverses only Overworld's changes.
2. **Hyprland look & motion** (`hypr/decorations.conf`, `animations.conf`, `rules.conf`, colours from
   tokens/out): rounding 0, crisp borders (2–3 px; active = Minecraft-ish e.g. white/light-grey or grass
   green, inactive dark grey; try a hard pixel drop shadow: `shadow` with small range, offset 4–6 px, high
   sharpness/`render_power` 4, dark colour — screenshot and judge), translucency kept (0.94/0.88 + blur
   ignore_opacity, video players opaque), animations per BRIEF §4.8 (named beziers e.g. `place = 0.2, 1.25,
   0.4, 1` overshoot pop-in, `snap = 0.1, 0.9, 0.2, 1`; windows popin 85 % ~2.5, close fast ~1.5 (the
   block-break effect does the drama), workspaces slide ~3.5, special slidevert, layers fade ~1.5, border angle
   off), layer rules for EVERY namespace qs-core/qs-widgets/qs-features/fx-* create (read their reports/QML
   for `WlrLayershell.namespace`; catch-all FIRST, widgets/weather/break/f3 layers: blur off, no animation
   for overlays that animate themselves, `ignore_alpha 0.35` for blurred panels), window rules for
   `overworld-test`, spf, pickers.
3. **CLI `scripts/overworld`**: keep every verb (on/off/status/light/dark/toggle/wallpaper …/reload/gamemode/
   repair/ws …/brew …/event/session-start/help) and add: `kill [address]` (block-break close via IPC
   `interact kill`, fallback `hyprctl dispatch killactive`), `chat [text]`, `f3`, `gamemode
   survival|creative|adventure|spectator|switcher` (adventure = the old performance gamemode
   implementation; spectator = focus: gaps 0, hide HUD/widgets via IPC, DND; keep `gamemode on|off|toggle` as
   aliases of adventure for compatibility), `weather <w>`, `daycycle <m>`, `sound <id>` (→ scripts/ow-sound),
   `world new [--scene …]` (→ scripts/make-world.sh), `advancements`, `stats`, `options`, `screenshot
   [mode]` (→ fx-interactions' script), and `help` pages for all of them. `status` reports previous-theme,
   gamemode, daycycle.
4. **Keybinds** (`hypr/keybinds.conf`, unbind JaKooLit conflicts only inside on.conf, absolute paths): BRIEF
   §4.7 — check every new key against `hyprctl binds -j` and JaKooLit's `~/.config/hypr/configs/Keybinds.conf`
   + `UserConfigs/UserKeybinds.conf`; SUPER+Q → `overworld kill`; Print/SHIFT+Print/etc. → the screenshot
   wrapper; JaKooLit scripts that would tear the theme down (GameMode.sh, Refresh.sh, WallpaperRandom.sh,
   WallpaperSelect.sh, ThemeChanger.sh, waybar menus) unbound/replaced as Apothecary did. Final table in
   `docs/KEYBINDS.md`.
5. **hyprlock = title screen** (`hypr/hyprlock.conf`): background = world-renderer's `assets/renders/lock-
   day.png`/`lock-night.png` (or the current wallpaper blurred), OVERWORLD wordmark image, yellow splash
   label rotated (hyprlock `rotate`), clock "Day N · HH:MM", Minecraft text-field style input (no rounding,
   black fill, grey outline), fonts Overworld Mojangles/Monocraft, "Singleplayer"-style hint text. Validate
   variables + every `cmd[]` by hand (cannot run hyprlock). hypridle: same timings as Apothecary, absolute
   paths, validate with `timeout 2 hypridle -c`. Do NOT start/stop the user's hypridle except inside
   `overworld on/off` itself.
6. **SDDM title screen** (`sddm/overworld/`, Qt6): rotating panorama (scrolling `assets/renders/panorama/
   strip.png` copied into the theme dir by install-sddm.sh `prepare`, or Qt Quick 3D cube if available),
   OVERWORLD wordmark, splash text, Minecraft buttons (Singleplayer = log in with the password field shown
   as a Minecraft text field, session selector as a cycling button "Session: Hyprland", power buttons as
   Quit Game/Respawn), bundled fonts (sddm user cannot read ~/.local/share/fonts — copy the TTFs in
   `prepare`). Test with `sddm-greeter-qt6 --test-mode --theme <dir>` (it opens a window — screenshot via
   dev-shot.sh after moving it to ws 77 is not possible… instead launch it with
   `hyprctl dispatch exec "[workspace 77 silent] sddm-greeter-qt6 --test-mode --theme <dir>"`, shoot, kill
   it by PID). Install steps → docs/SUDO-STEPS.md.
7. wlogout fallback themed (may already be in apps/ — coordinate with app-theming; you own nothing in apps/).
8. **Live verification at the END of your run only** (other agents test on top of Apothecary until then):
   `scripts/install.sh`, `overworld on` → screenshot (`qa/screenshots/hypr-on-day.png`), `overworld dark`,
   screenshot, `overworld off` → verify Apothecary is back ON in dark mode exactly as before (`apothecary
   status`, qs -c apothecary running, waybar stopped), `hyprctl configerrors` empty at each step. Leave the
   desktop as you found it (Apothecary ON, dark). Total time with Overworld on < 3 min.
Report in `docs/agent-reports/hyprland-engineer.md`.
