# How Overworld works (a guide for learning it)

This guide is for someone who can program but is new to Hyprland, Quickshell, QML and bash. It starts with the big picture,
follows one key press all the way to the screen, then shows how to add the four things you are most likely to add: a chat
command, an advancement, a widget card and a sound. Last comes debugging.

Every file and line reference below was read from the repo when this was written. Line numbers drift as files change; the
function names next to them are the stable part, so search for those if a line is off.

Words you will meet:

- **Hyprland**: the Wayland compositor. It draws windows, handles keys, and reads plain-text config files.
- **Quickshell (`qs`)**: a program that runs a QML file and turns it into desktop surfaces (bar, menus, overlays). Our whole HUD is one Quickshell config.
- **QML**: a declarative UI language. You describe objects and their properties; when a property they depend on changes, they update on their own ("bindings"). JavaScript goes inside for logic.
- **IPC**: a way for another process (the shell's `qs ipc call`) to run a function inside the running shell.
- **Layer surface**: how a shell draws on the desktop. Each of our surfaces has a *namespace* (for example `overworld-bar`) which Hyprland rules can match.

---

## 1. The layer stack

From the bottom (closest to the machine) to the top (closest to your eyes):

```
 you press a key
   │
 Hyprland                          compositor; reads ~/.config/hypr/hyprland.conf
   │
 hypr/*.conf                       our layer: on.conf sources decorations, animations, rules, keybinds
   │                               (hypr/ in this repo; linked in through ~/.config/hypr/overworld.conf)
   │
 scripts/ (bash)                   `overworld` CLI, kill.sh, ow-sound, make-world.sh ...: glue with side effects
   │                               Hyprland binds run these as plain commands
   │
 Quickshell config                 quickshell/shell.qml: the one entry file, `qs -c overworld`
   │
   ├─ Common/                      design-system components: McPanel, McButton, McSlot, McText, Theme.qml (the Theme singleton)
   ├─ Bar/ Launcher/ Notifications/ Network/ Power/ Wallpapers/ Osd/ Brew/ Widgets/     "modules" = screens you can see
   ├─ Game/ World/ Interact/       game logic: chat/advancements, weather/day cycle, mining/placing
   └─ Services/                    singletons holding state: ConfigService, SystemStats, HyprlandState, SoundService ...
         │
 GameEvents (event bus)            Services/GameEvents.qml: any part says "window.kill happened", any other part may listen
         │
 ~/.config/overworld/*, $XDG_RUNTIME_DIR/overworld/events.jsonl      state files
```

How the pieces connect, one at a time:

1. **Hyprland → `hypr/*.conf`.** `scripts/install.sh` puts one `source = ~/.config/hypr/overworld.conf` line in your `hyprland.conf`. That file
   sources `~/.config/overworld/active.conf`, a symlink that points either at `hypr/off.conf` (empty) or `hypr/on.conf` (the theme).
   `hypr/on.conf` then sources the colours for the current mode and the four layer files:
   `decorations.conf` (borders, blur, shadow, layer rules), `animations.conf`, `rules.conf` (window rules), `keybinds.conf`.
   Flipping the symlink and running `hyprctl reload` is the entire "theme on/off" for Hyprland. See `hypr/on.conf`.
2. **Hyprland → scripts.** A keybind is just a line that runs a command. `hypr/keybinds.conf` defines `$ow = $HOME/.local/bin/overworld` and
   `$qs = qs -c overworld ipc call`, and most binds are `bindd = SUPER, X, Description, exec, $qs <target> <function>`.
3. **Scripts → Quickshell.** `scripts/overworld` (the CLI) does the side effects bash is good at (files, `hyprctl`, other programs) and
   calls into the shell with `qs_ipc` (`scripts/overworld:187`).
4. **Quickshell config.** `quickshell/shell.qml` imports every module and instantiates it (`Bar {}`, `Launcher {}`, ... `GameSystems {}`,
   `WorldFx {}`, `Interactions {}`). Each module owns its own `IpcHandler`s. Directories become QML modules named `qs.<Dir>`
   (`import qs.Common`, `import qs.Services`).
5. **Common → modules → services.** Modules draw with Common components and read state from Services singletons.
   `Theme.qml` is the one place that knows colours, the GUI scale (`Theme.gui`, default 2) and how to find a texture (`Theme.tex("gui/sprites/hud/heart/full")`).
   Common deliberately does not import Services (see `docs/agent-reports/design-director.md`), so it stays previewable on its own.
6. **Event bus.** `Services/GameEvents.qml` is how unrelated modules talk. Emit with `GameEvents.emit("window.kill", {cls: "kitty"})`;
   listen with a `Connections { target: GameEvents; function onEvent(name, data) {...} }`. The same bus is reachable from bash:
   `overworld event <name> '<json>'`. Every event is one JSON line in `$XDG_RUNTIME_DIR/overworld/events.jsonl`, and listeners hear
   it only through a `tail -F` of that file (the `tail` process, `GameEvents.qml:46-48`), so an event is seen exactly once whoever sent it.

Two ideas to hold on to: **bash does side effects, QML does pixels**, and **modules never call each other directly: they use Services, IPC or events.**

---

## 2. Trace: pressing SUPER+Q until the window breaks

The only way to be sure how something works is to follow it. Here is the whole path of a window close (bash → Hyprland → QML → Hyprland again).

### Step 1: Hyprland sees the key

`hypr/keybinds.conf:29` first removes JaKooLit's own meaning of the key: `unbind = SUPER, Q  # killactive`. Without that line both
binds would fire. Line 66 defines ours:

```
bindd = SUPER, Q, Mine the window (block-break close), exec, $ow kill
```

`bindd` = a bind with a description; `exec` runs a command, here `~/.local/bin/overworld kill` (`$ow`, line 10).

### Step 2: the CLI hands over to a script

`~/.local/bin/overworld` is a symlink to `scripts/overworld`. At its bottom a `case` dispatches the verb (`scripts/overworld:1069`:
`kill) shift; cmd_kill "$@"`), and `cmd_kill` (line 557) is a one-liner that `exec`s `scripts/interact/kill.sh`.

### Step 3: `kill.sh` asks the shell, with a safety net

`scripts/interact/kill.sh:13`:

```bash
timeout 1.5 qs -c overworld ipc call interact kill >/dev/null 2>&1 && exit 0
exec hyprctl dispatch killactive >/dev/null
```

It asks the running shell to do the animated close. If the shell is not running (or does not answer within 1.5 s) the second line
closes the window the plain way, so SUPER+Q always works. `qs ipc call interact kill` means: target `interact`, function `kill`.

### Step 4: IPC arrives in QML

`quickshell/Interact/Interactions.qml:63-65`:

```qml
IpcHandler {
    target: "interact"
    function kill(): void { minerFx.kill("", ""); }
```

`minerFx` is the `Miner { id: minerFx }` instantiated at line 31. Quickshell calls the function inside the shell process.

### Step 5: `Miner.kill` asks Hyprland which window

`quickshell/Interact/Miner.qml:54`, `function kill(address, cls)`. It sets `phase = "query"`, starts a watchdog timer (nothing may
hold the overlay forever), and runs `hyprctl -j activewindow` through a `Process` item (line 61). The JSON comes back in
`_queried` (line 87), which stores the window's address, class, title, rectangle and workspace in `target`. It also chooses a
*material* from the class: `InteractFx.materialFor(cls, title)` (line 106), looked up in `Interact/materials.json` (kitty and
other terminals are metal, file managers and editors wood, ...; the default is stone).

If reduced motion is on, the game mode is adventure or spectator, or the window is not on the visible workspace, it skips the animation (`_instant`, line 109).

### Step 6: the colours of the window

`phase = "capture"`: `scripts/interact/capture-palette.sh` is run with the window's rectangle (line 111). It grabs the pixels with `grim`
in memory and prints a few hex colours; `Miner` collects those lines (line 120). These become the break particles later.

### Step 7: cracks, one stage per tick

`_startMining` (line 130) adds a `"mine"` effect to `InteractFx` (line 135) and plays `block.hit.<material>`. A `McTicker` item
(line 142) fires every tick (50 ms; Minecraft runs at 20 ticks per second). Each tick `_step` (line 146) goes to the next of
10 crack stages with `InteractFx.setStage`. On screen, `Interact/FxLayer.qml` is a transparent overlay surface (namespace
`overworld-break`) and `Interact/MineOverlay.qml` tiles the game's own texture `block/destroy_stage_<n>` exactly over the window's rectangle (line 15).
`_step` also aborts if you move focus to another window (the `viaActive` check, line 148).

On the last frame (line 156) it emits `GameEvents.emit("window.kill", {cls, title})`: this is the hand-off to the rest of the game (step 9).

### Step 8: break, particles, and the real close

`_finish` (line 160) removes the crack overlay, plays `block.break.<material>`, and dispatches the actual close:

```qml
Hyprland.dispatch("closewindow address:" + t.address);
```

It only ever closes that one address, never "the active window". It then adds a `"burst"` effect: 30-60 fragments in the sampled colours falling for about 0.6 s.

### Step 9: everything else that cares

`window.kill` went through `GameEvents`, so other modules react without `Miner` knowing about them:

- `Game/Stats.qml:90` listens; `record` (line 28 maps the name) increments `windowsMined`, and per-app mined counts (line 55).
- `Game/Advancements.qml:251` listens and feeds the event to the engine. `quotes/advancements.json` has "Monster Hunter" (`window.kill`, count 1)
  and "Monsters Hunted" (count 100), so you unlock them from your first and hundredth SUPER+Q, and a toast pops up.
- `Game/ChatService.qml:481` prints "Killed <title>" into the chat log.

That is the full path: **key → Hyprland bind → CLI → script → IPC → QML → Hyprland dispatch**, with an event bus on the side.
For the opposite direction (opening a window = placing a block), read `Interact/Placer.qml`, which listens to Hyprland's `openwindow` event.

---

## 3. Recipes

All of these edit files in the repo; the shell hot-reloads QML when a file changes. If it does not, run `overworld reload`.

### 3.1 Add a chat command

Commands have two halves: the *text* (help, usage, tab completion) in `quotes/chat.json`, and the *behaviour* in `Game/ChatService.qml`.

1. **Declare it.** Either add an entry to `help.commands` in `quotes/chat.json`, or (for quick experiments) add one to the `extraCommands` object in
   `ChatService.qml` (around line 40; `seed` and `clear` are there). An entry looks like:

   ```json
   { "name": "f3", "usage": "/f3 [on|off]", "description": "Toggles the debug screen.",
     "args": [ { "name": "state", "type": "choice", "choices": ["on", "off"] } ] }
   ```

   `args` drive Tab completion. Types: `choice`, `duration`, `workspace`, `app`, `text`, `command` (schema in `quotes/README.md`).
2. **Add a `case`** in the `switch (name)` of `run(body)` (`ChatService.qml:227-255`):

   ```qml
   case "f3": return cmdF3(a, spec);
   ```

   `a` is the list of words after the command; `rest` is the raw text after it.
3. **Write the function.** `cmdF3` (line 383) is a good model: validate, do the thing, print a result line.

   ```qml
   function cmdF3(a, spec) {
       const v = (a[0] || "toggle").toLowerCase();
       if (["on", "off", "toggle"].indexOf(v) < 0) { error(GameCore.t("errors.unknown_option", { value: a[0] })); return; }
       GameCore.ipc("world", "f3", [v]);          // call another module's IPC target
       ok(GameCore.t(v === "off" ? "ok.f3_off" : "ok.f3_on"));
   }
   ```

   Output helpers: `ok(text)`, `error(text)` (red), `system(text)` (grey), `post(text, color)`. Texts for success lines live under `ok` in
   `chat.json` (so you can translate or reword them without touching code); `GameCore.t("ok.f3_on", {placeholder: value})` looks them up.
4. **Test it** without opening the console: `overworld chat /yourcommand arg`.

If the command should also be a CLI verb, add it to `scripts/overworld` (a `cmd_<name>` function, a line in the final `case`, a `help_page` entry).

### 3.2 Add an advancement

Advancements are data only: add an object to `quotes/advancements.json` (schema in `quotes/README.md`):

```json
{
  "id": "adventure/hunted", "tab": "adventure", "parent": "adventure/hunter", "frame": "challenge",
  "title": "Monsters Hunted", "description": "Mine 100 windows.", "icon": "diamond_sword",
  "trigger": { "event": "window.kill", "count": 100 }
}
```

- `parent` places it in the tree (each tab has exactly one root with `parent: null`).
- `frame` is `task`, `goal` or `challenge`; `icon` is an item or block name from the game's textures.
- `trigger.event` is any event name on the bus (the list is in `BRIEF.md` §4.4, for example `window.open`, `workspace`, `brew.done`,
  `net.connect`, `xp.levelup`, `screenshot`). `count` is a lifetime total. `condition` can filter on the event data, e.g.
  `{"where": {"cls": "kitty"}}`, a `distinct` field (count distinct workspaces), or a `time` window (`"02:00"` to `"05:00"` for night-owl).
5. Validate: `python3 quotes/check.py` (checks JSON, the tree, textures and event names).
6. Try it: fake the event from bash: `overworld event window.kill '{"cls":"kitty"}'` (this really counts toward your statistics, so use a
   throwaway id while testing, or do it in a preview shell).

To make a *new kind* of event, emit it where the thing happens (`GameEvents.emit("my.event", {...})` in QML, or `overworld event my.event '{...}'` in a
script) and use it as `trigger.event`.

### 3.3 Add a widget card

A card is one QML file extending `WidgetCard`, plus three registrations. Copy `Widgets/Quote/QuoteCard.qml` (small) as a template.

1. **The card.** `Widgets/MyThing/MyThingCard.qml`:

   ```qml
   import QtQuick
   import qs.Common
   import qs.Widgets
   import qs.Widgets.Services

   WidgetCard {
       title: "My Thing"
       guiW: 190          // size in GUI pixels (multiply by Theme.gui to get screen pixels)
       guiH: 78
       McText { anchors.centerIn: parent; text: "hello" }
   }
   ```

   Lay content out with `Theme.px(n)` (n GUI pixels) and the `Mc*` components, never raw pixel sizes, so it follows the GUI scale.
2. **Instantiate it** in `Widgets/WidgetLayout.qml`: add `property alias mything: mything`, add it to the `cards` array (reading order = stagger order),
   and add a line like the others:

   ```qml
   MyThingCard { id: mything; index: 8; cardId: "mything"; defaultX: root.slots[8].x; defaultY: root.slots[8].y; fits: root.slots[8].fits }
   ```
3. **Register it** in `cardList` in `Widgets/Services/WidgetsState.qml` (about line 78): `{ id: "mything", cjk: "M", item: "chest", name: "My Thing" }` so the bar's widgets menu can toggle it.
4. **Click-through.** In `Widgets/DesktopWidgets.qml` add a line to the `mask: Region { ... }` block for your card, otherwise clicks on it fall through to the desktop.
5. Data: if the card needs a service (a command's output, a file), make a singleton in `Widgets/Services/` like `QuoteService.qml`.

Note `docs/WIDGETS.md` describes the layout planner (`layout-plan.js`) that places cards in columns, and how to preview a card alone.

### 3.4 Add a sound

All sounds go through `scripts/ow-sound <id>`, which reads `tokens/sounds.json`:

```json
"ui.click": { "files": ["mc:random/click"], "fallback": ["gen:click"], "volume": 0.5, "category": "ui", "desc": "button / slot click" }
```

- `files`: `mc:<path>` means `assets/mc/sounds/<path>.ogg` (Mojang's, fetched). Several files = a random variant per play.
- `fallback`: `gen:<name>` means `assets/gen/sounds/<name>.wav` (our own), used when no Mojang file exists.
- `category` (`ui`, `toasts`, `blocks`, `ambient`) is which Options slider scales it.

Steps: find the path with `ls assets/mc/sounds/` (or look in `assets/mc/sounds.json` for a game event), add an entry to `tokens/sounds.json`
(or add it to `tools/assetforge/build_sounds_map.py`, which generates the file, so a rebuild keeps it), and check silently:

```sh
scripts/ow-sound --list                           # all ids, and whether their files exist
OW_SOUND_DRYRUN=1 scripts/ow-sound my.new.sound   # prints "id -> file volume=..." instead of playing
```

Use it from QML with `Theme.playSound("my.new.sound")` (components) or `SoundService.play(...)`; from bash with `overworld sound my.new.sound`.
When `"sounds": false` in `config.json`, `ow-sound` exits silently, which is what you want while developing at night.

---

## 4. Debugging

**Logs.** The shell started by `overworld on` writes to `~/.cache/overworld/qs.log` (`scripts/overworld:25`). `tail -f ~/.cache/overworld/qs.log`.
`qs log` reads the logs of a running instance: `qs -c overworld log -t 100` (see `qs log --help`; `-f` follows, `-r` applies Qt logging rules).
In QML, `console.warn("x", value)` is the print statement. A line starting `WARN scene:` with a file and line is a QML error in *your* file;
the repo's QA notes (`qa/REPORT.md`) list known harmless warnings from other software (icon themes, `.desktop` files).

**Is the shell running?** `pgrep -a qs` (look for `qs -c overworld`), `overworld status`.

**IPC.** `qs -c overworld ipc show` lists every target and function that exists right now (use this to find the exact name). Call one with
`qs -c overworld ipc call <target> <function> [args]`, e.g. `qs -c overworld ipc call interact status` ("idle fx=0 ..."),
`qs -c overworld ipc call theme get`. Do not name an IPC function `show`: the `qs` CLI swallows it (use `reveal`/`open`).

**Hyprland.**

| Question | Command |
|---|---|
| Did my config parse? | `hyprctl configerrors` (empty is good) |
| Is the bind registered? | `hyprctl binds \| grep -i <key>` (add `-j` for JSON with modmask/keycode) |
| What are the windows? | `hyprctl clients` (class, title, address) |
| Which surfaces does the shell have? | `hyprctl layers` (look for namespaces `overworld-*`) |
| Try a setting without editing | `hyprctl keyword decoration:rounding 4` (gone at the next `hyprctl reload`) |
| Reload after editing a `.conf` | `hyprctl reload` |

**The event bus.** `tail -f $XDG_RUNTIME_DIR/overworld/events.jsonl` shows every event as it happens. Post your own with
`overworld event workspace '{"id":3}'` (note: advancements and stats count it).

**State files.** Everything persistent is in `~/.config/overworld/` (`config.json`, `mode`, `gamemode`, `advancements.json`, `stats.json`, `workspaces.json`...).
They are plain text; stop and look before editing by hand.

**Common problems.**

- *Nothing happens on a key.* `hyprctl binds | grep -i <key>`; if absent the theme is off or the `unbind`/`bind` spelling does not match JaKooLit's (the
  key string must match exactly, `SPACE` is not `Space`; `hypr/test/check-config.sh` checks all of them).
- *The screen is wrong after JaKooLit scripts ran.* `overworld repair` (`SUPER+ALT+R`).
- *Texture shows magenta/black.* The Mojang assets are not fetched: `scripts/fetch-minecraft-assets.sh`.
- *QML change has no effect.* `overworld reload`; then read the log for the error.
- *Preview a component without touching the live shell:* each module has a `preview/` folder; run `qs -p <dir>` on it (see `docs/QUICKSHELL.md` and `docs/DESIGN.md`).

---

## 5. Where to read next

| You want to understand | Read |
|---|---|
| The design system and every `Mc*` component | `docs/DESIGN.md`, `quickshell/Common/` |
| The HUD, launcher, notifications, services | `docs/QUICKSHELL.md` |
| Chat, game modes, advancements, options | `docs/GAMEPLAY.md` |
| Weather, day cycle, F3 | `docs/WORLD.md` |
| Mining, placing, the death screen | `docs/INTERACTIONS.md` |
| Desktop cards | `docs/WIDGETS.md` |
| Hyprland itself on this machine | `docs/HYPRLAND-GUIDE.md` |
| App theming (kitty, GTK, rofi ...) | `docs/APPS.md` |
