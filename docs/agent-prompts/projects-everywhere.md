# projects-everywhere (follow-up) — the Projects to-do in Apothecary and the stock desktop too, one shared list

Prerequisite: the `projects-widget` agent already built the Overworld version — read
`docs/agent-reports/projects-widget.md`, `quickshell/Widgets/Projects/`, `quickshell/Widgets/Services/ProjectsService.qml`,
the `/project` chat command and `overworld projects` CLI first.

The user: "I want it in other themes too." Themes on this machine: Overworld (this repo), **Apothecary**
(`~/Projects/apothecary-hyprland`, installed, currently OFF; its own git repo — you may edit it this time), and the
**stock JaKooLit** desktop (waybar + mako, used when both themes are off; its config under ~/.config/hypr/configs,
~/.config/waybar must NOT be edited in place).

## THE USER IS AT THE DESK (hard rules)
No scripts/dev-shot.sh, no workspace switching, no on-screen previews/windows/rofi menus, no theme switching
(`overworld|apothecary on|off|light|dark`), no sound, no git commits, no sudo. Visual checks = OFFSCREEN renders
(`QT_QPA_PLATFORM=offscreen` qs harness, grabToImage of a child Item → PNG; read it). Overworld is LIVE and hot-reloads
QML you save: keep saves valid, check `~/.cache/overworld/qs.log` after each. Apothecary's shell is not running, so
validate it with an offscreen harness that symlinks its Common/Services/Widgets dirs.

## Build
1. **One shared list for all themes.** Move the data to a theme-neutral path `~/.local/share/hypr-projects/projects.json`
   (same schema). A standalone CLI `scripts/hypr-projects` (installed as `~/.local/bin/hypr-projects` by both themes'
   install.sh, idempotent symlink) owns all writes from the shell side (flock + in-place write, never mv): `list
   [--json]`, `add <title> [--note N] [--built]`, `done|undone|rm <n|title-prefix>`, `rename <n> <title>`, `menu`
   (rofi picker, see 4). Overworld's `overworld projects …`, ProjectsService and `/project` keep working on the new path
   (one-time migration: if ~/.config/overworld/projects.json exists and the new file doesn't, copy it over and leave a
   note in the old one's place / or keep the old as .bak). Both QML services watch the shared file, so a check in one
   theme shows in the other after a switch, and CLI edits appear live.
2. **Apothecary card** "Projects · 工程" in Apothecary's own style (PaperPanel / TitleBar with seal, ink checkboxes,
   paper-note rows, vermilion seal stamp "成" (completed) on built items — verify the glyph exists in its CJK fonts with
   `fc-list ":family=<F>:charset=6210"`), same features as Overworld's (sections In Progress / Built, add dialog with
   keyboard focus like its BrewDialog, double-click edit, hover ✕ + undo, scroll, empty state, drag/hide/positions,
   widgets-menu entry, IPC `projects open|add|toggle|remove|list`, `apothecary projects …` CLI verb delegating to
   hypr-projects, layer rule for its dialog namespace, opacity like its other cards). Respect its layout system so
   nothing overlaps at its default positions; both light and dark modes. Docs: its WIDGETS.md, README, CHANGELOG.
3. **Sounds**: Apothecary uses its wood-block/seal cues (`seal.wav` on built), Overworld keeps xp.orb.
4. **Stock desktop** (both themes off): no widget layer exists, so provide (a) `hypr-projects menu`: a rofi menu
   (theme: whatever rofi uses by default) listing "☐ in-progress" and "☑ built" rows; Enter toggles, a top row
   "+ Add project…" prompts for the title (rofi -dmenu), "✕ Remove…" submenu; loops until Esc; and (b) a keybind
   SUPER+SHIFT+P (verify free in `hyprctl binds -j` and JaKooLit's Keybinds.conf/UserKeybinds.conf; pick another if
   taken) that runs it — put the bind in Overworld's `hypr/off.conf` AND Apothecary's `hypr/off.conf` (sourced only
   while that theme is off; identical bind lines, harmless if both load) so it exists on stock without editing
   JaKooLit files. Also bind the same key in both themes' ON keybinds to open their in-shell add/projects dialog.
   Optional (b2): a notify-send summary `hypr-projects summary` — skip waybar.
   Test rofi only with `rofi -dump-config`/`-dmenu` fed from a pipe with `-filter`/`-auto-select` in a NON-display way
   if possible; otherwise test the menu's logic by calling its non-interactive functions; never open a rofi window.
5. **Verify**: hypr-projects test suite against a temp `HYPR_PROJECTS_FILE` (every verb, prefix matching,
   numbering, concurrent writes, migration). Offscreen renders of the Apothecary card + dialog in light/dark with
   sample data, viewed. Overworld still loads clean and its card reads the shared file. `bash -n`,
   `Hyprland --verify-config`-style check / `hyprctl configerrors` clean after a single final `hyprctl reload`.
   Final real smoke: `hypr-projects add "Test"; hypr-projects list; hypr-projects rm Test` → real file left with the
   user's items unchanged (back it up first and diff).
Report in docs/agent-reports/projects-everywhere.md (both repos' changed files, "please try" list per theme).
