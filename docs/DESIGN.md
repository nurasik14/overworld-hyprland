# Overworld Hyprland — Design System (v2, Minecraft)

Owner: design-director. Numbers live in `tokens/tokens.json`; generated app files in `tokens/out/<mode>/`
(`python3 tokens/build.py --check`). QML foundation: `quickshell/Common/`. Every component's API is also in the comment at the
top of its file, and a working example of each is in `quickshell/Common/preview/shell.qml`.

Preview (never writes the mode file, never takes keyboard focus, click-through):

```sh
source scripts/dev-env.sh
OW_MODE=light qs -p quickshell/Common/preview      # dark for Night
OW_PAGE=2 …    # screens, text, legacy wrappers      OW_PAGE=3 …  pixel comparison with gui/demo_background
OW_GUI=3 …     # pin GUI scale 1-4|auto              OW_REDUCED_MOTION=1 …      OW_NO_MOJANG=1 …  fallback art
OW_SOUND_DRYRUN=1 OW_SELFTEST=1 …                    # component logic checks, PASS/FAIL lines in the log
```

Screenshots: `qa/screenshots/design-preview-{day,night}.png`, `-{day,night}-2.png`, `-day-gui3.png`, `-day-nomojang.png`.

---

## 1. Concept

The desktop is a Minecraft world and the shell is its HUD and menus (BRIEF §2). Fidelity comes from using **the game's own
sprites, metrics and timings**, not an imitation of them:

- `McPanel` is pixel-identical to `gui/demo_background`; nine-sliced buttons are pixel-identical to `widget/button`
  (both verified with an offline image diff, 0 differing pixels).
- Layout numbers are the game's: 20 px button height, 18 px slots, 8 px heart pitch, title at (8, 6), tooltip margins.
- Motion runs on a 20 TPS clock, and things that snap in the game snap here.

**Day** (`light`) is the classic Java GUI: `#C6C6C6` panels, white and `#555555` bevels. **Night** (`dark`) is deepslate and
obsidian: `#31313A` panels with white text and shadows. Buttons, sliders and fields keep their real dark sprites in both modes.

## 2. Palette

Role names are stable: add, never rename. Legacy names (`seal`, `jade`, `plum`, `herb`, `ink[]`, `paper[]`…) are kept with Minecraft
values so every generated app config still works. In QML use the typed `Theme.<role>`; `Theme.col("role")` reaches any other role.

### GUI roles

| role | Day | Night | use |
|---|---|---|---|
| `panel` | `#C6C6C6` | `#31313A` | panel fill |
| `panelLight` | `#FFFFFF` | `#5A5A66` | top-left bevel |
| `panelShadow` | `#555555` | `#16161B` | bottom-right bevel |
| `panelOutline` | `#000000` | `#000000` | stepped outline |
| `slot` | `#8B8B8B` | `#1F1F26` | slot fill |
| `slotDark` | `#373737` | `#0C0C10` | slot top-left edge |
| `slotLight` | `#FFFFFF` | `#4C4C58` | slot bottom-right edge |
| `guiTitle`, `guiText` | `#404040` | `#FFFFFF` | text on panels; shadow only on light text |
| `text`, `textMuted` | `#373737`, `#4A4A4A` | `#FFFFFF`, `#B4B4B4` | general text |
| `bg0`, `bg1`, `bg2` | `#C6C6C6`, `#CECECE`, `#D6D6D6` | `#141418`, `#1B1B21`, `#25252C` | grounds |
| `surface`, `surfaceAlt` | `#C6C6C6`, `#BDBDBD` | `#25252C`, `#31313A` | terminals, cards |

### Same in both modes

| role | value | use |
|---|---|---|
| `buttonText`, `buttonTextDisabled` | `#FFFFFF`, `#A0A0A0` | button labels |
| `fieldFill`, `fieldBorder`, `fieldBorderFocus` | `#000000`, `#A0A0A0`, `#FFFFFF` | text field (the sprites draw these) |
| `fieldText`, `fieldPlaceholder`, `fieldSelection` | `#E0E0E0`, `#707070`, `#0000FF` | |
| `slotHover` | `#FFFFFF80` (CSS order) | slot hover overlay |
| `tooltipFill` | `#100010F0` (the game's ARGB `0xF0100010`) | tooltip fill |
| `tooltipBorderTop`, `tooltipBorderBottom` | `#5000FF50`, `#28007F50` | tooltip border gradient |
| `tooltipTitle`, `tooltipDesc`, `tooltipCategory` | `#FFFFFF`, `#AAAAAA`, `#5555FF` | |
| `toastTitle`, `toastChallenge`, `toastText` | `#FFFF00`, `#FF88FF`, `#FFFFFF` | |
| `toastLightTitle`, `toastLightText` | `#500050`, `#000000` | recipe and tutorial frames |
| `menuGradientTop`, `menuGradientBottom` | `#101010C0`, `#101010D0` | screen dim |
| `hudText`, `hudTextShadow` | `#FFFFFF`, `#3F3F3F` | text over the world |
| `xp`, `xpText` | `#80FF20` | XP |
| `enchant`, `enchantGlint` | `#8040CC`, `#A970FF` | |
| `splash` | `#FFFF00` | splash text (the game's constant, not §e) |
| `grass` `sky` `water` `lava` | `#7CBD6B` `#78A7FF` `#3F76E4` `#E8721C` | world accents |
| `nether` `netherPortal` `end` `endSky` | `#7B1E1E` `#6A1FBF` `#DBDE9E` `#1A0B2E` | (QML: `Theme.endStone`) |
| `dirt` `stone` `obsidian` `deepslate` | `#866043` `#7F7F7F` `#0F0B19` `#373738` | |
| `diamond` `emerald` `redstone` `lapis` `goldBlock` | `#4AEDD9` `#17DD62` `#FF0000` `#1D47A8` `#FAD64A` | |

### Chat colours

Literal §-colours, as roles (`chatBlack`… `chatWhite`) and in QML as `Theme.chat["a"]`:

| § | role | | § | role | |
|---|---|---|---|---|---|
| 0 | chatBlack | `#000000` | 8 | chatDarkGray | `#555555` |
| 1 | chatDarkBlue | `#0000AA` | 9 | chatBlue | `#5555FF` |
| 2 | chatDarkGreen | `#00AA00` | a | chatGreen | `#55FF55` |
| 3 | chatDarkAqua | `#00AAAA` | b | chatAqua | `#55FFFF` |
| 4 | chatDarkRed | `#AA0000` | c | chatRed | `#FF5555` |
| 5 | chatDarkPurple | `#AA00AA` | d | chatLightPurple | `#FF55FF` |
| 6 | chatGold | `#FFAA00` | e | chatYellow | `#FFFF55` |
| 7 | chatGray | `#AAAAAA` | f | chatWhite | `#FFFFFF` |

They are designed for dark grounds. On Day panels most fail contrast (§a on `#C6C6C6` is about 1.3:1), so `Theme.chatReadable(code)`
returns the same hue from the ANSI palette, which passes on every ground. `McText { codes: … }` does this automatically unless
`darkGround: true`, which you set inside tooltips, chat and screens.

### ANSI (terminals)

| | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| Day normal | `#1A1A1A` | `#8A0000` | `#004F00` | `#5A4600` | `#0000AA` | `#7A007A` | `#004F4F` | `#3F3F3F` |
| Day bright | `#4A4A4A` | `#9A0000` | `#005600` | `#594500` | `#1F1FBF` | `#8A008A` | `#005252` | `#2A2A2A` |
| Night normal | `#000000` | `#FF7070` | `#55FF55` | `#FFFF55` | `#8FA8FF` | `#FF77FF` | `#55FFFF` | `#CFCFCF` |
| Night bright | `#A0A0A8` | `#FF9090` | `#88FF88` | `#FFFF99` | `#B0C0FF` | `#FF9FFF` | `#99FFFF` | `#FFFFFF` |

Day ANSI 7 and 15 are dark greys on purpose: "white" text must stay readable on a light terminal.

### Contrast

`python3 tokens/build.py --check` fails on any miss; the full table is `tokens/out/contrast.md`. Grounds are `bg0`, `bg1`, `bg2`,
`surface`, `surfaceAlt`, `panel`. 213 pairs per mode, 0 failing. Worst case per role:

| role | Day | Night |
|---|---|---|
| `text` | 6.3 | 12.9 |
| `textMuted` | 4.7 | 6.2 |
| `guiTitle`, `guiText` | 5.5 | 12.9 |
| `accent` | 5.0 | 9.7 |
| `accent2` | 5.1 | 6.8 |
| `seal`, `error` | 4.9 | 4.8 |
| `success` | 5.0 | 9.7 |
| `warning` | 4.7 | 12.1 |
| `info` | 5.8 | 10.5 |
| `plum` | 4.9 | 5.7 |
| `jade` | 5.2 | 10.5 |
| `indigo` | 5.9 | 5.3 |
| `link` | 5.8 | 6.0 |
| all 16 ANSI (Night: 1-15; ansi0 is the background) | 4.57 | 4.78 |
| `frame` (shapes, needs 3.0) | 6.3 | 3.8 |

Fixed pairs in both modes: `buttonText` on the button sprite 5.0, disabled 5.3, `tooltipDesc` on `tooltipFill` 8.8, `toastTitle` on the
toast frame 15.0, `toastChallenge` 7.8, `toastLightTitle` on the recipe frame 10.9.

## 3. GUI scale

Everything is authored in **GUI pixels** and drawn at an integer scale.

- `Theme.gui` is the scale: config `gui_scale` 1-4 or `"auto"`, default 2. `Theme.px(n)` = n × gui.
- `"auto"` = floor(min(w/960, h/540)), clamped to 1..4, so 1920×1080 gives 2. The game's own Auto would give 4 on this screen, far too
  large for a desktop shell.
- Keep sizes and positions at multiples of `Theme.gui` (use `Theme.px`). An odd screen pixel breaks the bevels and blurs nothing, but
  it looks wrong.
- Type: `McText.units` is a multiple of the 8 px font unit × gui. **Mojangles is crisp at 8 px × n** (`Theme.fontPx`).
- **Monocraft is crisp at 9 px × n** (`Theme.monoPx`): its grid is 120 font units per pixel at upem 1080. `McText { mono: true }` and
  `fontFor("mono")` handle this. Outside QML (kitty, hyprlock, rofi) use 9, 18, 27 px.
- Line pitch is 10 GUI px per unit. A line box has 1 GUI px above the glyphs and 2 below, so to put text at the game's y, use y − 1
  (see `McPanel`'s title).
- Mojangles has no Nerd Font glyphs and no CJK. Use `McText { mono: true }` or `McButton { glyph: … }` for Nerd glyphs.

## 4. Sprites and nine-slice

`Theme.tex("gui/sprites/hud/heart/full")` resolves `assets/mc/textures/<p>.png`, else `assets/gen/textures/<p>.png`, else the magenta
and black missing texture (`quickshell/Common/assets/missing.png`). Component `sprite:` properties take the short form rooted at
`gui/sprites` (`"hud/heart/full"`), or a full path when the first folder is a texture root (`"block/stone"`, `"gui/menu_background"`).

Rules, all implemented by `McNineSlice`:

- The sprite is drawn at source resolution in an item with `scale: gui` and `smooth: false`, so texels stay square. Never scale pixel art
  with a fractional factor or `smooth: true`.
- `.png.mcmeta` `gui.scaling` decides the mode: `nine_slice` (border and tiled centre), `tile`, or `stretch` (the default when absent).
  `stretch_inner: true` stretches instead of tiling.
- Borders are clamped to half the drawn size, like the game. That is how `toast/system` (64 px high, top border 30) draws at 32 px.
- Sprites with no mcmeta can be nine-sliced by passing `scaling:` yourself:
  `scaling: ({ type: "nine_slice", width: 160, height: 32, border: 4 })`.
- `nightRemap: true` swaps the Java GUI greys for the Night palette through `shaders/mcpalette.frag` (`#FFFFFF`→`panelLight`,
  `#C6C6C6`→`panel`, `#8B8B8B`→`slot`, `#555555`→`panelShadow`, `#373737`→`slotDark`). `tint: colour` multiplies, for grey textures like
  `block/water_still`. If you edit the shader, rebuild it:
  `/usr/lib64/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o mcpalette.frag.qsb mcpalette.frag`.

## 5. Motion (§4.8)

Everything visual honours `Theme.reducedMotion` (config `reduced_motion: true` or `animations: false`): sprite stepping, jiggle and
pulses stop and durations become 0. Verified: two captures under reduced motion differ by 0 pixels.

| thing | timing | constant |
|---|---|---|
| tick clock | 50 ms (20 TPS), one Timer, stopped when nobody holds it | `Theme.tick`, `McTicker` |
| button, slot, tab hover | instant | none, never animate these |
| hotbar selection | instant | |
| GUI screen fade | 150 ms OutQuad | `Theme.guiFade`, `Theme.easeGui` |
| toast slide | 500 ms in (InQuad, the game squares its progress), out 500 ms | `Theme.toastSlide`, `Theme.easeToast` |
| toast hold | 5000 ms | `Theme.toastHold` |
| /title | in 10, stay 70, out 20 ticks | `Theme.ticks.title_in`… , `Theme.ticksMs(n)` |
| item name above hotbar | hold 40, fade 10 ticks | `Theme.ticks.item_name_hold`, `item_name_fade` |
| chat line | hold 200, fade 20 ticks | `Theme.ticks.chat_hold`, `chat_fade` |
| text cursor | 6 ticks on, 6 off | `McTextField` |
| water, portal, fire | mcmeta frametime | `McAnimatedSprite` |
| splash pulse | 1000 ms loop, scale 1.8 − abs(sin(2πt))·0.1 | `McSplash` |
| hearts jiggle, regen wave, hunger shake | per tick | `McStatRow` |
| mode cross-fade | 500 ms OutCubic on typed colours | `Theme.durTheme` |
| window placed (Hyprland) | 250 ms, popin 85 %, slight overshoot | `motion.hyprland`, bezier `block` |
| workspace slide (Hyprland) | 350 ms | `motion.hyprland` |

`Theme.ms(n)` returns n, or 0 under reduced motion: `NumberAnimation { duration: Theme.ms(300) }`. Legacy `durFast`, `durBase`, `durSlow`,
`stagger`, `easeInk`, `easeBrush`, `easeDrift` still exist. Don't use them in new work.

## 6. Theme API

```qml
import qs.Common
```

| API | meaning |
|---|---|
| `mode`, `isDark`, `setMode(m)`, `toggleMode()` | light or dark; watches `~/.config/overworld/mode` |
| `gui`, `px(n)`, `fontPx(units)`, `monoPx(units)` | scale helpers |
| `tex(path)`, `gs(spritePath)`, `spritePath(p)`, `spriteMeta(p)`, `hasMojangAssets`, `missingTexture` | textures |
| `iconUrl(name)`, `itemFor(appClass, title)`, `items` | icons; `itemFor` applies `_title_rules` from `tokens/items.json`, then the class, then `_default` |
| `col(role)`, `colOf(mode, role)`, `c`, `ansi`, `chat`, `chatReadable(code)`, `withAlpha(c, a)`, `shadowOf(c)`, `qtColor(v)` | colours |
| `tick`, `tickAcquire()`, `tickRelease()` | clock; prefer `McTicker` |
| `ms(n)`, `ticksMs(n)`, `ticks`, `reducedMotion`, `guiFade`, `toastSlide`, `toastHold`, `easeGui`, `easeToast`, `easeBlock` | motion |
| `fontUi`, `fontMono`, `fontFor(role)` | fonts; first family present in `Qt.fontFamilies()` |
| `playSound(id)` | runs `scripts/ow-sound <id>` detached |
| `widgetOpacity` | config `widgets.opacity`, default 0.72 |
| `repoDir`, `assetsDir`, `commonDir`, `stateDir`, `home`, `config`, `ready` | locations and state |

**Sound:** Common calls `Theme.playSound` directly rather than `SoundService`, so Common has no dependency on Services and a preview
harness only needs a `Common` symlink. `ow-sound` is the one player (§4.5), so behaviour is the same either way. Skipped when config has
`sounds: false`, unless `OW_SOUND_DRYRUN` is set.

**Tick use:** read `Theme.tick` only through a held reference, otherwise it never advances:

```qml
McTicker { id: clock; active: root.visible; onTicked: n => frame = n % 32 }
```

## 7. Component reference

All sizes are GUI px unless noted. Components with a `skin` take `"auto"` (default, follows the mode and cross-fades), `"day"` or `"night"`.

### McNineSlice, McSprite
`sprite`, `source`, `scaling`, `scaleFactor`, `tint`, `nightRemap`; read `meta`. Natural size × gui unless sized. `McSprite` is the same type,
for plain sprites.
```qml
McNineSlice { sprite: "widget/button"; width: Theme.px(150); height: Theme.px(20) }
McSprite { sprite: "server_list/ping_" + level }
```

### McPanel
`title`, `titleColor`, `skin`, `fillOpacity` (centre only, bevels stay solid, negative = 1), `padding` (default px(7)), default property `content`,
`contentItem`, `titleItem`. Size it explicitly; it doesn't grow from its content.
```qml
McPanel { title: "Weather"; width: Theme.px(176); height: Theme.px(80); fillOpacity: Theme.widgetOpacity
    McText { text: "Clear" }
}
```

### McText
It **is** a `Text`: anchors, `width`, `elide`, `wrapMode`, `font.*`, `contentWidth` all work. Adds `units`, `mono`, `guiTitle`, `codes` (§-string),
`darkGround`, `rainbow`, `shadow` (default on for light text only), `shadowColor` (default colour × 0.25), `shadowOffset`.
Codes: §0-§f, §l bold, §o italic, §n underline, §m strike, §r reset.
```qml
McText { text: "Inventory"; guiTitle: true }
McText { codes: "§aOnline §7(3 players)"; darkGround: true }
McText { text: "Now Playing: Sweden"; rainbow: true }
```

### McOutlineText
`text`, `color` (default `Theme.xp`), `outlineColor`, `units`. The XP-level look.
```qml
McOutlineText { text: "30" }
```

### McButton
`text`, `labelColor`, `wide` (200), `small` (98), default 150, `fit`, `icon` (item), `glyph` (Nerd), `flat`, `highlighted`, `focusRing`, `soundId` (default `ui.click`,
`""` silent), `tooltip`, `tooltipDescription`, `tooltipCategory`, `horizontalPadding`; read `hovered`, `pressed`, `lit`; `clicked()`, `activate()`. Extra children are drawn over
the button. Tab focuses; Enter, Return and Space activate. The game has no pressed sprite: feedback is the highlight and the click.
```qml
McButton { text: "Back to Game"; wide: true; onClicked: menu.close() }
```

### McIconButton
McButton plus `item`, `sprite`, `size` (default 20).
```qml
McIconButton { item: "barrier"; tooltip: "Close"; onClicked: panel.close() }
```

### McToggle
McButton plus `label`, `checked`, `onText`, `offText`, `toggled(bool)`. Prints "Label: ON".
```qml
McToggle { label: "Particles"; checked: cfg.particles; onToggled: c => cfg.particles = c }
```

### McCheckbox
`text`, `checked`, `labelColor`, `highlighted`, `soundId`, `toggle()`, `toggled(bool)`.
```qml
McCheckbox { text: "Show seconds"; labelColor: Theme.guiText; onToggled: c => save(c) }
```

### McSlot
`item`, `app`, `appTitle`, `iconSource`, `count`, `highlighted`, `selected`, `glint`, `skin`, `soundId`, `tooltip`, `tooltipDescription`, `tooltipCategory`, `tooltipLines`; read `hovered`,
`empty`; `clicked()`, `rightClicked()`. 18×18; the 16×16 item area starts at (1,1). Extra children go between the icon and the count.
```qml
Grid { columns: 9
    Repeater { model: apps; McSlot { required property var modelData; app: modelData.id; tooltip: modelData.name
                                     tooltipCategory: modelData.category; onClicked: launch(modelData) } }
}
```

### McItemIcon
`name`, `app`, `appTitle`, `source`, `size` (default 16), `glint`. Lookup: `assets/icons/mc` → `assets/gen/icons` → `item/` → `block/` → missing.
```qml
McItemIcon { app: win.class; appTitle: win.title }
```

### McTooltip
`title`, `description` (grey, `\n` lines), `category` (blue), `lines` (§-strings), `maxWidth`, `target`, `targetX`, `targetY`, `margin`. With a `target` it reparents to the window's
content item, stays on top and flips at the window edge. Its size includes the sprite's transparent margin, so place it at −`margin` to line up by the visible edge.
Button, slot and tab tooltips are built in; use this directly only for custom hover areas.
```qml
MouseArea { id: area; anchors.fill: parent; hoverEnabled: true }
McTooltip { visible: area.containsMouse; title: "CPU"; description: "12% load"; target: area; targetX: area.mouseX; targetY: area.mouseY }
```

### McTextField
`text`, `placeholderText`, `echoMode`, `maxLength`, `validator`, `readOnly`, `inputMethodHints`, `selectByMouse`, `cursorPosition`, `highlighted`, `input` (the TextInput); `accepted()`, `edited()`,
`escapePressed()`. The window needs keyboard focus. Default 150×20. Password echo uses the game's `*`.
```qml
McTextField { placeholderText: "Password"; echoMode: TextInput.Password; onAccepted: connect(text) }
```

### McSlider
`label`, `value`, `from`, `to`, `stepSize`, `valueText`, `text`, `live`, `highlighted`, `focusLook`, `soundId`; read `position`, `hovered`, `pressed`; `moved(v)`, `released(v)`. Left, Right and the wheel step.
```qml
McSlider { label: "Master Volume"; value: vol; onMoved: v => setVolume(v) }
McSlider { value: b; text: "Brightness: " + (b === 0 ? "Moody" : b === 1 ? "Bright" : Math.round(b * 100) + "%") }
```

### McScrollbar
`flickable`, or manual `position`, `pageRatio`, `moved(p)`. `variant`: `"list"` (6 wide, proportional thumb) or `"creative"` (14 wide, fixed thumb). `skin`, `highlighted`; read `scrollable`.
```qml
McScrollbar { flickable: list; anchors { right: parent.right; top: list.top; bottom: list.bottom } }
```

### McTabs
`tabs` (`[{ item | sprite, label, description, category }]`), `currentIndex`, `side` (`"top"`, `"bottom"`), `skin`, `soundId`, read `hoveredIndex`, `overlap`; `tabClicked(i)`. Sits at `z: 1`.
```qml
McTabs { id: t; tabs: [{ item: "compass", label: "Search" }, { item: "nether_star", label: "Favourites" }]
         anchors { left: panel.left; bottom: panel.top; bottomMargin: -t.overlap } }
```

### McProgressBar
`kind` (`"xp"`, `"boss"`), `value`, `color` (boss: pink, blue, red, green, yellow, purple, white), `notches` (0, 6, 10, 12, 20), `title`, `level` (−1 hides), `animated`.
```qml
McProgressBar { value: progress; level: hours }
McProgressBar { kind: "boss"; color: "purple"; notches: 10; title: "Brewing: essay"; value: 0.7 }
```

### McToast
`kind` (`advancement`, `goal`, `challenge`, `recipe`, `tutorial`, `system`, `now_playing`), `title` (defaults for the first three are the game's), `description`, `icon`, `iconSprite`, `iconSource`,
`maxWidth`, `autoHideMs`, `shown`, `silent`; `reveal()`, `dismiss()`, `dismissed()`, `clicked()`. Stacking belongs to the owner. The root keeps its size while the frame slides.
```qml
McToast { kind: "challenge"; description: "100 windows mined"; icon: "diamond_pickaxe"
          Component.onCompleted: reveal(); onDismissed: destroy() }
```

### McScreen
`title`, `titleY`, `background` (`"gradient"`, or `"menu"` for the 1.21 list screen), `headerHeight`, `footerHeight`, `opened`, `closeOnEscape`, `open()`, `close()`, `toggle()`, default property `content`,
`contentItem`; `opening()`, `closed()`. The `closed()` signal fires after the fade. Fill a layer window with it. The game's `menu_background` is a translucent dark overlay, not dirt: the world shows through.
```qml
McScreen { id: menu; anchors.fill: parent; title: "Game Menu"; titleY: 40
    Column { anchors.centerIn: parent; McButton { text: "Back to Game"; wide: true; onClicked: menu.close() } }
}
```

### McSplash
`text`, `units`, `running`. Takes no layout space: place its centre. Uses the game's formula, so short text is drawn larger.
```qml
McSplash { x: Theme.px(320); y: Theme.px(60); text: "Also try Terraria!" }
```

### McDivider
`variant` (`"bevel"`, `"header"`, `"footer"`), `vertical` (bevel only), `skin`.
```qml
McDivider { width: parent.width }
```

### HeartsRow, HungerRow, ArmorRow, AirRow, McStatRow
All: `value` (7.5 = seven and a half), `max` (default 10), `jiggle`, `shake`, `wave`, `lifted`, `reverse`.
HeartsRow adds `style` (`normal`, `poisoned`, `withered`, `frozen`, `absorbing`), `hardcore`, `blinking`, `regen`, `lowAt` (jiggle threshold, default 2). HungerRow adds `hunger` and fills from the right.
AirRow fills from the right. McStatRow is the generic base: `emptySprite`, `halfSprite`, `fullSprite`, or `spriteFor: (index, kind) => path`.
```qml
HeartsRow { value: battery / 10; regen: charging; hardcore: battery <= 5 }
HungerRow { value: freeRamRatio * 10; shake: swapHeavy }
ArmorRow { value: 7.5 }
AirRow { value: 7.5 }
```

### McAnimatedSprite
`sprite`, `frameTime` (default from mcmeta), `running`, `tint`, `columns`, `rows`, `scroll` (for `misc/enchanted_glint_item`, which is not a strip), read `frame`. Handles `frames` with indices or `{index, time}`, and `height`.
```qml
McAnimatedSprite { sprite: "block/water_still"; tint: Theme.water }
McAnimatedSprite { sprite: "block/nether_portal"; width: Theme.px(32); height: Theme.px(32) }
```

### McTicker
`active`, `tick`, `ticked(int)`. See §6.

### Deprecated wrappers
`PaperPanel`, `InkButton`, `InkText`, `TitleBar`, `Seal`, `InkDivider`, `PaperBackground` keep their old APIs on top of the Mc* look so unported modules load and look right. Don't use them in new work.
Note `Seal.size` and `PaperPanel`'s legacy properties take screen px; `McItemIcon.size` takes GUI px.

## 8. Sprite cheat-sheet

Paths are relative to `gui/sprites/` unless they start with `gui/`, `block/`, `item/`, and so on. `*` means several variants.

| desktop thing | sprites |
|---|---|
| hotbar | `hud/hotbar` (182×22), `hud/hotbar_selection` (24×23), `hud/hotbar_offhand_left`, `_right` (29×24) |
| hearts | `hud/heart/container`, `full`, `half`, with `_blinking`, `hardcore_`, `poisoned_`, `withered_`, `frozen_`, `absorbing_`, `vehicle_` |
| hunger | `hud/food_empty`, `_half`, `_full`, plus `_hunger` |
| armor, air | `hud/armor_empty`, `_half`, `_full`; `hud/air`, `air_empty`, `air_bursting` |
| XP | `hud/experience_bar_background`, `_progress` (182×5) |
| effects, crosshair | `hud/effect_background`, `_ambient`; `container/inventory/effect_background*`; `hud/crosshair*` |
| boss bars | `boss_bar/{pink,blue,red,green,yellow,purple,white}_{background,progress}`, `boss_bar/notched_{6,10,12,20}_{background,progress}` |
| toasts | `toast/advancement`, `recipe`, `tutorial`, `system`, `now_playing`; icons `toast/tree`, `wooden_planks`, `recipe_book`, `mouse`, `movement_keys`, `right_click`, `social_interactions` |
| buttons | `widget/button`, `_highlighted`, `_disabled`; `widget/locked_button*`, `unlocked_button*`, `cross_button*`, `page_forward*`, `page_backward*` |
| slider | `widget/slider`, `_highlighted`, `slider_handle`, `_highlighted` |
| text field | `widget/text_field`, `_highlighted` |
| checkbox | `widget/checkbox`, `_selected`, `_highlighted`, `_selected_highlighted` |
| list scrollbar | `widget/scroller`, `widget/scroller_background` |
| header tabs (Options style) | `widget/tab`, `_selected`, `_highlighted`, `_selected_highlighted` |
| creative tabs | `container/creative_inventory/tab_{top,bottom}_{selected,unselected}_{1..7}` (26×32), `scroller`, `scroller_disabled` (12×15) |
| creative backgrounds | `gui/container/creative_inventory/tab_items`, `tab_item_search`, `tab_inventory` |
| container backgrounds | `gui/container/{inventory,generic_54,furnace,brewing_stand,crafting_table,…}`, `gui/demo_background` |
| slots | `container/slot`, `container/slot_highlight_back`, `_front`, `widget/slot_frame` |
| brewing stand | `gui/container/brewing_stand`, `container/brewing_stand/brew_progress`, `bubbles`, `fuel_length` |
| furnace | `gui/container/furnace`, `container/furnace/burn_progress`, `lit_progress` |
| ping bars | `server_list/ping_{1..5}`, `pinging_{1..5}`, `unreachable`, `incompatible`; `icon/ping_{1..5}`, `ping_unknown` |
| server list rows | `server_list/join`, `_highlighted`, `move_up*`, `move_down*`; `misc/unknown_server` |
| world list rows | `world_list/join`, `_highlighted`, `marked_join*`, `warning*`, `error*`; `misc/unknown_pack` |
| advancement frames | `advancements/{task,goal,challenge}_frame_{obtained,unobtained}` |
| advancement boxes, window | `advancements/box_obtained`, `box_unobtained`, `title_box`; `gui/advancements/window`, `gui/advancements/backgrounds/{stone,adventure,husbandry,nether,end}` |
| advancement tabs | `advancements/tab_{above,below,left,right}_{left,middle,right,top,bottom}[_selected]` |
| statistics | `statistics/block_mined`, `item_broken`, `item_crafted`, `item_used`, `item_picked_up`, `item_dropped`, `header`, `sort_up`, `sort_down` |
| gamemode switcher | `gamemode_switcher/slot`, `selection`; `gui/container/gamemode_switcher` |
| notification badges | `notification/{1..5}`, `more`; `icon/unseen_notification` |
| small icons | `icon/search`, `info`, `language`, `accessibility`, `checkmark`, `link`, `news`, `music_notes` (animated), `chat_modified`, `invite` |
| tooltip, popup | `tooltip/background`, `tooltip/frame`, `popup/background` |
| menus | `gui/menu_background`, `gui/menu_list_background`, `gui/inworld_menu_*`, `gui/header_separator`, `gui/footer_separator`, `gui/tab_header_background` |
| recipe book | `recipe_book/*`, `gui/recipe_book` |
| world textures | `block/water_still`, `block/lava_still`, `block/nether_portal`, `block/fire_0`, `misc/enchanted_glint_item`, `environment/sun`, `environment/moon_phases`, `environment/rain`, `environment/snow` |

Never use `gui/title/minecraft`, `minceraft` or `edition` on screen: our wordmark is OVERWORLD (BRIEF §1.9).

## 9. Do and don't

**Do**
- Author in GUI px through `Theme.px`, and use the game's numbers (20 high buttons, 18 slots, 8 heart pitch).
- Draw pixel art with Mc* or `smooth: false` at an integer scale.
- Use a real sprite if one exists; check the cheat-sheet first.
- Use `Theme.tick` through `McTicker`, and set `active` so hidden things stop asking for ticks.
- Highlight on hover instantly. Fade whole screens only, at 150 ms.
- Respect `Theme.reducedMotion` in anything you animate yourself (`Theme.ms`).
- Use `Theme.widgetOpacity` as `fillOpacity` on desktop widgets.
- Set `darkGround: true` on §-coded text inside tooltips, chat and screens.
- Use `Theme.playSound` or `SoundService` with the ids in §4.5 for feedback.

**Don't**
- No rounded corners, gradients on panels, soft shadows or blur. Depth comes from the bevels and hard 1 GUI px text shadows.
- No fractional scale on pixel art, and no `smooth: true`, `mipmap: true` or `Text.QtRendering` on game surfaces.
- No hover or colour transitions on widgets, and no bounce or easing on hotbar selection.
- Don't hardcode greys: use the roles, so Night works.
- Don't put chat colours on Day panels raw; use `McText.codes` or `Theme.chatReadable`.
- Don't read `Theme.tick` without holding a reference, or it will sit still.
- Don't scale Mojangles to anything but 8 px × n, or Monocraft to anything but 9 px × n.
- Don't call `pw-play` directly, and don't commit anything derived from Mojang assets (BRIEF §1.9).

## 10. Notes for module authors

- Preview harness: a `Common` symlink beside your `shell.qml` is enough for `import qs.Common`. Add `Services` only if your own module imports it.
- Quickshell only registers `pragma Singleton` types for directories inside the config root, so a relative `import "../"` won't find `Theme`.
- A property called `top`, `left`, `right` or `bottom` on an Item is a QML error (`Cannot override FINAL property`). Property names can't begin with a capital.
- `Font.NoAntialias` is not available in QML. Bitmap crispness comes from `renderType: Text.NativeRendering` plus `antialiasing: false`, both of which `McText` sets.
- `FileView.text()` inside a binding captures a notifying property and loops. `Theme._read` shows the workaround if you need a synchronous read from a binding.
- `tokens/items.json` regexes use Python's `(?i)`. Go through `Theme.itemFor` rather than parsing them yourself.
