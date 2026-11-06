# projects-widget report — the "Projects" to-do card (follow-up, user at the desk)

Done 2026-11-06 ~11:10 HKT. No dev-shot, no workspace switch, no sound (the card plays `xp.orb`/`ui.click` through `Theme.playSound`; tests ran with `OW_SOUND_DRYRUN=1`), no commits, no sudo.
All visual checks are offscreen renders (QtQuick `Window` + `grabToImage`), all viewed. Details of the design are in `docs/WIDGETS.md` → *Projects*.

## Delivered
| what | where |
|---|---|
| Data layer: the rules (add / toggle / set / remove / edit / move / clearbuilt / insert / ordered) | `quickshell/Widgets/Services/projects.jq` |
| The one writer: `flock`, in place (`cat tmp > file`, never mv), refuses to overwrite invalid JSON; also `list` / `resolve <n\|id\|title>` | `quickshell/Widgets/Services/projects-write.sh` |
| `ProjectsService` singleton: watching `FileView`, queue of writes, diff → `project.add/built/remove` events, 5 s undo, `find()`, dialog state, IPC target `projects` (`open add toggle done undone remove rm edit undo list status`) | `quickshell/Widgets/Services/ProjectsService.qml` |
| The card (Book and Quill, 190×150 GUI px): In Progress / Built ✔ (fold, latest 5 + "+N more"), rows with checkbox, elided title, hover ✕, tooltip with note + dates, undo bar, empty state, `+` in the title bar, scrolling | `quickshell/Widgets/Projects/ProjectsCard.qml`, `ProjectRow.qml`, `ProjectBox.qml`, `PixelGlyph.qml` |
| Add / edit dialog, layer namespace `overworld-projects`, Exclusive keyboard (Title autofocus, Note, "Already built", Add=Enter, Cancel=Esc, Up/Down when editing) | `Projects/ProjectsDialog.qml` (layer) + `ProjectsForm.qml` (the panel, also used by the renders) |
| 9th card registered; `DesktopWidgets` is now a `Scope` (dialog + the per-screen `Variants`), mask region for the card | `DesktopWidgets.qml`, `WidgetLayout.qml`, `Services/WidgetsState.qml` (`cardList` → the bar's Desk Widgets menu lists it by itself, `WidgetsMenu.qml` untouched) |
| Layout: cards past the first 8 go into an overflow column (`plan(W,H,gui,sizes,nBase)`), clear of the boss bars and the HUD | `layout-plan.js`, `tests/widgets-layout.test.js` (extended) |
| Chat `/project add\|done\|undone\|toggle\|remove\|undo\|list\|edit` + bare `/project` (dialog), Tab completion of actions and whole titles, "Nurasik built [Title]!" line (green bracket, hover = note) | `quickshell/Game/ChatService.qml`, `quotes/chat.json` (`ok.project_*`, `system.project_built`) |
| CLI `overworld projects [list\|add <title> [--note t] [--built]\|done\|undone\|toggle\|rm\|clear [--yes]\|open\|edit]` + `overworld help projects` + the general help line | `scripts/overworld` |
| Keybind `SUPER+SHIFT+P` → `projects open` (free: checked `hyprctl binds -j`; SUPER+P is pseudotile) | `hypr/keybinds.conf`, `docs/KEYBINDS.md` |
| Docs | `docs/WIDGETS.md`, `docs/GAMEPLAY.md`, `README.md` |
| Tests / harnesses | `quickshell/Widgets/preview/projects-test.qml`, `projects-chat-test.qml`, `projects-render.qml` (+ a `Game ⇒ ../../Game` symlink in `preview/` for the chat test) |

`ChatCommands.js` needed no change (the title completion is in `ChatService.completions`). `hypr/rules.conf`: **no new layer rule** — `hypr/decorations.conf` already matches `^(overworld-.*)$` (blur on, no animation), which is what the brew dialog gets too.

## Decisions
- **Remove = ✕ on hover + 5 s Undo bar** on the card (also `/project undo`, IPC `undo`), no right-click menu, no confirmation. `clearBuilt` is undoable the same way.
- **Checkbox is drawn, not the 20 px sprite**: the real `widget/checkbox` is 20×20 (a 20 GUI px row would make the card 3× too tall), so `ProjectBox` redraws it at 11 GUI px (black outline, grey frame, white when hovered, dark fill, green pixel tick). Same for the ✕ / fold arrows (`PixelGlyph`, 1 GUI px squares, no font dependence).
- **No optimistic copy**: the card shows what the file says; every change is a write by `projects-write.sh` and the watcher brings it back (~100 ms). One source of truth for card, chat, CLI and hand edits.
- **Events from the diff**, not from the actions: a click, `/project`, `overworld projects`, and a text editor each announce exactly once.
- **Overflow column** instead of squeezing: at 1920×1080 GUI 2 the two stacks end at y 1008 / 980 of 1036 allowed, so nothing fits there. Projects sits at x 1124, y 80 (just left of Clock & Calendar, under the boss bars), at GUI 1 at x 1522, y 8. GUI 3 at 1080p: the Sign and Projects have no room (as the Sign alone had before); 2560×1440 GUI 3: 9/9.
- Fold state of "Built" / "+N more" is not persisted (per shell run).
- The user's file: the brief assumed an empty list, but `~/.config/overworld/projects.json` already held the user's own 3 projects (created 11:02 HKT, minutes after the card appeared, not by any of my tests, so presumably the user trying the card). I left them alone; the smoke test added and removed a test entry and the file ended **content-identical** to how I found it (verified with `jq -S` diff against a backup in `~/.hermes/cache/scratch/projects-widget/`).

## Verified
- **service** `projects-test.qml` → **44 PASS / 0 FAIL** (temp file; missing file → empty and not created, add ×3 with blank title refused, whitespace collapsed, built split/order, toggle both ways, built_at added/removed, rename + note, move up/down within a section only, remove + undo to the same place, external edit picked up by the watcher, 4 CLI + 2 service writers at once → 10 items nothing lost + unique ids, half-written/invalid file keeps the list then recovers, find by number/prefix/ambiguous/none, clearBuilt + undo, IPC-style `act`, events add/built/remove exactly once, no event on the first load, file is valid JSON at the end).
- **chat** `projects-chat-test.qml` → **26 PASS / 0 FAIL** (add, bare add → usage error, done by prefix and by number, the "Nurasik built [X]!" line exactly once, already built, undone, no match / no argument errors, list header + numbering, remove by number, `/project undo`, second undo → "Nothing to undo", completion of actions / in-progress / built titles / whole-title Tab, `/help` lists it, bare `/project` and `/project edit` open the dialog on the right project, unknown verb → usage).
- **card handlers** `projects-render.qml` `OW_RENDER_WHAT=act` → 7 PASS: `toggleItem` (the box's click handler) built / unbuilt, `removeItem` (✕) removes and offers undo, `undoRemove` restores, "+N more" logic, `openDialog` (the + button's path).
- **CLI** against a temp file (`OW_PROJECTS`): list (empty hint, numbered sections), add with note and `--built`, `done` by prefix / number / ambiguous (rc 4) / none (rc 3) / missing (rc 1), `undone`, `rm`, `clear` refusing without a tty and `--yes`, `help projects`, general help. `bash -n` on `scripts/overworld` and `projects-write.sh`.
- **layout** `node tests/widgets-layout.test.js` → ok on 7 sizes (9/9 placed at GUI 1 and 2, no overlaps, nothing below the HUD limits, no overflow card under the boss bars, the first 8 slots identical with and without the 9th card).
- **renders** (software renderer, Mojangles font, opacity pinned 0.72), Day and Night, all viewed — `qa/screenshots/projects-widget-*.png`:
  `card-{dark,light}` (4 in progress incl. a long elided title + 3 built, hovered row with ✕; `card-light` with the tooltip), `empty-{dark,light}`, `undo-dark`, `fold-dark`, `long-dark` (8 + 9 built: scrollbar), `long-all-light`, `dialog-{dark,light}`, `edit-{dark,light}` (title selected, note, Up/Down), `layout-{dark,light}` (the whole 1920×1080 layout: Projects beside the right stack, HUD area free, no overlap).
- **Live** (the shell hot-reloaded each save; `~/.cache/overworld/qs.log` checked after each): "Configuration Loaded", no QML warning from any of my files. The only ERROR in the log is one from my first, half-written save of `DesktopWidgets.qml` (unbalanced brace, 11:0x), fixed within seconds. Hyprland picked up the new bind by itself, `hyprctl binds -j` shows `SUPER+SHIFT+P → qs -c overworld ipc call projects open`, `hyprctl configerrors` empty (I did not run `hyprctl reload`). `qs -c overworld ipc call projects status|list` answer; `widgets cards` lists `projects on`.
- **Real-path smoke** (live shell): `overworld projects add "Test project" --note …` → `list` (shown, IPC `1 in progress, 3 built`) → `rm "Test project"` → `list` (IPC `0 in progress, 3 built`); the live watcher followed both changes; file identical to the start.

## Not verified
- Real pointer / keyboard input (no input injection while the user is at the desk): the clicks on the box / ✕ / Undo / + / header, the double-click edit, the hover tooltip timing, typing + Enter / Esc / Tab in the dialog, dragging the card by its title bar, the real `SUPER+SHIFT+P` press. The handlers behind them are covered above (signals → card functions → service), the dialog's form was only rendered, never driven by keys.
- The dialog as a layer on a real output (`OverlayWindow`, Exclusive keyboard): same code path as `BrewDialog`, but it was only rendered through `ProjectsForm` in a plain window, not shown as `overworld-projects`.
- Sounds (`xp.orb` / `ui.click`): code path only.
- `Hyprland` layer rule effect of `overworld-.*` on the dialog (blur + no animation): inherited, not looked at.
- Real-time `project.built` → chat line in the live shell: tested in the harness (private bus), not provoked on the user's real list.

## Known limits
- Titles are collapsed to single spaces and capped at 120 characters (note 240) in the dialog; the CLI/chat do not cap.
- `/project add` takes only a title (no note); use the dialog or `overworld projects add … --note`.
- Undo lives in the shell process: the CLI cannot undo, and a remove done by the CLI or an editor has no undo bar.
- Re-adding through undo emits `project.add` again (nothing listens to it yet).
- Saved card positions win over the layout, as for every card (`~/.config/overworld/widget-positions.json` has entries for `quote`, `brew`, `sysinfo`; none for `projects`).

## Requests filed
none.

## Please try (user)
1. The card is on the desktop (layer: widgets, default spot just left of the Clock & Calendar card). Click **+** in its title bar, or press **SUPER+SHIFT+P**: type a name, **Enter** adds, **Esc** cancels. Tab goes Title → Note → "Already built".
2. Click a checkbox: the project moves to **Built ✔** (grey, struck through) and the chat says "Nurasik built [Title]!"; click again to un-build it.
3. Hover a row: the **✕** appears (remove; an **Undo** bar shows for 5 s) and after 0.4 s the tooltip with the note and dates. **Double-click a title** = edit (rename, note, built, Up/Down).
4. Click the **Built** header to fold it; with more than 5 built, "+N more" / "Show less". Long lists scroll.
5. Chat (`T` or SUPER+/): `/project add Hyprland rice`, `/project list`, `/project done hypr` (or the number), `/project remove 2`, `/project undo` — Tab completes titles.
6. Terminal: `overworld projects`, `overworld projects add "Title" --note "x"`, `overworld projects done 2`, `overworld projects rm 3`, `overworld help projects`.
7. `qs -c overworld ipc call projects list`.
8. Drag the card by its title bar, double-click the bar to put it back; the desk-widgets menu in the bar lists "Projects" with an on/off checkbox.
