# now-playing-pip-apothecary (follow-up): the floating Now Playing video mini-player for the Apothecary theme

Prerequisite: the `now-playing-pip` agent just built the Overworld version plus the shared, theme-neutral parts: the
Zen userscript `apps/zen/nowplaying-bridge.user.js`, the daemon/CLI `scripts/hypr-nowplaying`, the state file in
`$XDG_RUNTIME_DIR/hypr-nowplaying/` and the video cache `~/.cache/hypr-nowplaying/`. Read
`docs/agent-reports/now-playing-pip.md` (especially "for the Apothecary port"), the Overworld service + surface, and
`docs/agent-reports/sticky-notes-apothecary.md` (how the last shared feature was ported to Apothecary).

Target repo: `~/Projects/apothecary-hyprland` (its own git repo; you may edit it). Read its BRIEF.md,
docs/WIDGETS.md, docs/DESIGN.md, its music card/service, its widgets menu + WidgetsState, `scripts/apothecary`,
`hypr/keybinds.conf`, `hypr/decorations.conf`, `scripts/install.sh`, `tokens/`.
Don't change the Overworld repo except: copy `scripts/hypr-nowplaying` (and the userscript if Apothecary keeps an
`apps/zen/` copy) byte-identical into Apothecary; fix a real bug in them only if you find one (then in both copies,
and note it).

## THE USER IS AT THE DESK (hard rules)
No grim/dev-shot, no workspace switching, no on-screen previews/windows, no theme switching
(`overworld|apothecary on|off|light|dark`), no sound, no git commits, no sudo, no input injection, never control
the user's players. Apothecary's shell is NOT running (Overworld is live). Validate with an offscreen harness that
symlinks its Common/Services/Widgets dirs (`QT_QPA_PLATFORM=offscreen`, grabToImage of a child Item → PNG, Read it).
Tests use temp runtime/cache dirs and a temp token.

## Build
1. Surface (namespace `apothecary-nowplaying`) with the same behaviour as Overworld's: always on top (Overlay layer by
   default, config `nowplaying.layer`), muted synced video mirror, thumbnail fallback with blurred letterbox, portrait
   frame for TikTok/Shorts, title/artist/source strip, hover controls (⏮ ⏯ ⏭, focus source, ✕, resize grip), drag +
   persist + double-click reset, auto-hide, hide when the source browser is the focused fullscreen window, persisted
   on/off that starts OFF. Look: Apothecary's world (e.g. a hanging scroll / framed paper window with a vermilion seal
   in the title strip, ink text), light and dark modes. Check every CJK glyph you add with
   `fc-list ":family=<F>:charset=<hex>"` (see DESIGN.md).
2. Service (reuse its MPRIS service, merge the bridge state the same way, run the shared daemon as a child Process
   only while on), IPC target `nowplaying` with the same verbs, a widgets menu row, `apothecary nowplaying …` + help
   page, the same keybind Overworld chose in its ON keybinds, layer rule in `hypr/decorations.conf`, config keys in
   its config.json, install.sh symlink for hypr-nowplaying.
3. Verify: offscreen renders in light and dark (landscape, portrait, thumbnail-only, hover controls) all viewed; the
   shared CLI still passes Overworld's test suite; `bash -n`/syntax checks on every script you touched.
4. Docs: its docs/WIDGETS.md section, README bullet + CLI table, KEYBINDS, CHANGELOG.

Report in `~/Projects/overworld-hyprland/docs/agent-reports/now-playing-pip-apothecary.md`: changed files, decisions,
verified vs not verified, "please try" list.
