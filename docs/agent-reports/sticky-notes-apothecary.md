# sticky-notes-apothecary report — the Notes card (札记) in the Apothecary theme

Done 2026-11-06, about 22:50 HKT. No dev-shot, no grim, no workspace switch, no on-screen window or rofi, no theme switch, no sound, no commits, no sudo, no input injection into the desktop. Apothecary's shell was not run (Overworld is live). Visual checks are offscreen renders, all viewed. Design details: `~/Projects/apothecary-hyprland/docs/WIDGETS.md` → *Notes*.

## Still open: the user's note is not on the pad
The previous agent's open question stands. **The pad was empty when this run started and is empty now, and "Finish the note taking widget in apothecary theme." is not on it.** I did not restore it, because it may have been torn off on purpose, and I found nothing new about what removed it (see `sticky-notes.md`). This port is what that note asked for, so it may no longer be wanted. To put it back: `hypr-notes add "Finish the note taking widget in apothecary theme."`
One lead the previous agent did not have: a slow double click on the ✕ tears off a second sheet (measured on Apothecary's card before the fix; Overworld has the same service guard, not run there; request filed, below). That cannot explain a pad holding one note, but it is the same control.

## Changed files
**`~/Projects/apothecary-hyprland` (uncommitted)**
| what | where |
|---|---|
| Card, 10th, 254×244 at x 1166 y 812 | `quickshell/Widgets/Notes/NotesCard.qml`, `WashiSlip.qml`, `PaperScraps.qml` (new) |
| Edit layer, namespace `apothecary-notes` | `Notes/NotesEditor.qml`, `NotesForm.qml`, `NotesPlace.js` (new) |
| Service, IPC target `notes`: `open newSheet add next prev remove undo list status flush` | `Widgets/Services/NotesService.qml` (new) |
| Shared CLI, byte-identical with Overworld's | `scripts/hypr-notes` (new) |
| Registration | `Widgets/DesktopWidgets.qml`, `Widgets/Services/WidgetsState.qml`, `Services/ShellState.qml` (`notes` modal), `shell.qml` |
| `apothecary notes …` + help page; `qs_stop` flushes first | `scripts/apothecary` |
| `SUPER+ALT+N`, stock menu, layer rule | `hypr/keybinds.conf`, `hypr/off.conf`, `hypr/decorations.conf` |
| Symlink; uninstall hands it to Overworld's copy and never removes the data | `scripts/install.sh`, `scripts/uninstall.sh` |
| Tests | `tests/notes-quit.test.sh`, `tests/notes-layout.test.js`, `quickshell/Widgets/preview/notes-test.qml`, `notes-render.qml`, `notes-quit-test.qml` |
| Docs | `docs/WIDGETS.md`, `README.md`, `docs/KEYBINDS.md`, `CHANGELOG.md`, `docs/QUICKSHELL.md`, `docs/DESIGN.md`, `docs/INSTALL.md` |

**`~/Projects/overworld-hyprland`:** code unchanged. Only this report and one entry in `docs/REQUESTS.md`. `scripts/hypr-notes` had no bug that needed fixing.

## Decisions
- **Label 札记** (*zhájì*, jottings; 札 is also the slip they are written on), seal **记** ("to record"), Latin subtitle NOTES as DESIGN.md requires. Glyph check with `tokens/check-glyphs.sh` (`fc-list ":family=…:charset=…"`): **札 and 记 are OK in ZCOOL XiaoWei and Ma Shan Zheng**. 覚書, 雑 and 箋 are MISSING from both, so the Japanese spelling was ruled out.
- **Body face LXGW WenKai** (DESIGN.md's role for notes), not the brush font. Checked with `fc-list`: it covers Latin, Russian, the Kazakh letters ә ғ қ ң ө ұ ү һ і, and CJK. Rendered in `notes-pager-*`.
- **The slip**: herb-paper with deckled edges, faint kozo fibres and flecks of leaf, stitched with a silver needle (Maomao's poison test) and a vermilion thread. It is drawn on a Canvas from a per-sheet seed, so a sheet always looks the same.
- **Night is the same paper by lamplight, with dark ink**, not a lacquer slip. It reads as an object on the dark card. Paper alpha follows `widgets.opacity` with a floor of 0.9, as in Overworld.
- **Slot x 1166–1420, y 812–1056**: the other free slot under the art zone, 16 px from Herb and from Quote, same bottom edge as Projects. Also clear of the user's saved Apothecary positions (by arithmetic).
- **`ShellState.notesOpen`** instead of Overworld's separate wiring, so the editor is one modal among the others: any other modal or `shell closeAll` saves and closes it. This is the main difference from Overworld's service; the draft logic is otherwise unchanged.
- **Writes go straight to `Theme.repoDir/scripts/hypr-notes`**, as `ProjectsService` does, with no shim file.
- **Layer rule `animation fade`, not `popin` like Projects.** A pop-in scales toward the screen centre, which would slide the slip off the card it opens over.
- **Editor controls on a paper strip**: over a busy wallpaper they were hard to read (seen in the light render, also raised by the review).
- **Tear-off cue `seal`**, the soft thud: the theme has no paper sound. Code path only. No cue on flip.
- **IPC verb `newSheet`**: QML forbids a function called `new`. `apothecary notes new` maps to it.

## Independent review
A fresh read-only reviewer got the code and requirements, and found five items.
- **Fixed: the editor's Canvas may go blank after reopening**, because an unmapped layer window can take the picture with it. This rests on the reviewer's memory of the Qt sources and **cannot be reproduced offscreen**, so the fix (repaint on open and once mapped) is harmless but **unconfirmed**.
- **Fixed: the slip re-rolled its torn edge and page counter during the close fade.** My first fix failed its own new test (a `Binding` re-evaluates before its `when` turns false), so it became an explicit hold.
- **Fixed: a double click on ✕ tore off two sheets.** The service guard holds only until the file is read back. Regression test added, and checked both ways: with the new guard disabled, clicks 250 ms apart left 2 of 4 sheets and the test failed; restored, it passes.
- **Fixed: controls on the scrim** (the strip above).
- **Filed, not changed: `overworld on` kills Apothecary's shell without a flush** (`scripts/overworld:292`, confirmed by reading it).
- **Known limit, documented:** the default slot overlaps Herb below 1888 px wide.
- **Walked and correct:** SUPER+ALT+N in all four on/off combinations of the two themes. With both on, Overworld's shell gets the key.
- **Noticed, not touched:** `Notifications/NoteCard.qml:68` is also a Canvas inside an `OverlayWindow`, so its fold may have the same blank-after-reopen problem.

## Verified (and how)
All tests ran against temp files with a temp HOME and `sounds: false`. The last full run was after every fix.
- **Service** `preview/notes-test.qml` → **116 PASS, 0 FAIL**: Overworld's full suite ported, plus the `ShellState` paths.
- **Real events on an offscreen window** `notes-render.qml` `APO_RENDER_WHAT=act` → **45 PASS, 0 FAIL**: clicks on slip, ✕, Undo, +, ◀ ▶, the 记 seal; hover; real wheel events on the slip and the card padding; typing; Enter = newline; Ctrl+N; Ctrl+PgUp/PgDn; Ctrl+Enter; Esc; click outside; select-all + Delete; paste into a full note; emoji at the cap; double click; held slip on close; sounds off.
- **Quit** `bash tests/notes-quit.test.sh` → **3 PASS**: draft and queue survive `Qt.quit`, `Quickshell.reload`, and IPC flush + SIGTERM.
- **Layout** `node tests/notes-layout.test.js` → **0 failed**: real slots parsed from the QML at 1920×1080, 1920×1200, 2560×1440, 3840×2160: no two cards overlap; at 1920×1080 Notes is clear of the art zone; editor placement cases.
- **CLI** Overworld's `tests/hypr-notes.test.sh` → **214 passed, 0 failed**. `cmp` confirms both copies are identical. Rofi was never opened (the suite uses a scripted stand-in).
- **Nothing else broke**: `projects-test.qml` 47 PASS, 0 FAIL.
- **`apothecary notes`**: help, add, list, show, rm, path, unknown verb; open/new/next/prev/undo answer "the shell is not running". `bash -n` on all scripts.
- **Types**: `NotesEditor` and `DesktopWidgets` resolve up to the expected "No PanelWindow backend loaded", the same limit as `BrewDialog`.
- **Config**: `Hyprland --verify-config` on `decorations.conf` + `keybinds.conf` + both `off.conf` → config ok. `hyprctl configerrors` empty. Both `off.conf` files carry the identical line.
- **Overworld still clean**: live shell answers `notes status`, `qs.log` has no line from a Notes file. On the live session `SUPER+ALT+N` still runs only `notes newSheet`.
- **Real-path smoke** (run twice): backed up, added a uniquely worded sheet with Apothecary's copy, removed it **by id**, only compared. The live Overworld shell followed (1 sheet, then none); `apothecary notes list` showed it; an Apothecary render reached it through the default path; `menu --if-stock` returned at once with no rofi. Pad **byte-identical** to before both times. The first run's render was invalid: my env line pointed the harness at a temp dir, and the empty card gave it away, so I fixed that and reran. The user's live card showed a test note for a few seconds, twice.

**Renders**, light and dark, viewed, in `~/Projects/apothecary-hyprland/qa/screenshots/` (gitignored, they contain the wallpaper): `notes-empty-*`, `notes-long-*` (fade), `notes-pager-*` (2/3 + hover ✕, Cyrillic and Kazakh), `notes-undo-*`, `notes-edit-*`, `notes-editlong-*`, `notes-editnew-*`, `notes-layout-*` (full desktop at the default slots; Cava drawn as a placeholder, Music in demo mode), `notes-one-light`, `notes-flip-light2dark` (live mode flip repaints), `notes-realpath-dark` (the real pad through the default path).

## Not verified
- **The editor as a real `apothecary-notes` layer**: Exclusive keyboard, real focus, real placement over the card, the fade, and the Canvas surviving a reopen. `NotesForm` inside it was fully driven in a plain offscreen window; placement is unit-tested. **First thing to try.**
- **The card on the real `bottom` layer**: the mask region, drag, hide, the bar's Desk widgets row (it reads `cardList`, so it should appear by itself).
- **`apothecary reload|off` flush through `qs_stop`**: not run, as it would restart the shell. IPC flush + SIGTERM was tested in a private instance.
- The real `SUPER+ALT+N`, the Cyrillic layout fallback (`nativeScanCode`), the real rofi window, a real `notify-send` for a refused save, sounds, `install.sh` / `uninstall.sh` (`bash -n` only; the symlink still points at Overworld's copy, which is identical). The mode cross-fade was seen only at its end state.
- Editing `hypr/off.conf` may have triggered Hyprland's auto-reload on the live session (Apothecary's off.conf is sourced even while it is off). No config errors followed; I did not reload anything myself.

## Known limits
- The default slot overlaps Herb below 1888 px wide (drag it; a saved position wins). Apothecary's layout is not designed for those sizes anyway.
- Undo lives in the shell: `hypr-notes rm` cannot be undone.
- The first note from the CLI into a missing file can take up to 4 s to appear (a missing file cannot be watched).

## Requests filed
One entry in `docs/REQUESTS.md`, to the orchestrator: flush before `apothecary_down`'s `pkill` in `scripts/overworld`, and the double-click ✕ fix for Overworld's card.

## Please try (user)
Turn Apothecary on first (`apothecary on`, or `apothecary dark|light`).
1. The **札记 Notes** card is at the bottom, between Herb and Quote. Click the slip, type, press **Esc**. It should open right over the card and take your typing at once. **Report if the keyboard does not land there.**
2. Press Esc, then open it again and **check that the needle and the paper are still drawn**. This is the unconfirmed fix.
3. **SUPER+ALT+N**: a blank slip. **Enter** = new line, **Ctrl+N** = next blank slip, **Ctrl+PgUp/PgDn** = flip; **Ctrl+Enter**, a click outside, or the **记 Done** seal also close.
4. Switch to the Russian layout and try **Ctrl+N**, **Ctrl+V**, **Ctrl+Z** in the editor.
5. Hover the slip, click **✕**: scraps fall and **Undo** shows for 5 s. Scroll over the card to flip. Drag it by the title bar. Toggle it in the bar's Desk widgets menu.
6. Write a note, then switch to Overworld: the same note is on its card.
7. Terminal: `apothecary notes`, `apothecary notes add "a thought"`, `apothecary help`.
8. Stock desktop (both themes off): **SUPER+ALT+N** opens the rofi menu, and only one window.
