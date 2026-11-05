# fix-pass (phase 4) — close the open issues from qa/REPORT.md

Phase 4: you may edit any repo file (minimal, targeted changes). Overworld is LIVE (ON, Day) and `qs -c overworld`
hot-reloads when you save QML — check `~/.cache/overworld/qs.log` (or the log path in `overworld status`) for
errors after every QML save; a QML error must never be left in place. Read qa/REPORT.md "Open issues" and
docs/REQUESTS.md (anything not marked done).

Fix, verify each (screenshot via scripts/dev-shot.sh where visual, view it), and record in
docs/agent-reports/fix-pass.md:
1. GUI scale 3 widget overflow (`Widgets/WidgetLayout.qml`): all 8 cards must fit or wrap without covering the
   HUD at gui_scale 1, 2, 3 (test scale 3 by editing config.json `gui_scale` in place and RESTORE it to its
   previous value after).
2. btop at Monocraft's line height: make the themed btop usable in a half-height kitty split (smaller preset or
   per-window font via the spf/btop launch, document).
3. Select World rows not following a mode flip while open (`Wallpapers/WallpaperPicker.qml:146`).
4. `qs ipc wallpapers next` should not open the picker (match `overworld wallpaper next`), keep a separate open.
5. Multiplayer list sometimes shows only the connected row right after opening — find the cause (scan timing /
   nmcli caching) and fix; READ-ONLY nmcli only, never connect/disconnect.
6. `overworld gamemode` with no argument → print status (no toggle); keep `toggle` explicit.
7. JaKooLit F6-style screenshot binds → route through scripts/interact/screenshot.sh (hypr/keybinds.conf, unbind
   first, verify with `hyprctl binds -j`, `hyprctl configerrors` empty).
8. Brew-done notification icon "brewing_stand" not found → use a real icon path.
9. TimeService.qml:14 hot-reload warning.
10. Asset fallbacks incomplete (REQUESTS) — make every sprite the shell references resolve to an assets/gen
    file or the missing texture without QML warnings when `assets/mc` is absent: test by pointing Theme at a
    fake empty mc dir in a PREVIEW (`qs -p`), not the live shell.
11. Remove `scripts/fetch-minecraft-sounds.sh` if nothing calls it (grep), or make it a wrapper of
    fetch-minecraft-assets.sh --sounds-only.
12. F3 rows: real F3 draws a translucent grey background strip behind each text line — check World/F3Layer.qml
    and match it if missing.
Do NOT touch: the user's ~/.config/rofi/config.rasi (report only), media playback, Zen, sound config
(`sounds` stays false). End with `overworld status`, full config load clean, and Overworld still ON.

## UPDATE 13:25 — THE USER IS NOW AT THE DESK USING THE DESKTOP (overrides anything above)
- `scripts/dev-shot.sh` is disabled (exit 6). Do NOT switch workspaces, do NOT run `qs -p` previews (their layers
  would pop up over the user's work), do NOT open test windows, do NOT run `overworld on/off/light/dark/gamemode`,
  do NOT change config.json (skip the gui_scale live test — reason it out from the layout code instead, and
  test layout math with a pure-JS/QML-free check if possible, e.g. node on the extracted function).
- You may edit repo files. The live `qs -c overworld` hot-reloads QML you save: make each QML edit complete and
  syntactically valid, then immediately read the shell log (`overworld status` shows it; usually
  ~/.cache/overworld/qs.log) for errors/warnings from that file and fix at once. Prefer `qmllint` if present.
- Hypr config edits: `Hyprland --verify-config -c <file>` style checks are fine; `hyprctl reload` is allowed only
  once at the end, and only if `hyprctl configerrors` would be clean.
- Instead of screenshots, end your report with a short "please eyeball" checklist for the user (which key/
  command to press and what they should see).
