# sticky-notes (follow-up) — a sticky-note desk widget for raw, stray thoughts (Overworld + shared data/CLI)

The user: "Create a sticky note, Minecraft-stylized, raw stray thoughts writing widget. Make it for Apothecary Diaries
too." This run builds the Overworld card, the shared data file and the shared CLI. A second agent
(`sticky-notes-apothecary`) ports it to Apothecary right after you, from your report — so write the report for it.

Read first: BRIEF.md (§1 rules), docs/WIDGETS.md, docs/agent-reports/projects-widget.md and
projects-everywhere.md (the closest precedent: same card/dialog/service/CLI/shared-file pattern — copy its idioms:
in-place writes under flock, writer script, watched FileView, undo, IPC, chat command, layout overflow column,
offscreen render harness), `scripts/hypr-projects`, `quickshell/Widgets/Projects/`, `quickshell/Brew/BrewDialog.qml`.

## THE USER IS AT THE DESK (hard rules)
No scripts/dev-shot.sh, no grim, no workspace switching, no on-screen previews/test windows/rofi windows, no
`overworld on/off/light/dark/gamemode`, no sound, no git commits, no sudo, no input injection. Visual checks =
OFFSCREEN renders (`QT_QPA_PLATFORM=offscreen` harness, grabToImage of a child Item → PNG, then Read the PNG).
The live `qs -c overworld` hot-reloads every QML save: keep each save valid and check `~/.cache/overworld/qs.log`
right after for errors from your files. Tests use an env-overridable data path (`HYPR_NOTES_FILE`), never the real
file, except the final real-path smoke below.

## What it is
A pad of sticky notes for dumping thoughts fast: no titles, no structure, no checkboxes (that is the Projects card's
job). Open → type → it's saved. Must feel faster than opening an editor.

## Build
1. **Shared data** `~/.local/share/hypr-notes/notes.json` (theme-neutral, read by both themes):
   `{"sheets":[{"id","text","created":ISO,"updated":ISO,"color"?}],"current":<id>}`. Starts empty (never invent the
   user's notes). Plain text, multi-line, cap ~4000 chars per sheet.
2. **Shared CLI** `scripts/hypr-notes` (symlinked to `~/.local/bin/hypr-notes` by install.sh, idempotent, like
   hypr-projects; it owns every write: flock + in-place, refuses to overwrite invalid JSON): `list [--json]`,
   `add <text…>` (also reads stdin when text is `-`, so `echo x | hypr-notes add -` works), `show [n]`,
   `rm <n>`, `edit [n]` (opens `$EDITOR` on that sheet, writes back), `clear [--yes]`, `menu` (rofi: "+ New note…"
   prompt, list of sheets by first line → Enter shows it / Del submenu; `--if-stock` guard like hypr-projects), `-h`.
   `overworld notes …` delegates to it; `overworld help notes` page.
3. **Service** `NotesService` singleton (watched FileView, writes through the CLI/writer, 5 s undo for a torn-off
   sheet, IPC target `notes`: `open` (edit current), `new`, `add <text>`, `next`, `prev`, `remove`, `undo`, `list`,
   `status`). Edits from CLI/editor show up live.
4. **Card** "Notes" (10th card, registered like Projects: WidgetsState cardList → widgets menu, drag/hide/positions,
   translucency like the others, Day + Night). Minecraft look: a sheet of **Paper** (the paper item's cream/pixel
   palette, a folded pixel corner, a pixel pin/nail or hung in an Item Frame) — it MUST read as distinct from the Sign
   (Quote card) and the Book and Quill (Projects card). Text in the theme's Minecraft font, wrapped, fading out at the
   bottom when long. Footer: page counter `2/5`, ◀ ▶ to flip (also mouse wheel over the card), `+` new sheet, a
   tear-off ✕ on hover with Undo bar, relative time ("3 min ago"). Empty state: "Click to scribble a thought…".
   Optional small fun: when a sheet is torn off, a paper-break crumb particle (only if the theme already has a
   particle helper; respect reduced_motion).
5. **Typing** (the key requirement): the widget layer has `keyboardFocus: None`, so clicking the sheet (or the
   keybind) opens an **edit layer** (namespace `overworld-notes`, Exclusive keyboard, like BrewDialog) drawn as the
   SAME paper sheet, positioned exactly over the card's screen position (fall back to screen-centre if the card is
   hidden), slightly larger, with a blinking text cursor at the end — it should feel like writing on the note itself,
   in the spirit of Minecraft's sign/book edit screen ("Done" button). Multi-line TextArea: Enter = newline,
   Esc / Ctrl+Enter / click outside / Done = save + close, Ctrl+N new sheet, Ctrl+PgUp/PgDn flip, autosave
   debounced ~700 ms while typing so nothing is ever lost. Empty sheets are dropped on close.
6. **Quick capture**: chat `/note <text>` (adds a sheet, "Note pinned." line), `/note` alone opens the editor,
   `/note list`. Keybind: find a free one (`hyprctl binds -j`, JaKooLit Keybinds.conf/UserKeybinds.conf;
   SUPER+N, SUPER+SHIFT+N, SUPER+T are taken — try SUPER+ALT+N first) → `notes new` in `hypr/keybinds.conf`, and
   the same key → `hypr-notes menu --if-stock` in `hypr/off.conf` (stock desktop). Document in docs/KEYBINDS.md.
   Do NOT `hyprctl reload` unless needed; if you do, once at the end, and `hyprctl configerrors` must stay empty.
7. **Layout**: fits the default layout (layout-plan.js overflow column machinery; extend
   `tests/widgets-layout.test.js`) without covering HUD, boss bars or other cards at GUI 1/2.
8. **Verify**: CLI test suite against a temp `HYPR_NOTES_FILE` (every verb, stdin add, numbering, concurrent writes,
   invalid-file refusal); service test (add/edit/flip/remove/undo/external edit/autosave debounce/empty-sheet drop);
   offscreen renders, Day and Night, all viewed: empty card, card with a long multi-line note (fade), 3/5 pager +
   hover ✕, undo bar, the edit layer with text + cursor. Live: qs.log clean, `qs -c overworld ipc call notes status`
   answers. Final real smoke: `hypr-notes add "test note"` → `list` → `rm` it; back the real file up first (if it
   exists) and diff — leave it as you found it.
9. **Docs**: docs/WIDGETS.md section, README (widgets list + CLI table), docs/KEYBINDS.md, docs/GAMEPLAY.md
   (/note), CHANGELOG.md entry.

Report in docs/agent-reports/sticky-notes.md: changed files, decisions, what was verified and how, what wasn't
(real clicks/keys), a "please try" list, and a "for the Apothecary port" section (data/CLI contract, which files to
mirror, gotchas you hit).
