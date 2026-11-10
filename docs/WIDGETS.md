# Desktop widgets (`quickshell/Widgets/`) — qs-widgets

The desktop widget layer: ten **Minecraft objects** on the wallpaper (layer `bottom`, namespace `overworld-widgets`,
click-through where empty). Every card is a `WidgetCard` = `Common/McPanel` (the real GUI panel with the dark-grey title,
centre filled at `Theme.widgetOpacity`, config `widgets.opacity`, default 0.72) + show/hide fade + drag handle. Everything is authored
in GUI px (`Theme.px`, default 2 × at 1920×1080) with the design system's text (`McText`), buttons, slots, progress bars and
sprites; nothing is re-implemented locally except the few widget-specific pieces listed under *Layout*.

Toggle with `widgets toggle` (SUPER+G); the bar chip menu (`Bar/WidgetsMenu.qml`, qs-core) switches single cards.
How the theme switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

## Layout (1920×1080; bar 0–36; the bottom-centre ~110 px stay free for the HUD)

```
quickshell/Widgets/
  DesktopWidgets.qml     Variants{Quickshell.screens} → PanelWindow per screen, WlrLayer.Bottom, anchors all edges,
                         exclusionMode Ignore, transparent, mask = union of the visible cards (+ full-screen while dragging)
  WidgetLayout.qml       the ten cards on their slots (an Item: also used by the offscreen render harness)
  WidgetCard.qml         McPanel + fade/rise 250 ms OutQuad (stagger 40 ms × index) + title-bar drag + double-click reset
  BlockPatch.qml         a square cut out of a block texture, 1 texel = 1 GUI px (weather columns, note-block cells)
  KeyedSprite.qml        sprite drawn additively in the game (sun / moon): black → transparent (shaders/blackkey.frag.qsb)
  Weather/  WeatherCard.qml  SkyWindow.qml        Music/  MusicCard.qml        Calendar/  CalendarCard.qml
  SysInfo/  SysInfoCard.qml                       Cava/   CavaCard.qml         Quote/     QuoteCard.qml
  BlockOfDay/  BlockOfDayCard.qml                 BrewTimer/  BrewTimerCard.qml
  Projects/  ProjectsCard.qml ProjectRow.qml ProjectBox.qml PixelGlyph.qml   ProjectsForm.qml ProjectsDialog.qml (the to-do card + its add/edit screen)
  Notes/  NotesCard.qml PaperSheet.qml PaperCrumbs.qml   NotesForm.qml NotesEditor.qml NotesPlace.js (the sticky-note card + the sheet you type on)
  Services/  (pragma Singleton, auto-registered, no qmldir)
    WidgetsConfig.qml   config.json view: sounds, reduced_motion, brew.{work,break}; stateDir / cacheDir / scriptDir   (was ApoConfig)
    WidgetsState.qml    visible (persisted), demo, positions, per-card switches, cardOpacity, IpcHandler "widgets"
    WeatherService.qml + weather-fetch.py    MusicService.qml (MPRIS)    SysInfoService.qml + sysinfo.py
    QuoteService.qml    BlockOfDayService.qml    BrewTimer.qml (IpcHandler "brew")    CavaService.qml    duration.js
    ProjectsService.qml (IpcHandler "projects") + projects-write.sh (shim → scripts/hypr-projects, which owns the rules)    the to-do list
    NotesService.qml (IpcHandler "notes") + notes-write.sh (shim → scripts/hypr-notes, which owns the rules)    the sticky notes
  assets/weather/*.png  gen_weather_icons.py    original 16×16 pixel icons (sun moon partly_day partly_night cloud fog rain snow sleet thunder)
  shaders/blackkey.frag(.qsb)    rebuild: /usr/lib64/qt6/bin/qsb --qt6 -o shaders/blackkey.frag.qsb shaders/blackkey.frag
  preview/  shell.qml (the layer) · render.qml (offscreen) · skies.qml (all sky conditions) · selftest.qml · shot.sh
            projects-test.qml · projects-chat-test.qml · projects-render.qml (Projects: logic, chat, offscreen renders)
            notes-test.qml · notes-chat-test.qml · notes-render.qml (Notes: logic, chat, offscreen renders + real key / mouse events)
```

| card | default slot (x y, px) | size (GUI px) | what it is |
|---|---|---|---|
| **Weather** | 24 60 | 190×150 | sky window + 24 h columns of blocks |
| **Jukebox** | 24 372 | 190×106 | MPRIS player as a jukebox, record, item frame, action bar, XP bar |
| **Brewing Stand** | 24 596 | 190×84 | the brew timer as the brewing GUI |
| **Block of the Day** | 24 776 | 190×138 | item frame + facts + tip (`quotes/blocks-of-the-day.json`) |
| **Clock & Calendar** | `w−404` 60 | 190×156 | the real clock item + "Day N" + month of slots |
| **System** | `w−404` 384 | 190×148 | F3 debug text + CPU/RAM/disk boss bars |
| **Note Block** | `w−404` 692 | 190×82 | cava equaliser built from note blocks / redstone lamps |
| **Sign** | `w−404` 868 | 190×78 | oak sign (`quotes/quotes.json`) + pulsing splash |
| **Projects** | `w−784` 80 | 190×150 | Book-and-Quill to-do list: In Progress / Built ✔, add · tick · remove with undo (see *Projects* below) |
| **Notes** | `w−784` 392 | 190×130 | a pad of Paper sheets for raw thoughts: click to write, flip, tear off with undo (see *Notes* below) |

`WidgetLayout` builds the slots as stacks in GUI px (left column 12 GUI px from the left edge, right column flush to 12 GUI px from
the right edge, first card at 30 GUI px, 6 GUI px between cards), so they follow the GUI scale (`gui_scale`) and the screen width; the
pixel numbers above are for 1920×1080 at GUI scale 2, where every card is 380 px wide. The left column ends at y 1052, the right at y
1024: the HUD area at the bottom centre stays free. Verified renders at GUI 2 and GUI 1 (`OW_GUI=1`).

The two stacks are full, so the ninth and tenth cards, **Projects** and **Notes**, are not part of them: `layout-plan.js` puts every card past the first 8 into an *overflow column* next to the right stack (then next to the left one), scanning down past the cards already there; a column that passes under the top centre starts 40 GUI px down (the boss bars), one that passes over the bottom centre ends above the hotbar. No room means `fits = false` like the others (GUI scale 3 at 1080p: the Sign, Projects and Notes have none; scale 1-2: 10 of 10).

## Cards

- **Weather → sky window.** `SkyWindow` is a framed window (oak planks) onto the sky at the weather's location: sky colour by
  condition and day/night, the **sun** (`environment/celestial/sun`) or the **moon with its real phase**
  (`environment/celestial/moon/<phase>`, synodic month from the 2000-01-06 new moon) travelling its arc by the *local* hour,
  drifting pixel clouds, the game's own `environment/rain` / `snow` textures falling in tick steps, lightning flashes for
  thunder, fog bands, stars on clear nights, a grass (snow-capped when snowing) strip. Right of it: the big temperature
  (`McText units: 3`), the condition with a pixel icon (`assets/weather/*.png`: sun, moon, partly cloudy day/night, cloud, fog,
  rain, snow, sleet, thunder — original art), Rain / Humidity / Wind, and below the window the **next 24 hours as stacked blocks**:
  column height = temperature (1–6 blocks), block = condition — *sand* clear day, *lapis* clear night, *sandstone* / *blue wool*
  partly cloudy, *light-grey wool* overcast, *smooth stone* fog, *water* rain, *snow block*, *packed ice* sleet, *gold block*
  thunder. Hover a column: `14:00 · 26° · Light rain · 40%`. Error state: "Weather unavailable" + Retry.
  Location: `config.json weather.{lat,lon,name}` → IP geolocation (ipapi.co, ip-api.com; rejected when its time-zone differs from
  `/etc/localtime`, i.e. a VPN exit) → Kowloon 22.3167, 114.1833. Refresh every 30 min; the cache is read synchronously at startup.
- **Music → Jukebox.** Jukebox block icon and a **spinning music disc** (a record picked from the track title, rotated in 7.5° steps
  on the 20 TPS clock while playing), the **album art in an item frame** (sampled down to 52×52 texels like a map), elapsed /
  length, **prev · play/pause · next** as small Minecraft buttons, the action-bar line **"Now Playing: Artist - Title" in the
  game's rainbow colour** (scrolls on the tick when too long) and an **XP-style progress bar** (click/drag to seek when the player
  allows it). Player: spotify first, else any playing player, else the first; `playerctld` ignored; position polled each second.
  Empty state: idle jukebox, "Nothing playing". Demo (`OW_WIDGETS_DEMO=1` / `widgets demo on`) shows a mocked track when no
  player exists. The buttons are wired to `MprisPlayer` but were never pressed during development (BRIEF §1.1).
- **Calendar → clock + map.** The real **`item/clock_00…63`** animation frames: frame 0 is noon, 32 midnight, chosen with the game's
  own celestial-angle formula `(2d + (0.5 − cos(πd)/2))/3`, `d = frac(dayTime/24000 − 0.25)`, `dayTime 0 = 06:00`; refreshed every
  10 s. "**Day N**" = day of the year, the time and the weekday, month arrows (click the month name = back to today), the month
  as a grid of inventory-style slots (Monday first), weekends in yellow like stack counts, **today inside the hotbar selection
  frame** (`hud/hotbar_selection`, nine-sliced with the 4 px border).
- **SysInfo → F3.** The fastfetch facts (name, user@host, OS, uptime, kernel, packages, shell + terminal, WM) as F3 text: white
  Minecraft text with the grey hard shadow on translucent `#90505050` rows, one 9 GUI px row per line, left aligned like the game;
  a grass block where the Maomao picture was; CPU, RAM and disk as **boss bars** (green < 70 %, yellow < 90 %, red above) with the
  value in the title. CPU from two `/proc/stat` samples, RAM `/proc/meminfo`, disk `/home` mount else `/`; bars refresh every 5 s only
  while the card is shown, static facts every 10 min (package count cached 10 min in `~/.cache/overworld/packages`).
- **Cava → note-block equaliser.** `~/.cache/overworld/cava.conf` is written at startup (raw, ascii 0–100, 24 bars, 30 fps) and
  `cava -p` runs **only while the card is shown** (layer visible *and* this card on). 24 columns × 7 rows of 6×6 GUI px block patches:
  low rows note blocks, upper rows lit redstone lamps, unlit cells dark; stacks fall a row per tick; each column's **peak is a
  note particle** (`particle/note`, tinted with the game's note colour for that pitch) that holds 8 ticks then sinks. ≈1.5 s of
  silence = dark grid + "Silence…"; "cava not running" if the binary fails.
- **Quote → sign + splash.** An oak sign: the real `entity/signs/oak` front face tiled at 1 texel = 1 GUI px, black sign lettering,
  message from `quotes/quotes.json` (attribution right-aligned), and the **yellow pulsing splash** (`McSplash`, the title screen's
  formula) on the card's top-right corner, text from `quotes/splashes.json` (seasonal entries only inside their date range, preferred
  there) **plus Mojang's `assets/mc/texts/splashes.txt` when that file exists** (read at runtime, one in four; never copied). Click the
  sign = next message + new splash; both rotate every 10 min.
- **Herb → Block / Mob of the day.** `BlockOfDayService` = `quotes/blocks-of-the-day.json` `entries[(dayOfYear + offset) % n]`, so the
  pick is deterministic by date (left click next, right click previous). Item frame with the texture (first animation frame, square
  crop; mobs show their spawn egg `item/<id>_spawn_egg`), name, kind (Block / Item / Mob / Biome), "Since <version>", the facts one
  at a time (rotate every 12 s, "Fact 1/3"), and the tip.
- **Brew → brewing stand.** Blaze-powder slot + fuel bar (`container/brewing_stand/fuel_length`, burns down with the phase), a well
  with the game's **bubbles** (heights 29/24/20/16/11/6/0, a step per 2 ticks while brewing) and the **arrow** filling downwards
  (`brew_progress`), the time (`mm:ss`, `h:mm:ss` from an hour), the summary line, Start/Pause/Resume + reset + pencil buttons, and
  three **bottle slots** (empty bottle → potion with glint as sessions complete, a stack count past three). Every BrewTimer feature
  is kept: any lengths (`25` · `50m` · `1h30` · `90s` · `1:30`, grammar `Services/duration.js`, mirrored by `brew_parse` in
  `scripts/overworld`), rest `0` = none, pencil / click the clock → brew dialog (`Brew/BrewDialog.qml`), scroll on the clock = brew
  ±1 min and on the "brew · rest" line = rest ±1 min (Shift ±5) while idle (saved after 700 ms through `overworld brew set`), sessions
  count, states `idle | working | breaking | paused`, finished brew rolls into the rest (or idle when rest is 0). On finish the
  sound id **`brew.done`** (brewing stand) or **`brew.drink`** (rest over) plays through `Theme.playSound` → `scripts/ow-sound`
  (silent when `config.json sounds:false`), `notify-send -a Overworld "Brewing complete" …`, and the events **`brew.start`**,
  **`brew.done`**, **`rest.done`** go on the bus (`GameEvents`, BRIEF §4.4).

## Projects (to-do card) — `Projects/`, `Services/ProjectsService.qml`

A **Book and Quill** to-do list for the user's own projects: what is *built*, what is *in progress*. Starts empty ("No projects yet",
with the quill icon and "Click +, or type /project add <name>"); nothing is ever pre-filled.

- **Card** (190×150 GUI px, same panel, translucency, title-bar drag, hide/show and stagger as the others). **In Progress** rows
  (unchecked, file order), then **Built ✔** (grey + struck through, newest first, the latest 5 then "+N more" / "Show less"; click the
  header to fold it). A row = the game's checkbox look (11 GUI px, green tick; the 20 px sprite is too big for a list row, so it is drawn in
  GUI pixels) · title, elided · a ✕ that appears while the row is hovered. Click the box = toggle (`xp.orb` when it becomes built,
  `ui.click` otherwise; silent when `sounds` is false). Hover a row (0.4 s) = the game's tooltip: full title, the note, "Added 6 Nov 2026",
  "Built … · took N days". Double-click a title = edit. The **+** in the title bar = add. Long lists scroll (wheel or `McScrollbar`).
- **Remove has no question but an undo**: ✕ removes the project and the card shows "Removed <title> [Undo]" for 5 s (also
  `/project undo`, `ipc call projects undo`); `Clear built` (chat/CLI) is undoable the same way. A removed-then-restored project comes back at
  its old place (it re-announces `project.add`).
- **Add / edit dialog** (`ProjectsDialog.qml` + `ProjectsForm.qml`, layer namespace `overworld-projects`, keyboard Exclusive like the brew
  dialog, because the widget layer itself never takes focus): Title (autofocus), optional Note, "Already built" checkbox, **Add** (Enter) /
  Cancel (Esc or a click outside). Editing adds Up / Down (reorder inside the section). The dialog sits in `DesktopWidgets.qml`
  (`DesktopWidgets` is a `Scope` now: the dialog + the per-screen layer `Variants`), and closes when any other overlay opens.
- **Data**: `~/.local/share/hypr-projects/projects.json` `{"items": [{"id", "title", "note"?, "status": "progress"|"built", "created": ISO-UTC,
  "built_at"?}]}` — **one list shared with Apothecary and the stock desktop** (a tick here shows in the other theme after a switch);
  created by the first add; the old `~/.config/overworld/projects.json` was migrated once (kept as `projects.json.bak`).
  `HYPR_PROJECTS_FILE=<file>` (or the older `OW_PROJECTS`) redirects it for tests. `ProjectsService` reads it with a watching
  `FileView` (an external edit shows at once; an unreadable or half-written file keeps the list on screen and is retried). **Every
  write is `scripts/hypr-projects raw <op>`** (via the shim `projects-write.sh <file> <op>`) — the jq rules are embedded in that
  script, under `flock`, written **in place** (`cat tmp > file`, never `mv`, the inode is watched) — and it is the same script
  `overworld projects` and `hypr-projects` run, so the card, the chat, the CLI and Apothecary's card cannot disagree or lose each
  other's writes (tested: 4 CLI + 2 service writers at once, nothing lost). A file that is not valid JSON is never overwritten.
- **Numbering** everywhere (chat `/project list`, `overworld projects list`, IPC `list`): in progress in file order, then built newest first
  (`built_at`, ties → later file entry first). `<n|title>` accepts that number, the id, or a title (exact, then prefix, then contains; more
  than one match → an error, never a guess).
- **Events** `project.add | project.built | project.remove {id, title}` are emitted from the diff of every reload, so each change announces
  itself exactly once whoever made it; the chat turns `project.built` into `Nurasik built [Title]!` (docs/GAMEPLAY.md).
- **Ways in**: the card · `SUPER+SHIFT+P` (add dialog) · chat `/project add|done|undone|toggle|remove|undo|list|edit` with Tab completion of titles
  · CLI `overworld projects [list|add <title> [--note t] [--built]|done <n>|undone <n>|toggle|rm <n>|clear [--yes]|open|edit <n>]`
  (works without the shell; `open`/`edit` need it) · IPC `qs -c overworld ipc call projects open | add <title> | toggle|done|undone|rm|remove|edit <n|title> | undo | list | status`.
- **Tests** (`bash tests/hypr-projects.test.sh`: 98 checks of the standalone CLI incl. the rofi menu logic; the rest all offscreen, temp `OW_PROJECTS`, private `OW_EVENTS_DIR`): `preview/projects-test.qml` (service: add / toggle / rename / reorder / remove /
  undo / clearBuilt / external edit / concurrent writers / invalid file, 44 checks), `preview/projects-chat-test.qml` (chat: 26 checks),
  `preview/projects-render.qml` (`OW_RENDER_WHAT=card|undo|dialog|edit|act`, `OW_RENDER_PIN=<row>` draws a hovered row, `OW_RENDER_TIP=1` its
  tooltip, `OW_RENDER_FOLD=1`, `OW_RENDER_ALL=1`), `node tests/widgets-layout.test.js` (9 cards, overflow column, boss-bar clearance).

## Notes (sticky notes) — `Notes/`, `Services/NotesService.qml`

A pad of **Paper** sheets for dumping raw, stray thoughts: no titles, no structure, no checkboxes (those are the Projects card's job). Open, type, it is saved. Starts empty ("Click to scribble a thought…"); it never invents notes.

- **Card** (190×130 GUI px, same panel, title-bar drag, hide/show and stagger as the others). `PaperSheet` draws one sheet in GUI pixels from the paper item's palette, warmed a little towards cream: a perforated top edge, a folded corner, a red pin, faint fibres (the same for a given sheet), up to two sheets of the pad peeking out behind it; Night dims it as if by moonlight. The paper's alpha follows `widgets.opacity` with a floor of 0.9 so the ink stays readable. Text is the Minecraft font in dark ink with no shadow, wrapped; a long note fades out in four chunky steps (the same text in strips of falling opacity). Footer: `◀ 2/5 ▶`, the age ("3 min ago", follows `updated`), `+`. The **mouse wheel** anywhere on the card flips (120 units a notch; touchpad steps add up). There is no wrap-around: the arrows grey out on the first and last sheet.
- **Tear-off**: hover the sheet, **✕** removes it with no question, paper crumbs fall (stepped at 20 per second, none with `reduced_motion` or particles `minimal`, half with `decreased`) and the card offers "Tore off … [Undo]" for 5 s (also IPC `notes undo`, `overworld notes undo`). Tear-offs inside those 5 s pile up; Undo restores all of them at their places.
- **Editor** (`NotesEditor.qml` + `NotesForm.qml`, layer namespace `overworld-notes`, keyboard Exclusive, because the widget layer never takes focus): a click on the sheet opens **the same sheet, slightly larger (216×150 GUI px), exactly over the card** (`NotesPlace.js`: centred on the paper, kept on screen, on the GUI grid; the card publishes where its paper is through `NotesService.cardRects`; card hidden or without a slot = the middle of the screen). A light dim (alpha under Hyprland's `ignore_alpha 0.35`, so no blur) keeps the desk in view. "Page 2 of 5" in the corner like the book screen, a blinking `_` at the end of the text (a thin bar inside it), Done underneath.
  - **Enter** = new line · **Esc / Ctrl+Enter / a click outside / Done** = save and close · **Ctrl+N** = new sheet · **Ctrl+PgUp / PgDn** = flip. Ctrl+N/A/C/V/X/Z also work on a Cyrillic layout (physical key).
  - **Autosave**: 700 ms after the last keystroke, and on every flip and close. A blank draft is never written; **an empty sheet is dropped on close or on flipping away**. A sheet that had text and was emptied gets the 5 s Undo with its last saved text. Up to 4000 characters a sheet (the count shows in the last 200; when full, what was just typed or pasted is refused, the end of the note stays). A shell reload or `overworld reload|off|repair` mid-typing writes the draft and the queue on its way out (detached).
  - If the sheet changes under the editor: with nothing typed since the last save the editor shows the new text; with typing, the typing wins; torn off elsewhere, the editor moves on to the current sheet and does not bring it back.
- **Data**: `~/.local/share/hypr-notes/notes.json` `{"sheets": [{"id", "text", "created": ISO-UTC, "updated": ISO-UTC, "color"?}], "current": id}` — **one pad shared with Apothecary and the stock desktop**; created by the first note. `HYPR_NOTES_FILE=<file>` redirects it for tests. Reading is a watching `FileView`; a missing file cannot be watched, so while the pad is missing or empty it is polled every 4 s (the very first note from the CLI can take that long to appear, later ones under 0.1 s). **Every write is `scripts/hypr-notes raw <op>`** under `flock`, in place (`cat tmp > file`, never `mv`); a write that changes nothing does not touch the file; a file that is not valid JSON, or not one object with a `sheets` array, is never overwritten: the text of a refused write is appended to `notes.json.rescue` instead, one notification says so, and an open draft stays unsaved so the next save retries. CLI reads take the lock shared, so they never see a half-written file. The flip is the one thing shown before it is written (`currentId`; written 400 ms later so the wheel does not write per notch).
- **Numbering** everywhere (page counter, `hypr-notes list`, `/note list`, IPC `list`): file order, oldest first; a new sheet goes last and becomes current. `current` missing or stale = the last sheet.
- **Ways in**: the card · `SUPER+ALT+N` (a blank sheet) · chat `/note <text>` ("Note pinned."), bare `/note` (the editor), `/note list` · CLI `hypr-notes` and `overworld notes [list|add <text>|add -|show [n]|rm <n>|edit [n]|clear [--yes]|open|new|next|prev|undo]` (`open new next prev undo` need the shell; the rest do not) · IPC `qs -c overworld ipc call notes open | newSheet | add <text> | next | prev | remove | undo | list | status | flush`. (`new` is a reserved word in QML, so the IPC function is `newSheet`; `overworld notes new` maps to it.)
- **Sounds**: `book.page` on a flip and a tear-off (from the card and the editor, not from IPC), `ui.click` on buttons. No game events: a note's text has no business on the event bus.
- **Tests** (all offscreen, temp file): `bash tests/hypr-notes.test.sh` (the CLI: every verb, stdin, numbering, cap, concurrent writers, invalid files, `$EDITOR`, the rofi menu with a scripted stand-in), `preview/notes-test.qml` (service), `preview/notes-chat-test.qml` (chat), `preview/notes-render.qml` (`OW_RENDER_WHAT=card|undo|edit`, `OW_RENDER_PIN=1` draws the ✕, `OW_RENDER_NEW=1`, `OW_RENDER_LATE=<ms>`; `act` sends real key and mouse events to its own offscreen window through QtTest's `TestEvent`), `bash tests/notes-quit.test.sh` (typing and the write queue survive a quit, a reload, and IPC flush + SIGTERM), `node tests/widgets-layout.test.js` (10 cards, overflow column, where the editor lands).

## Now Playing PiP — `quickshell/NowPlaying/` (an overlay, not a desk card)

The floating mini-player with the video lives in its own module and layer (`overworld-nowplaying`, Overlay), not on the
widget layer: it floats above windows. Its row in the widgets menu sits under the cards and is **not** part of "All widgets"
or the chip's middle-click; its on/off is `~/.config/overworld/nowplaying.json` (starts off). Everything about it —
the Zen bridge, the shared `hypr-nowplaying` daemon, privacy, config, sync, tests — is in [NOWPLAYING.md](NOWPLAYING.md).
For a logged-in **TikTok** tab its hover controls also have **like / repost / save-to-collection** toggles (bridge 1.3.0;
un-saving un-favourites the clip, which removes it from every collection; config `nowplaying.tiktokCollection`, default
`"Edits"`): see [NOWPLAYING.md → TikTok](NOWPLAYING.md#tiktok-like-repost-save-to-a-collection).

## IPC

```
qs -c overworld ipc call widgets toggle | reveal | hide      # persisted in ~/.config/overworld/widgets-visible
#   (NB `widgets show` is swallowed by the qs CLI — `show` collides with `qs ipc show` — so the alias is `reveal`)
qs -c overworld ipc call widgets demo on|off                 # mocked track on the Jukebox when no player exists
qs -c overworld ipc call widgets status                      # "visible (demo)"
qs -c overworld ipc call widgets layout                      # every card back on its slot
qs -c overworld ipc call widgets card <weather|music|calendar|sysinfo|cava|quote|block|brew|projects|notes>    # toggle one (`herb` = alias of block)
qs -c overworld ipc call widgets cards | menu
qs -c overworld ipc call brew start 50m | startWith 50m 10m | toggle | pause | reset | add 5m | open | sound brew|rest | status | settings
# CLI: overworld brew help   (`-p <preview dir>` instead of `-c overworld` for the preview instance)
```

## State, caches, config

| path | what |
|---|---|
| `~/.config/overworld/widgets-visible` | `true` / `false`, read at startup, written by reveal/hide/toggle |
| `~/.config/overworld/widgets-hidden.json` | list of switched-off card ids |
| `~/.local/share/hypr-projects/projects.json` | the Projects card's list, shared with Apothecary and the stock desktop (see *Projects*); `projects.json.lock` is the flock file next to it |
| `~/.local/share/hypr-notes/notes.json` | the Notes card's sheets, shared with Apothecary and the stock desktop (see *Notes*); `notes.json.lock` is the flock file next to it, `notes.json.rescue` (only after a refused write) holds text that could not be saved |
| `~/.config/overworld/widget-positions.json` | `{cardId: [x, y]}` for dragged cards |
| `~/.config/overworld/config.json` | `widgets.opacity`, `weather.{lat,lon,name}`, `brew.{work,break}`, `sounds`, `reduced_motion`, `gui_scale` |
| `~/.cache/overworld/weather.json` | last good forecast + location (Open-Meteo JSON, `stale: true` when served from cache) |
| `~/.cache/overworld/weather-now.json` | **for fx-world:** `{"kind": "clear|cloudy|fog|rain|thunder|snow", "code": <WMO>, "is_day": bool, "temp": °C, "precip_mm": mm, "wind": km/h, "city": str, "stale": bool, "updated": epoch}`, rewritten by `weather-fetch.py` after every fetch (startup, every 30 min, Retry) |
| `~/.cache/overworld/packages`, `cava.conf` | package count text (10 min) · generated cava config |

In-process consumers (fx-world runs inside the same `qs` instance) may read `WeatherService.kind`, `.code`, `.isDay`, `.temp`
after `import qs.Widgets.Services`; the file above is for anything outside QML. Kind mapping: 95/96/99 thunder · 71–77, 85, 86 snow ·
51–67, 80–82 rain · 45/48 fog · 2/3 cloudy · else clear.

## Behaviour of the engine (kept from Apothecary)

- **Click-through.** The PanelWindow `mask` is a `Region` whose children are `Region { item: <card> }` for every visible card (null
  while the layer or the card is hidden). Outside the rectangles the desktop receives everything; inside, cards get hover/click.
- **Dragging.** Grab a card's title bar (the top 17 GUI px). While a drag is active `WidgetsState.dragging` adds a full-screen region
  to the mask, so a fast flick cannot leave the card's input region. Position is saved on release; **double-click the title bar** =
  back to the slot; IPC `widgets layout` resets all.
- **Opacity.** Only the panel's centre fill is translucent (`Theme.widgetOpacity`, live from `config.json`); bevels, text, icons
  stay opaque.
- **Costs when hidden.** cava is stopped, sysinfo polling stops, tick clocks (`McTicker`) release, the weather/quote/block timers are
  slow (30 min / 10 min / 12 s while visible).
- **Reduced motion** (`config reduced_motion`, Options "animations" off): fades are instant, the sky/disc/marquee/bubbles/splash stop on
  their first frame.

## Running the preview (never touches the live shell)

```
source scripts/dev-env.sh
OW_MODE=light qs -p quickshell/Widgets/preview                    # the layer itself (dark for Night); OW_WIDGETS_DEMO=1 mocked track
quickshell/Widgets/preview/shot.sh <name> [light|dark] [region]   # start it, scripts/dev-shot.sh → qa/screenshots/qs-widgets-<name>.png, stop it
qs -p quickshell/Widgets/preview/skies.qml                        # every sky condition in a grid
# offscreen, no compositor at all (software renderer: no ShaderEffects, i.e. no sun/moon/note particles/water tint):
OW_RENDER_OUT=/tmp/x.png OW_RENDER_BG=<wallpaper.png> OW_MODE=dark OW_WIDGETS_DEMO=1 QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/render.qml
# logic self-test (throw-away HOME; see the header of selftest.qml)
```

Preview-only env pins (no effect unless set): `OW_WIDGETS_OPACITY` (card fill; the live desktop's own cards would shine through a
0.72 fill in screenshots), `OW_WIDGETS_LAYER=top` (a `bottom` layer is covered by other agents' test windows), `OW_WIDGETS_DEMO`,
plus the design system's `OW_MODE`, `OW_GUI`, `OW_REDUCED_MOTION`.

Known harmless log lines: `quickshell.dbus.properties … playerctld … NoActivePlayer` (Quickshell's Mpris probing the playerctld
bus) and `kf.iconthemes: Icon theme … not found` (Qt platform theme).

### Projects on the stock desktop and in Apothecary
The same list is the **Projects** card of Apothecary (工程, with a vermilion seal 成 on built items) and, with both themes off, the rofi menu
`hypr-projects menu` on `SUPER+SHIFT+P` (bound in `hypr/off.conf`; `--if-stock` makes it a no-op while a theme is on). `hypr-projects`
(`scripts/hypr-projects`, linked to `~/.local/bin` by install.sh) is the CLI that owns every write; `overworld projects …` delegates to it.

### Notes on the stock desktop
With both themes off, `SUPER+ALT+N` opens `hypr-notes menu` (rofi; bound in `hypr/off.conf`; `--if-stock` makes it a no-op while a theme is on): "+ New note…" asks for a line, Enter on a sheet shows it (with "✕ Tear off this note"), "✕ Remove…" tears one off, Esc closes. `hypr-notes` (`scripts/hypr-notes`, linked to `~/.local/bin` by install.sh) is the CLI that owns every write; `overworld notes …` delegates to it.
