# sticky-notes-apothecary (follow-up) — the sticky-note widget for the Apothecary theme

Prerequisite: the `sticky-notes` agent just built the Overworld version + the shared data file
(`~/.local/share/hypr-notes/notes.json`) and the shared CLI `scripts/hypr-notes`. Read
`docs/agent-reports/sticky-notes.md` (especially "for the Apothecary port"), the Overworld card/service/edit layer,
and `docs/agent-reports/projects-everywhere.md` (how Projects was ported to Apothecary — same pattern).

Target repo: **`~/Projects/apothecary-hyprland`** (its own git repo; you may edit it). Read its BRIEF.md,
docs/WIDGETS.md, docs/DESIGN.md, `quickshell/Widgets/Projects/` (the Projects 工程 card: PaperPanel / TitleBar with
seal, ink style, dialog with keyboard focus, ProjectsService), `quickshell/Brew/` dialog, `scripts/apothecary`,
`hypr/keybinds.conf`, `hypr/off.conf`, `hypr/decorations.conf`, `scripts/install.sh`, `tokens/`.
Do not change the Overworld repo except: copy `scripts/hypr-notes` byte-identical into Apothecary's `scripts/` (both
install.sh files symlink `~/.local/bin/hypr-notes`; keep the two copies identical) and fix a real bug in it if you
find one (then in both copies, and note it).

## THE USER IS AT THE DESK (hard rules)
No grim/dev-shot, no workspace switching, no on-screen previews/windows/rofi, no theme switching
(`overworld|apothecary on|off|light|dark`), no sound, no git commits, no sudo, no input injection. Apothecary's shell is
NOT running (Overworld is live) — validate with an offscreen harness that symlinks its Common/Services/Widgets dirs
(`QT_QPA_PLATFORM=offscreen`, grabToImage of a child Item → PNG, Read it). Tests use a temp `HYPR_NOTES_FILE`; the
real file only in the final smoke (back it up, diff, leave it as found).

## Build
1. **Card** "Notes · <CJK>" in Apothecary's style — Maomao's scribbled memos: a slip of washi / herb-paper pinned to
   the desk (a needle or a small paper clip / string tie), ink text, faint paper fibre texture, a vermilion seal
   in the title bar like the other cards. Pick the CJK label (e.g. 覚書 / 手記 / 雑記 / 札) and VERIFY every glyph in the
   font you use: `fc-list ":family=<F>:charset=<hex>"` (the Chinese brush fonts lack Japanese-only kanji — see
   DESIGN.md). Body text in a readable face (not the brush font). Same features as Overworld's: pad of sheets,
   page counter, ◀ ▶ + wheel, `+`, tear-off ✕ with undo, relative time, fade when long, empty-state hint, drag/hide/
   positions, widgets-menu entry, opacity like its other cards, light AND dark modes. Respect its layout system so
   nothing overlaps at default positions.
2. **Edit layer** (namespace `apothecary-notes`, Exclusive keyboard like its Brew/Projects dialog) drawn as the same
   paper slip over the card's position, multi-line, Enter newline, Esc / Ctrl+Enter / click outside / Done (or a 記
   seal button) = save + close, Ctrl+N new, Ctrl+PgUp/PgDn flip, ~700 ms debounced autosave, empty sheets dropped.
   Layer rule in `hypr/decorations.conf` if its catch-all doesn't already cover it.
3. **Service** NotesService (watched shared file, writes via hypr-notes, IPC target `notes` with the same verbs as
   Overworld's: open new add next prev remove undo list status). Sounds: its brush/paper or wood-block cue on tear-off
   if one exists (code path only — never play sound).
4. **CLI/keys**: `apothecary notes …` delegating to hypr-notes + help page; the same keybind Overworld chose →
   `notes new` in its ON keybinds and → `hypr-notes menu --if-stock` in its `hypr/off.conf` (identical line to
   Overworld's off.conf; the menu's lock prevents double windows); `scripts/install.sh` symlink (+ uninstall.sh).
5. **Verify**: offscreen renders light + dark, all viewed: empty card, long note with fade, pager + hover ✕, undo
   bar, edit layer with text. Service test against a temp file. `bash -n` scripts; `hyprctl configerrors` stays
   empty (no reload needed for Apothecary since it is off). Overworld still loads clean (`~/.cache/overworld/qs.log`).
   Real smoke as above.
6. **Docs** in the Apothecary repo: WIDGETS.md, README, KEYBINDS.md, CHANGELOG.md, QUICKSHELL.md if it lists
   services/IPC.

Report in `~/Projects/overworld-hyprland/docs/agent-reports/sticky-notes-apothecary.md` (changed files per repo,
decisions incl. the CJK label + glyph check, verified / not verified, "please try" list).
