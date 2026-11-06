# projects-widget (follow-up) — a "Projects" to-do card: built vs in progress, add/remove/check easily

You own: new `quickshell/Widgets/Projects/` (card + dialog), new `quickshell/Widgets/Services/ProjectsService.qml`,
and these EDITS only: `quickshell/Widgets/DesktopWidgets.qml` + `WidgetLayout.qml` + `layout-plan.js` +
`Services/WidgetsState.qml` (register the 9th card), `quickshell/Bar/WidgetsMenu.qml` (if the card list is not
already generated from WidgetsState), `quickshell/Game/ChatService.qml` + `ChatCommands.js` + `quotes/chat.json`
(a `/project` command), `scripts/overworld` (a `projects` verb + help), `hypr/rules.conf` (layer rule for a new
namespace), `docs/WIDGETS.md`, `docs/GAMEPLAY.md`, `README.md` (one line in the widgets list + CLI table).
Read first: BRIEF.md (§1 rules, §4), docs/WIDGETS.md, docs/agent-reports/qs-widgets.md and fix-pass.md, the
existing cards (e.g. `Widgets/BrewTimer/`, `Widgets/BlockOfDay/`) and `quickshell/Brew/BrewDialog.qml` (a dialog
layer that takes keyboard focus — the widget layer itself has `keyboardFocus: None`, so typing must happen in a
dialog layer or the chat).

## THE USER IS AT THE DESK (hard rules)
No scripts/dev-shot.sh (disabled), no workspace switching, no on-screen previews/test windows, no
`overworld on/off/light/dark/gamemode`, no sound, no git commits, no sudo. Visual checks = OFFSCREEN renders
(`QT_QPA_PLATFORM=offscreen` harness grabbing an Item to PNG with grabToImage — see fix-pass.md / adv-reset.md for
the working pattern; FloatingWindow.contentItem can't be grabbed, grab a child Rectangle), then Read the PNG.
The live `qs -c overworld` hot-reloads every QML save: keep each save valid and check
`~/.cache/overworld/qs.log` right after for errors from your files. NEVER write the user's real
`~/.config/overworld/projects.json` during tests except through the final real-path smoke described below; use
an env-overridable path (e.g. `OW_PROJECTS` or the existing test HOME pattern) for tests.

## The user's request
"I need a new widget like a to do, to keep track of my built and in progress projects. I should be able to
add/remove/check easily."

## Build
1. **Data** `~/.config/overworld/projects.json` (create on first use): `{"items":[{"id","title","note"?,
   "status":"progress"|"built","created":ISO,"built_at"?:ISO}]}`; ProjectsService singleton: FileView with
   watchChanges, in-place writes (`jq`/printf to tmp then `cat tmp > file` under flock — never mv), API add(title,
   note), remove(id), toggle(id), rename(id,title), move(id, ±1), clearBuilt(); emits
   `GameEvents.emit("project.add|project.built|project.remove", {title})`. Start EMPTY (never invent the user's
   projects), with an empty-state hint ("No projects yet — click + or type /project add <name>").
2. **Card** "Projects" (Minecraft object: a **Book and Quill** / lectern page, or a quest-log look in the McPanel
   style used by the other cards — pick what looks best next to them; match their translucency, title bar,
   drag handle, hide/show, positions). Two sections: **In Progress** (unchecked) and **Built ✔** (checked,
   grey/strikethrough or green "§a✔", collapsible, shows the latest ~5 with "+N more"). Each row: Minecraft
   checkbox sprite (click = toggle, plays `ui.click`/`xp.orb` when built, and a small chat line
   "Nurasik built [Title]!" like an advancement), title (elided, tooltip with the note + dates on hover), and a
   small ✕ remove button that appears on row hover (remove asks no dialog but supports undo: a 5 s "Undo"
   button/chat line, or right-click → remove; choose and document). Header "+" button opens the add dialog.
   Scroll when long (McScrollbar). Mouse wheel/ drag reorder optional.
3. **Add dialog** (namespace `overworld-projects`, keyboard focus Exclusive/OnDemand like BrewDialog): McTextField
   for the title (autofocus), optional note field, "Add" (Enter) / "Cancel" (Esc), checkbox "Already built". Also
   reachable by double-clicking a row → edit (rename/note) in the same dialog. IPC target `projects`:
   `open`/`add <title>`/`toggle <id>`/`remove <id>`/`list`.
4. **Quick ways** (the user said "easily"): chat `/project add <title>`, `/project done <title-prefix|n>`,
   `/project remove <title-prefix|n>`, `/project list` (tab completion of titles); CLI `overworld projects
   [list|add <title>|done <n>|undone <n>|rm <n>|open]` (numbers as shown by list). Keybind: suggest one in
   docs/KEYBINDS.md only if a free key exists (check `hyprctl binds -j`), add to hypr/keybinds.conf, and only
   `hyprctl reload` once at the end if `hyprctl configerrors` stays clean.
5. **Layout**: the card must fit the default layout without covering the HUD or other cards at gui 1/2 (use the
   layout-plan.js machinery and its node test `tests/widgets-layout.test.js` — extend the test). Day + Night.
6. **Verify**: offscreen renders of the card (empty state, 4 in-progress + 3 built, hover row with ✕, long
   title elision) and the dialog, Day and Night, all viewed. ProjectsService logic test against a temp file (add,
   toggle, remove, rename, reorder, external edit picked up by watch, concurrent CLI write). CLI tested against
   the temp path. Final real smoke on the LIVE shell: `overworld projects add "Test project"` → `list` → `rm`
   it, leaving the real file with an empty item list; check qs.log clean.
Report in docs/agent-reports/projects-widget.md ending with a "please try" list (keys/clicks).
