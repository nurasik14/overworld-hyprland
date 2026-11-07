# sticky-notes report — the Notes card (Overworld), the shared pad and CLI

Done 2026-11-06, finished 22:30 HKT (the laptop was suspended 18:10–22:15). No dev-shot, no grim, no workspace switch, no on-screen window or rofi window, no theme switch, no sound, no commits, no sudo, no input injection into the desktop. Visual checks are offscreen renders, all viewed. Details of the design: `docs/WIDGETS.md` → *Notes*.

## Incident: I deleted the user's note for about 30 seconds (restored)
The user started using the card while I worked and pinned **"Finish the note taking widget in apothecary theme."** at 18:08 HKT. My third real-path smoke (`hypr-notes add "test note"` → `list` → `rm 1`) assumed the pad was still empty, so `rm 1` tore off **their** note and left my test note. The laptop suspended two seconds after the add, so `rm 1` ran right after the 22:15:30 wake.
- **Restored at 22:16:00** from the backup taken just before the add, in place under the lock, verified byte-identical with `cmp`. Before the restore the file held only my test note, so nothing else was lost.
- **What the user may have seen:** for about 30 s after waking the laptop, the card showing "test note" instead of their note. They should not be left wondering, so please tell them.
- **Cause:** a hard-coded number in my smoke, not a bug in the widget. The rerun selects the sheet by id and only compares at the end, it never overwrites. **The Apothecary agent's final smoke must do the same; the pad is not empty any more.**
- Backups are in `~/.hermes/cache/scratch/sticky-notes/` (`notes.json.final`, `notes.json.before-final-smoke`).

## Open question: the user's note is gone again, and I do not know why
**At the end of this run the pad is empty (`{"sheets":[]}`), and "Finish the note taking widget in apothecary theme." is not on it.** The file matched my backup at 22:16:38 and was rewritten at **22:18:00.012**. I did not restore it a second time, because that may be the user's own tear-off and I had no grounds to overwrite the pad on a guess.
- **Ruled out:** my smoke (finished and compared equal 82 s earlier); `selftest.qml`, which overlapped that moment (rerun with a seeded pad in a temp HOME: pad untouched, real pad not written); the Hermes shell started at 22:17:51 (it only waits for this run to end, then starts the Apothecary agent); timers and cron (none near then); leftover test instances (none running).
- **What remains:** the only ways to remove a sheet are the ✕ on the card, emptying a sheet and closing the editor, the IPC `notes remove`, and `hypr-notes rm|clear`. Those are all human actions unless something invoked them, and I found nothing that did. The user was at the desk (Zen spawned processes at 22:17:42 and 22:18:35) and has dragged the card (`widget-positions.json`: `notes: [1526,11]`). So a deliberate or accidental tear-off is the likeliest explanation, but **this is an inference, not established**, and the time landing on a minute boundary is odd. The 5 s Undo had long expired by the time I looked.
- **To get it back**, this cannot clobber anything written since: `hypr-notes add "Finish the note taking widget in apothecary theme."`
- **If it turns out the user did not remove it, treat that as a data-loss bug** and look at those paths first. The ✕ sits in the sheet's top-right corner, close to where a click opens the editor, so a mis-click is plausible.

## Delivered
| what | where |
|---|---|
| Shared CLI: `list [--json]`, `add <text…>` / `add -` (stdin), `show [n]`, `rm <n>`, `edit [n]`, `clear [--yes]`, `menu [--if-stock]`, `path`, `help [raw]`, `raw <op>`. Owns every write: flock, in place, refuses invalid files, reads under a shared lock, keeps refused text in `<file>.rescue` | `scripts/hypr-notes`, `~/.local/bin/hypr-notes` (symlink; made by hand, install.sh does it from now on) |
| Shared data `~/.local/share/hypr-notes/notes.json` | `HYPR_NOTES_FILE` or `-f` overrides it |
| Service: watched FileView, write queue, flip debounce, 5 s undo, editor draft with 700 ms autosave and empty-sheet drop, flush, IPC target `notes` | `quickshell/Widgets/Services/NotesService.qml`, `notes-write.sh` (shim) |
| Card, 10th, 190×130 GUI px: paper sheet (perforated top, folded corner, red pin, fibres, pad behind), fade when long, `◀ 2/5 ▶`, wheel, age, `+`, hover ✕ with crumbs and Undo bar, empty state | `quickshell/Widgets/Notes/NotesCard.qml`, `PaperSheet.qml`, `PaperCrumbs.qml` |
| Edit layer, namespace `overworld-notes`, Exclusive keyboard, the same sheet over the card | `Notes/NotesEditor.qml`, `NotesForm.qml`, `NotesPlace.js` |
| Registration, layout | `WidgetsState.qml` (cardList), `WidgetLayout.qml`, `DesktopWidgets.qml`, `Projects/PixelGlyph.qml` (`left` glyph) |
| Chat `/note <text>` ("Note pinned."), `/note`, `/note list` | `Game/ChatService.qml`, `quotes/chat.json` |
| One modal at a time: the editor closes for and is closed by Game screens, the chat and the Projects dialog | `Game/GameUi.qml`, `NotesService.qml` |
| `overworld notes …` + `overworld help notes`; `qs_stop` flushes notes before it kills the shell | `scripts/overworld` |
| Keybind **SUPER+ALT+N** → `notes newSheet`; stock desktop → `hypr-notes menu --if-stock` | `hypr/keybinds.conf`, `hypr/off.conf` |
| install / uninstall (idempotent link; uninstall hands it to Apothecary's copy once that exists; never removes the data) | `scripts/install.sh`, `scripts/uninstall.sh` |
| Tests | `tests/hypr-notes.test.sh`, `tests/notes-quit.test.sh`, `tests/widgets-layout.test.js` (extended), `Widgets/preview/notes-test.qml`, `notes-chat-test.qml`, `notes-render.qml`, `notes-quit-test.qml`, `selftest.qml` (card count) |
| Docs | `docs/WIDGETS.md`, `README.md`, `docs/KEYBINDS.md`, `docs/GAMEPLAY.md`, `CHANGELOG.md` |

## Decisions
- **IPC verb is `newSheet`, not `new`.** The brief asked for `new`, but QML rejects a reserved word as a function name, even escaped (tested). `overworld notes new` maps to it.
- **`SUPER+ALT+N`**: free (`hyprctl binds -j`, JaKooLit Keybinds.conf). No `hyprctl reload` from me; Hyprland picked up the file by itself.
- **The sheet sits inside the usual panel** (like the Sign's board), so drag, title and hide work as on every card. Paper alpha follows `widgets.opacity` with a floor of 0.9 for readable ink.
- **Palette**: the paper item's own greys and face, warmed slightly, because the real item is near white and the brief wanted cream.
- **No wrap-around** when flipping; arrows grey out at the ends, like a book.
- **Numbering = file order, oldest first**, new sheets last, so the page counter equals `hypr-notes list`.
- **Blank drafts are never written.** Clearing a sheet changes nothing on disk until close, when it is dropped with Undo holding its last saved text.
- **If the same sheet changes under the editor**, text being typed wins over the outside write; with nothing typed the editor shows the new text. This is a choice between the two rules, recorded here on purpose.
- **Light dim, no gradient**: `#50101010` is under Hyprland's `ignore_alpha 0.35`, so the desk stays sharp and in view. No new layer rule needed (the `overworld-.*` catch-all gives no_anim).
- **No game events** for notes: their text has no business in `events.jsonl`. A typed `/note <text>` still lands in chat history and the `chat.command` event, like every command.
- **Crumbs**: small local component stepped at 20/s, honouring `reduced_motion` and `particles`.

## Independent review
A fresh read-only reviewer got the code and the requirements, and found 16 issues. All were real. Fixed, with regression tests:
- Refused writes silently lost text → `.rescue` file, one notification, draft stays dirty and retries.
- Undo of a blanked sheet restored the text from when it was opened → last saved text.
- A paste into a full note deleted the note's end → the paste is refused; the cap now counts characters, not UTF-16 units.
- `hypr-notes edit` lost the edit if the write failed → the temp file is kept and named; over-128 KB edits are cut, not an error.
- `overworld reload|off|repair` and shell reloads lost up to 700 ms of typing and the queue → IPC `flush` before the kill, a detached drain on destruction, and every op the service queues is now safe to repeat.
- IPC `remove` on an unsaved draft lost it → it gets an Undo.
- CLI reads saw half-written files (`edit` could open a blank sheet) → shared lock.
- Binary junk, `{}`, `{"todo":…}`, `{"sheets":false}` and concatenated documents were accepted → refused.
- Quick flip-back loaded stale text; pending flips were not flushed around drop and Undo, leaving the wrong `current`; double-click on ✕ counted twice; the Undo bar let clicks through to the pager; error messages printed the exit status; silent truncation now warns; two Exclusive overlays at once.
Left as designed: finding 16 (typing wins, see Decisions).

## Verified (and how)
- **CLI** `bash tests/hypr-notes.test.sh` → **214 passed, 0 failed**: every verb, stdin, numbering, cap, multi-line, special characters, 24 concurrent writers, no torn reads under a write storm, invalid-file refusal for 11 kinds of file, `.rescue`, inode kept, no-op writes leave the file alone, `$EDITOR`/`$VISUAL` incl. failing and argument-taking editors, the rofi menu via a scripted stand-in, `--if-stock`, the one-window lock.
- **Service** `preview/notes-test.qml` → **115 PASS, 0 FAIL**: add, flip debounce, external edit and CLI add live, tear-off and undo in place, autosave debounce timing, empty-sheet drop, Ctrl+N and flip logic, changes under the editor, cap, invalid file kept on screen, refused save retried, concurrent CLI + service writers, flush.
- **Real events, offscreen window only** `preview/notes-render.qml` `OW_RENDER_WHAT=act` → **34 PASS, 0 FAIL**, using QtTest's `TestEvent`: clicks on the sheet, ✕, Undo, `+`, ◀; hover; real wheel events; typing; Enter = newline; Ctrl+N; Ctrl+PgUp/PgDn; Ctrl+Enter; Esc; click outside; select-all + Delete; paste into a full note; emoji at the cap.
- **Chat** `preview/notes-chat-test.qml` → **15 PASS, 0 FAIL**.
- **Quit** `bash tests/notes-quit.test.sh` → **3 PASS**: draft and queue survive `Qt.quit`, `Quickshell.reload`, and IPC flush + SIGTERM.
- **Layout** `node tests/widgets-layout.test.js` → ok on 7 sizes, 10/10 placed at GUI 1 and 2, no overlaps, clear of HUD and boss bars, first 9 slots unchanged, editor placement cases.
- **Nothing else broke**: `projects-test` and `projects-chat-test` 0 failed, `hypr-projects.test.sh` 106 passed, `selftest.qml` no FAIL.
- **Renders**, Day and Night, viewed, in `qa/screenshots/` (gitignored): `sticky-notes-empty-*`, `-long-*` (fade), `-pager-*` (3/5 + hover ✕), `-undo-*`, `-edit-*` (text + cursor), `-editnew-*`, `-crumbs-dark`, `-layout-dark-gui2`, `-layout-light-gui2`, `-layout-dark-gui1`. Cyrillic and Kazakh render in Mojangles.
- **Live**: `qs -c overworld ipc call notes status|list|next|prev|undo|flush` answer; `widgets cards` lists `notes on`; `overworld notes list|show|next|prev|undo`, `help notes` work; `qs.log` has no line from any Notes file (other ERROR/WARN lines there are tray menu and `McSlider`, not from my files). `SUPER+ALT+N` is registered, `hyprctl configerrors` empty, `Hyprland --verify-config` ok.
- **Real-path smoke, final** (22:16:37): backed up, `add` → `list` → `rm <id>`; the live shell followed (2 sheets, then 1); file **byte-identical** to how I found it (`cmp`). See the incident above for the earlier, wrong one, and the open question for what happened to the pad afterwards.

## Not verified
- **The edit layer on a real output**: `NotesEditor` as a real `overworld-notes` layer (Exclusive keyboard, real focus, real placement over the card). It type-resolves up to `OverlayWindow`, which cannot load offscreen; `NotesForm` inside it was fully driven in a plain offscreen window; placement is unit-tested. **This is the first thing to try.**
- **Any real click or key on the desktop**, and the real `SUPER+ALT+N`. The user has evidently used the card and typed a note, which is encouraging but is not my test.
- **The Cyrillic layout fallback** (Ctrl+N/A/C/V/X/Z by physical key): the assumption that `nativeScanCode` is the xkb keycode could not be exercised offscreen.
- **`NotesEditor`'s own `onDestruction`** in the live shell: the mechanism is tested with an identical object in the quit test, because the editor needs a real backend.
- **`overworld reload|off|repair` flush** through `qs_stop`: not run (it restarts the shell); IPC flush + SIGTERM was tested in a private instance.
- The real rofi window, a real `notify-send` for a refused save, sounds (`book.page`, `ui.click`: code path only), `install.sh` / `uninstall.sh` (`bash -n` only, as they reload Hyprland), multi-monitor behaviour.

## Known limits
- The first note from the CLI into a missing file can take up to 4 s to appear (a missing file cannot be watched); after that under 0.1 s. Notes made on the card are immediate.
- Undo lives in the shell: `hypr-notes rm` cannot be undone.
- GUI 3 at 1080p has no slot for Notes (like the Sign and Projects); drag it there or use the keybind, and the editor opens centred.
- Two tear-offs in the same instant, before the file is read back, can restore in the wrong order. Not reachable by hand: a double click is ignored and clicks further apart see the fresh list.
- Saved card positions win over the layout, as for every card.

## Requests filed
One, to the orchestrator: the same bugs exist in `scripts/hypr-projects` (and `ProjectsCard`'s undo bar). Not changed, since that script must stay identical in both repos. See `docs/REQUESTS.md`.

## Please try (user)
1. Click the sheet on the **Notes** card (under Projects unless you moved it), type, press **Esc**. It should open right on top of the card and take your typing at once. **Report if the keyboard does not land there.**
2. **SUPER+ALT+N**: a blank sheet. **Enter** = new line, **Ctrl+N** = next blank sheet, **Ctrl+PgUp/PgDn** = flip, **Ctrl+Enter** / click outside / **Done** also close.
3. Switch to the Russian layout and try **Ctrl+N**, **Ctrl+V**, **Ctrl+Z** in the editor.
4. Hover the sheet, click **✕**: crumbs fall and **Undo** shows for 5 s. Scroll over the card to flip.
5. Chat: `/note buy coffee`, `/note list`, `/note`.
6. Terminal: `hypr-notes`, `echo "from a pipe" | hypr-notes add -`, `hypr-notes edit`, `hypr-notes show 1`, `overworld help notes`.
7. Stock desktop (both themes off): **SUPER+ALT+N** opens the rofi menu.

## For the Apothecary port
**The real pad is the user's, and they are using it right now: it may hold notes, and it can change while you work. In your final smoke select your test sheet by id, never by number, and never overwrite the file at the end: only compare, and if it differs, report it. I broke this once (see the incident).**

**Contract**
- Copy `scripts/hypr-notes` **byte-identical**, and symlink `~/.local/bin/hypr-notes` from both install.sh files. `hypr-notes help raw` lists the ops: `add`, `put <id> <text>`, `current <id>`, `remove <id>`, `insert <json> <index>`, `clear`, `read`. Everything goes through `-f <file> raw <op>`.
- Data: `{"sheets":[{"id","text","created","updated","color"?}],"current":id}`. Order = file order; a `current` that is missing or stale means the last sheet. Set `HYPR_NOTES_FILE` in tests, and `HYPR_NOTES_QUIET=1`, or a refused-write test **sends a real notification to the user's desktop**.
- IPC target `notes`: `open newSheet add next prev remove undo list status flush`, and use **`newSheet`** in the keybind, because QML forbids a function called `new`. Keep the same key: `bindd = SUPER ALT, N, Notes (stock desktop: rofi menu), exec, ~/.local/bin/hypr-notes menu --if-stock` in `hypr/off.conf` (identical line; the lock makes the pair open one window), and `unbind = SUPER ALT, N` before the theme's own bind.

**Files to mirror**
- `NotesService.qml` nearly as is; its theme-specific parts are only `ShellState`, `ProjectsService`, and the `qs -c overworld` text. Keep the draft logic: it took a review to get right, and `notes-test.qml` covers it (its GameUi part is Overworld-only).
- `NotesCard.qml` / `NotesForm.qml` / `PaperSheet.qml`: restyle these. Keep the handlers (`flipBy`, `wheelBy`, `tearOff`, `keyPressed`, `latinKey`, the cap code in `onTextChanged`, `load`) and `paperRect` → `setCardRect`. `NotesPlace.js` works as is.
- `NotesEditor.qml`: keep `Component.onDestruction: NotesService.flushNow()`.
- `scripts/apothecary`: call IPC `notes flush` before anything that kills the shell, as `qs_stop` does in `scripts/overworld`.
- `notes-render.qml`'s `act` mode and `notes-quit-test.qml` port directly and catch a lot.

**Gotchas I hit**
- `Array.from(string)` in this QML engine walks UTF-16 units; **`[...s]` walks real characters**. An emoji test caught it.
- A `Singleton`'s `Component.onDestruction` did not flush, and `Qt.application.aboutToQuit` does not fire: flush from an object in the normal tree. SIGTERM destroys nothing at all, hence IPC flush.
- A property named `top` on an Item fails with "Cannot override FINAL property". Property names cannot start upper case.
- A temp `HOME` hides `~/.local/share/fonts`, so renders silently fall back to a sans face: symlink the fonts dir into the temp home, or you judge the wrong font.
- `FileView.reload()` is not synchronous: in tests read a moment later.
- Overlays over translucent paper look wrong (bands turn brighter than the face); fade the text itself, in strips of falling opacity.
- `zsh` does not word-split `set -- $var`, and a shell heredoc delimited `EOF` ends at any inner `EOF` line.
- Apothecary's ink look may want its own `tone()` values; on a Cyrillic layout Qt reports Cyrillic key codes, so keep `latinKey`.
