# projects-everywhere report — the Projects to-do in Apothecary and the stock desktop, one shared list

Done 2026-11-06 ~11:30 HKT. User at the desk: no `dev-shot.sh`, no workspace switch, no on-screen window / rofi window, no theme switch, no sound
(every test ran with a temp HOME whose `config.json` has `"sounds": false`), no commits, no sudo. All visual checks are **offscreen renders**
(`QT_QPA_PLATFORM=offscreen qs -p …`, `grabToImage` → PNG), all viewed. Overworld is live and hot-reloaded each save (`~/.cache/overworld/qs.log` checked:
"Configuration Loaded", no new QML error; the only ERROR lines in it are the older half-written `DesktopWidgets.qml` save of `projects-widget`).

## Delivered

### Shared pieces
| what | where |
|---|---|
| **`hypr-projects`** standalone CLI (identical copy in both repos; `~/.local/bin/hypr-projects` → symlink): `list [--json]`, `add <title…> [--note N] [--built]`, `done|undone|toggle|rm <n\|title-prefix>`, `rename`, `clear [--yes]`, `menu [--if-stock]`, `summary [--print]`, `path`, `help [raw]`, and `raw <op>` (the low-level ops the QML services call). The jq rules are embedded; every write = `flock` + read-modify-write **in place** (`cat tmp > file`, never `mv`); an invalid JSON file is never overwritten. | `overworld-hyprland/scripts/hypr-projects`, `apothecary-hyprland/scripts/hypr-projects` |
| Shared data path `~/.local/share/hypr-projects/projects.json` (same schema; `HYPR_PROJECTS_FILE` / `-f` overrides). **Migration**: the first run copies the old `~/.config/overworld/projects.json` over when the new file does not exist (byte-for-byte, then keeps the old as `projects.json.bak`). Done for the user's real list (3 built projects, unchanged). | in `hypr-projects` (`migrate`) |
| Test suite (every verb, prefix matching, numbering, concurrent writes, invalid JSON, inode kept, migration ×5, `menu` loop driven by a scripted stand-in for rofi, `--if-stock`, lock) | `overworld-hyprland/tests/hypr-projects.test.sh` — **106 PASS / 0 FAIL** |
| install / uninstall: `~/.local/bin/hypr-projects` symlink (idempotent); uninstall hands the link to the other theme and never touches the list | both repos' `scripts/install.sh`, `scripts/uninstall.sh` |

### Overworld (this repo) — changed files
`scripts/hypr-projects` (new), `tests/hypr-projects.test.sh` (new), `scripts/overworld` (`overworld projects …` now delegates to `hypr-projects`; `open`/`edit` stay IPC; `rename` added), `quickshell/Widgets/Services/ProjectsService.qml` (new path, slow poll while the file is missing/empty so the other theme / CLI creating it shows up), `quickshell/Widgets/Services/projects-write.sh` (now a 4-line shim → `hypr-projects raw`), `quickshell/Widgets/Services/projects.jq` (deleted: the rules live in the script), `hypr/keybinds.conf` (`unbind SUPER SHIFT, P` before its bind), `hypr/off.conf` (the stock-desktop bind), `scripts/install.sh`, `scripts/uninstall.sh`, `docs/WIDGETS.md`, `docs/GAMEPLAY.md`, `docs/KEYBINDS.md`, `README.md`. Sound stays `xp.orb`.

### Apothecary (`~/Projects/apothecary-hyprland`, its own repo, **uncommitted**) — changed files
| what | where |
|---|---|
| Card "**工程 · PROJECTS**" (400×244): **PaperPanel** + lacquer title bar with seal 印; sections **在制 In progress** / **已成 Built**; paper-note rows (hairline slip, jade frame on hover); **ink checkbox** (brush tick that draws itself in); built rows struck through + a **vermilion seal 成** stamped at the right (presses in with a small overshoot and spin; none under `reduced_motion`); note + "built 6 Nov" in small muted type under the title; hover ✕ + 5 s **Undo** slip; Built fold + latest 5 / "+N more"; scrolling with a thin scroll indicator; empty state (big vermilion 工 + "Add a project"); **Add** button in the header; double-click a title = edit | `quickshell/Widgets/Projects/{ProjectsCard,ProjectRow,InkCheck}.qml` |
| Add / edit dialog, namespace `apothecary-projects`, an `OverlayWindow` like `BrewDialog` (scrim, Exclusive keyboard): Title (autofocus) · Note · "Already built" · Add/Save = Enter · Esc/click outside cancel · Tab next field · editing: Up/Down buttons and ↑/↓ in the title reorder inside the section | `Widgets/Projects/{ProjectsForm,ProjectsDialog}.qml`, `Services/ShellState.qml` (`projectsOpen`, so it is one modal at a time like brew) |
| `ProjectsService` singleton (watching `FileView`, write queue → `scripts/hypr-projects raw`, undo, `find`, IPC target **`projects`**: `open add toggle done undone remove rm edit undo list status`) | `Widgets/Services/ProjectsService.qml` |
| 9th card registered at the free slot **x 340, y 812 (by(812))** with a mask region + stagger index 8; in the widgets menu (`WidgetsState.cardList`, so the bar's Desk widgets menu lists it by itself, `widgets card projects`) | `Widgets/DesktopWidgets.qml`, `Widgets/Services/WidgetsState.qml`, `shell.qml` |
| `apothecary projects [list\|add\|done\|undone\|toggle\|rm\|rename\|clear\|open\|edit\|help]` (delegates to `hypr-projects`; `open`/`edit` via IPC) | `scripts/apothecary` |
| keybind `SUPER+SHIFT+P` → `projects open` (+ `unbind` first); layer rule for `apothecary-projects` (blur, popin like brew); `hypr/off.conf` stock bind | `hypr/keybinds.conf`, `hypr/decorations.conf`, `hypr/off.conf` |
| Sounds: `seal.wav` on becoming built (nothing on un-build/remove: there is no other cue in `assets/sounds` worth reusing; `SoundService` honours `sounds:false`) | `ProjectsCard.toggleItem` |
| Docs | `docs/WIDGETS.md` (new *Projects* section + IPC + file tree + slot table), `docs/KEYBINDS.md`, `docs/QUICKSHELL.md`, `docs/DESIGN.md` §7 table, `docs/INSTALL.md`, `README.md`, `CHANGELOG.md` |
| Tests / harnesses | `quickshell/Widgets/preview/projects-test.qml` (service), `projects-render.qml` (`APO_RENDER_WHAT=card\|undo\|dialog\|edit\|act\|form`), symlink `preview/Services ⇒ ../../Services` |

### Stock desktop (both themes off)
`hypr-projects menu` — a **rofi** menu: `+ Add project…` (row 0, asks for a title with a second `rofi -dmenu` prompt), one `☐ title` / `☑ title` row per project (in progress first, then built; the note after "  —  "), Enter toggles and keeps the cursor on that row, `✕ Remove…` opens a pick-to-delete submenu (only shown when there is something to remove); loops until Esc. `hypr-projects summary` sends a `notify-send` ("Projects · 3 in progress · 2 built" + the open ones; `--print` for a terminal). No waybar module (skipped as asked).
**Keybind `SUPER+SHIFT+P`**: free on JaKooLit (`hyprctl binds -j`: only `SUPER+P` pseudotile and `CTRL+ALT+P` wlogout; grep of Keybinds.conf / UserKeybinds.conf: nothing). Bound as `bindd = SUPER SHIFT, P, …, exec, ~/.local/bin/hypr-projects menu --if-stock` in **both** `hypr/off.conf` files (identical lines). Two safeguards make that harmless: `--if-stock` does nothing while either theme's `enabled` flag exists (each theme's ON keybinds `unbind` that key and bind its own dialog; Overworld's/Apothecary's off.conf is sourced even while the *other* theme is on), and the menu takes `flock -n` on `$XDG_RUNTIME_DIR/hypr-projects-menu.lock`, so the pair of identical binds when both themes are off, or key repeat, opens one window.

## Verified (and how)
- `bash tests/hypr-projects.test.sh` → **106 passed, 0 failed** (against a temp dir; the real file is never touched). `bash -n` on `hypr-projects`, `scripts/overworld`, `scripts/apothecary`, both `install.sh` / `uninstall.sh`.
- **Menu logic without a window**: a scripted stand-in for rofi (`HYPR_PROJECTS_ROFI`) feeds answers: toggle by row, add with a typed title (whitespace collapsed), Esc in the title prompt, empty title, remove submenu, empty list (only the add row, nothing written), `--if-stock` is a no-op with Overworld on / Apothecary on and runs with both off, a second menu while one holds the lock exits without touching rofi. The real `rofi` was only asked `rofi -version`, `rofi -h` (every option used — `-dmenu -format -selected-row -mesg -no-custom -p -i -l` — exists in 2.0.0; `-format i` = original index per `rofi-dmenu(5)`) and `rofi -dump-config`. **No rofi window was opened.**
- **Apothecary service** `projects-test.qml` (temp HOME + file) → **47 PASS / 0 FAIL** (same cases as Overworld's: missing file → empty and not created, adds with blank refused, whitespace, built split/order, toggle both ways, rename, move within a section, remove + undo to the same place, external edit seen by the watcher, 4 CLI + 2 service writers at once = 10 items nothing lost, half-written/invalid file keeps the list then recovers, find by number/prefix/ambiguous/none, clearBuilt + undo, two removes piling into one Undo, `justBuilt`, IPC-style `act`, signals once).
- **Apothecary card handlers** `APO_RENDER_WHAT=act` → 10 PASS (box click → built and the `seal` cue was asked for, again → back, no cue; ✕ removes + Undo slip; Undo restores; "+N more"; Add button path sets `ShellState.projectsOpen`; edit path sets `editId`; sounds are off in the run).
- **Apothecary form** `APO_RENDER_WHAT=form` → 9 PASS (starts empty with focus in the title; Enter on empty = refused + flagged; accept adds a built project with collapsed whitespace; editId loads the fields; Tab Title→Note→Title; save renames, drops the note, un-builds; ↑ moves the project inside its section).
- **Renders** (software, real fonts, wallpaper behind, opacity 0.72), light + dark, all viewed — `~/Projects/apothecary-hyprland/qa/screenshots/` (gitignored: wallpaper): `projects-card-dark.png` (4 in progress, scrolled), `projects-card-light.png` (hovered row with ✕), `projects-user-dark.png` (1 in progress + 3 built with the 成 seals, hover on a built row), `projects-realdata-dark.png` (the user's real list read through the **default shared path** with a temp HOME), `projects-empty-light.png`, `projects-undo-dark.png`, `projects-dialog-dark.png`, `projects-edit-light.png`. Overworld reading the shared data: `overworld-hyprland/qa/screenshots/projects-everywhere-overworld-shared.png`.
- **Layout**: arithmetic over the 9 default slots (the formulas of `DesktopWidgets.qml`) — no overlap with any other card at 1920×1080, 2560×1440, 1920×1200; stays outside the art zone (x 520–1420 y 180–780); bottom edge 1056 = DESIGN's bottom margin (1080−24). At 1600×900 and 1366×768 it overlaps the centred Herb card (Apothecary's own layout is already not designed for those): drag it, the saved position wins.
- **Overworld still fine** (live): shell hot-reloaded each save with no new error; `qs -c overworld ipc call projects status` reads the shared file ("0 in progress, 3 built"); `overworld projects list|help` work; Overworld's own suites re-run green: `projects-test.qml` **0 failed**, `projects-chat-test.qml` **0 failed**, `node tests/widgets-layout.test.js` ok on all sizes.
- **Hyprland config**: `Hyprland --verify-config -c <temp conf>` → "config ok" for (a) both `off.conf` files, (b) Apothecary `keybinds.conf` + `decorations.conf` + both off.conf, (c) Overworld `keybinds.conf` + `decorations.conf` + both off.conf. `hyprctl configerrors` empty (see the final line below for the post-reload result).
- **Real-path smoke** (live Overworld shell watching the file): `hypr-projects add "Test"` → `list` (IPC `1 in progress, 3 built`) → `done Test` (`0 in progress, 4 built`) → `rm Test` (`0 in progress, 3 built`) → the real file is **content-identical** (`jq -S` diff against `~/.hermes/cache/scratch/projects-everywhere/original.json`, taken before any work; sha256 of the original `a7bc7f05…`). `hypr-projects menu --if-stock` with Overworld on: returns at once, no rofi process.

## Independent review (a fresh read-only subagent) and what I did about it
It found no bug in the bind logic (all four on/off combinations walked: the key fires exactly one thing) and 11 smaller issues, all confirmed and fixed:
- **script**: backslashes in titles shown doubled (`@tsv`) → own tab join; a whitespace-only file silently dropped an add → treated as empty + an empty result is never written; an item without a string title made `done` print a false success → such items are dropped on normalisation (the shells already hide them) and `resolve` dies on an empty answer; the menu read the file twice per loop (a race between the rows and the row count) → one read; after "+ Add project…" the cursor now lands on the new project; `rename` read the note outside the lock and could revert a concurrent note edit → new `retitle` op; `theme_on` honours `XDG_CONFIG_HOME`. New tests for each (+8).
- **Apothecary dialog**: a click on the panel's title bar / padding closed the dialog (the `MouseArea` sat in the padded content item; the old `BrewDialog` has the same latent pattern, not touched) → a `MouseArea` over the whole panel; a project removed by the CLI / other theme while it was being edited turned Enter into an *add* → the dialog now closes; Up/Down for built projects did nothing visible (built ones sort by built-at) → hidden for them (Overworld's form too).
- **both services**: every reload rebuilt all rows (hover, a pending double-click and animations lost; our own write comes back as a reload) → an unchanged list is ignored; two removes within the 5 s window overwrote the first undo → they pile up and one Undo restores both (last first); the legacy-file migration only ran on the first write → the service runs `migrate` once at start. Apothecary: the seal now **presses down** when its row appears because the project just became built (`ProjectsService.justBuilt`, set before the rows are rebuilt).

## Not verified
- **Apothecary's shell was not run** (it is OFF; running `qs -c apothecary` would take over the desktop): the dialog as a real layer (`apothecary-projects`: scrim, Exclusive keyboard, real key input), the card on the real `bottom` layer with the real mask / drag, the bar's Desk-widgets menu row, `SUPER+SHIFT+P` really pressed, hot-load of `shell.qml`. What was done instead: every component (card, rows, form) instantiated in an offscreen window against the real Theme/PaperPanel/InkField; `ProjectsDialog.qml`, `DesktopWidgets.qml` and the edited singletons load and resolve their types (the offscreen loader stops only at "No PanelWindow backend loaded", the same as for the existing `BrewDialog`); the dialog wrapper is a copy of `BrewDialog`'s pattern.
- Real pointer / keyboard input on either theme (no input injection while the user is at the desk); the actual rofi window (look and feel under the user's rofi theme, `-selected-row`, `-mesg` rendering) and a real `notify-send` from `summary`.
- Sound: code path only (`SoundService.play("seal")` returns false with `sounds:false`; Apothecary's real config currently has `"sounds": true`).
- `hyprctl reload` effect on the live desktop (see below).
- Install scripts were `bash -n`-checked and the symlink was made by hand (`ln -sfn`), not by running `install.sh` (it reloads Hyprland, runs apps/ installers).

## Known limits
- Apothecary's default slot assumes ≥ ~1700 px width (see Layout above). The card has no tooltip (the note and built date are shown inline instead; `InkButton.tooltip` in Apothecary is accessibility-only).
- Undo lives in the shell that did the remove: the CLI and the rofi menu cannot undo (the rofi remove list asks nothing but is a deliberate pick; Esc backs out).
- Both repos carry a copy of `scripts/hypr-projects` (identical now; the theme repos are separate git repos, so there is no single shared file). Whoever last ran `install.sh` owns `~/.local/bin/hypr-projects`.
- Fold state of Built / "+N more" is per shell run. Titles are collapsed to single spaces; the dialog caps title 120 / note 240 characters.
- The Apothecary service does not feed a game event bus (it has none); Overworld's still emits `project.*` events.

## Requests filed
none.

## Please try (user)
**Any theme / terminal**
1. `hypr-projects` · `hypr-projects add "Hyprland rice" --note "waybar part left"` · `hypr-projects done 1` · `hypr-projects rm rice` · `hypr-projects summary`. The Overworld card (live) follows every command within ~0.1 s.
2. `apothecary projects help` / `overworld projects help` print the same verbs; both edit the same file.

**Overworld (now, nothing changes visually)**
3. Tick a project on the card, then look at `hypr-projects list`: the same list. The old file is `~/.config/overworld/projects.json.bak`.

**Apothecary** (`apothecary on`, or `apothecary dark|light`)
4. The **工程 Projects** card sits under the art zone between the Brew timer and the Herb card. **Add** (or `SUPER+SHIFT+P`) → type a name, Enter. Click a checkbox → the ink tick draws in and a vermilion **成** seal is stamped on the row (and the seal cue plays). Hover a row → ✕ → remove → **Undo** within 5 s. Double-click a title → edit (↑/↓ move it). Click **已成 Built** to fold it.
5. Switch theme (Overworld ↔ Apothecary) and check that a built project stays built.
6. The bar's Desk widgets menu (󰕮) has a **Projects** switch; `qs -c apothecary ipc call projects list`.

**Stock desktop** (`overworld off` / `apothecary off`, both off)
7. `SUPER+SHIFT+P` → rofi menu: Enter on a row toggles it (☐ ↔ ☑), `+ Add project…` asks for a title, `✕ Remove…` deletes one, Esc closes. Pressing the key again while it is open does nothing extra.
