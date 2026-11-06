//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

/*  Design-system preview.  Run from the repo root:
 *      source scripts/dev-env.sh
 *      OW_MODE=light qs -p quickshell/Common/preview            (OW_MODE=dark for Night; never writes the mode file)
 *      OW_PAGE=2 …       page 2: screens, text, legacy wrappers;  OW_PAGE=3 …  pixel comparison against gui/demo_background
 *      OW_SELFTEST=1 …   exercises component logic from code and logs PASS/FAIL lines
 *      OW_GUI=1-4|auto, OW_REDUCED_MOTION=1, OW_NO_MOJANG=1 (fallback art)
 *  `Common` in this directory is a symlink so `import qs.Common` resolves as it does in the real shell (config root =
 *  quickshell/). Common has no dependency on Services, so a preview needs no other link. The window is click-through and never takes keyboard focus, so forced-state
 *  properties (highlighted, focusRing…) stand in for real hover and focus.
 */
ShellRoot {
    id: shell
    readonly property int page: parseInt(Quickshell.env("OW_PAGE") || "1")

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === "eDP-1") || Quickshell.screens[0]
        anchors { top: true; left: true; right: true; bottom: true }
        color: "#000000"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "overworld-preview"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region { }

        Rectangle {   // a stand-in world so translucent parts have something to show
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.isDark ? "#0c1020" : Theme.sky }
                GradientStop { position: 0.8499; color: Theme.isDark ? "#1a2038" : "#bcd4ff" }
                GradientStop { position: 0.85; color: Theme.isDark ? "#14301a" : Theme.grass }
                GradientStop { position: 1; color: Theme.isDark ? "#0e2012" : "#5d8c3e" }
            }
        }

        Loader { anchors.fill: parent; active: shell.page === 1; sourceComponent: pageOne }
        Loader { anchors.fill: parent; active: shell.page === 2; sourceComponent: pageTwo }
        Loader { anchors.fill: parent; active: shell.page === 3; sourceComponent: pageThree }
    }

    component Head: McText {
        color: Theme.hudText
        shadowColor: Theme.guiTextShadow
    }

    Component {
        id: pageOne
        Item {
            // ------------------------------------------------------------ column A: controls
            Column {
                x: Theme.px(6); y: Theme.px(4)
                spacing: Theme.px(2)
                Head { text: "McButton: normal, hover, disabled, focus ring" }
                Row {
                    spacing: Theme.px(4)
                    McButton { text: "Singleplayer"; small: true }
                    McButton { text: "Multiplayer"; small: true; highlighted: true }
                    McButton { text: "Realms"; small: true; enabled: false }
                }
                Row {
                    spacing: Theme.px(4)
                    McButton { text: "Wide: Save and Quit to Title"; wide: true }
                    McButton { text: "Options..."; small: true; focusRing: true }
                }
                Row {
                    spacing: Theme.px(4)
                    McButton { text: "With item"; icon: "compass"; small: true }
                    McButton { text: "Nerd glyph"; glyph: "\uf013"; small: true }
                    McButton { text: "A label much too long"; small: true }
                }
                Head { text: "McIconButton, McToggle, McCheckbox" }
                Row {
                    spacing: Theme.px(4)
                    McIconButton { item: "compass" }
                    McIconButton { item: "barrier"; highlighted: true }
                    McIconButton { item: "clock_00"; enabled: false }
                    McIconButton { sprite: "icon/language" }
                    McIconButton { sprite: "icon/accessibility"; focusRing: true }
                    McButton { text: "Fit"; fit: true; highlighted: true }
                    McIconButton { item: "apple"; size: 16 }
                }
                Row {
                    spacing: Theme.px(4)
                    McToggle { label: "Particles"; checked: true; width: Theme.px(150) }
                    McToggle { label: "Peaceful"; checked: false; width: Theme.px(150); highlighted: true }
                }
                Rectangle {   // checkboxes on the panel colour, as they appear inside a panel
                    width: Theme.px(304); height: Theme.px(24); color: Theme.panel
                    Row {
                        x: Theme.px(2); y: Theme.px(2)
                        spacing: Theme.px(4)
                        McCheckbox { text: "Off" }
                        McCheckbox { text: "On"; checked: true }
                        McCheckbox { text: "Hover"; highlighted: true }
                        McCheckbox { text: "On, hover"; checked: true; highlighted: true }
                    }
                }
                Head { text: "McSlider" }
                Row {
                    spacing: Theme.px(4)
                    McSlider { label: "Master Volume"; value: 0.75 }
                    McSlider { label: "Brightness"; value: 0; text: "Brightness: Moody"; highlighted: true }
                }
                Row {
                    spacing: Theme.px(4)
                    McSlider { label: "Music"; value: 1; focusLook: true; highlighted: true }
                    McSlider { label: "Disabled"; value: 0.3; enabled: false }
                }
                Head { text: "McTextField: placeholder, focused, password" }
                Row {
                    spacing: Theme.px(4)
                    McTextField { placeholderText: "Search..." }
                    McTextField { text: "New World"; highlighted: true }
                }
                Row {
                    spacing: Theme.px(4)
                    McTextField { text: "hunter2"; echoMode: TextInput.Password }
                    McTextField { text: "cursor inside"; highlighted: true; Component.onCompleted: cursorPosition = 6 }
                }
                Head { text: "McProgressBar: XP, boss bars" }
                McProgressBar { value: 0.42; level: 7; width: Theme.px(182) }
                McProgressBar { kind: "boss"; color: "purple"; title: "Brewing: essay"; value: 0.7 }
                McProgressBar { kind: "boss"; color: "red"; notches: 10; value: 0.55 }
                McProgressBar { kind: "boss"; color: "green"; notches: 20; value: 0.3 }
                Row {
                    spacing: Theme.px(4)
                    Repeater {
                        model: ["pink", "blue", "yellow", "white"]
                        McProgressBar { required property string modelData; kind: "boss"; color: modelData; value: 0.6; width: Theme.px(74) }
                    }
                }
            }

            // ------------------------------------------------------------ column B: panel, tabs, slots
            Item {
                x: Theme.px(318); y: Theme.px(4)
                Head { y: 0; text: "McPanel, McTabs, McSlot" }
                McTabs {
                    id: tabs
                    x: 0; y: Theme.px(12)
                    currentIndex: 1
                    tabs: [
                        { item: "compass", label: "Search" }, { item: "nether_star", label: "Favourites" },
                        { item: "brick", label: "Blocks" }, { item: "redstone", label: "Redstone" },
                        { item: "apple", label: "Food" }
                    ]
                }
                McPanel {
                    id: inv
                    x: 0; y: tabs.y + tabs.height - tabs.overlap
                    width: Theme.px(195); height: Theme.px(106)
                    title: "Favourites"
                    z: 0
                    Grid {
                        columns: 9
                        Repeater {
                            model: [
                                { item: "command_block", n: 3 }, { item: "compass", n: 1 }, { item: "diamond_pickaxe", n: 1, glint: true }, { item: "redstone", n: 64 },
                                { item: "apple", n: 12 }, { item: "bread", n: 1, hl: true }, { item: "map", n: 1 }, { item: "clock_00", n: 2 }, { item: "", n: 1 },
                                { item: "book", n: 1 }, { item: "chest", n: 5 }, { item: "furnace", n: 1, sel: true }, { item: "", n: 1 }, { item: "not_a_real_item", n: 1 },
                                { item: "", n: 1 }, { item: "", n: 1, hl: true }, { item: "ender_pearl", n: 16 }, { item: "brewing_stand", n: 1 },
                                { app: "kitty", n: 3 }, { app: "zen", n: 7 }, { app: "spotify", n: 1 }, { app: "kitty", t: "nvim notes.txt", n: 2 }, { app: "kitty", t: "hermes", n: 1 }, { app: "unknown-app", n: 1 }, { item: "", n: 1 }, { item: "", n: 1 }, { item: "", n: 1 }
                            ]
                            McSlot {
                                required property var modelData
                                item: modelData.item || ""
                                app: modelData.app || ""
                                appTitle: modelData.t || ""
                                count: modelData.n
                                highlighted: !!modelData.hl
                                selected: !!modelData.sel
                                glint: !!modelData.glint
                            }
                        }
                    }
                }
                McScrollbar {
                    x: Theme.px(173); y: inv.y + Theme.px(17)
                    height: Theme.px(54)
                    variant: "creative"
                    position: 0.35
                    pageRatio: 0.5
                }

                Row {
                    y: inv.y + inv.height + Theme.px(4)
                    spacing: Theme.px(4)
                    McPanel {
                        width: Theme.px(92); height: Theme.px(44)
                        title: "Skin: day"
                        skin: "day"
                        McSlot { y: Theme.px(10); item: "emerald"; skin: "day" }
                        McSlot { x: Theme.px(18); y: Theme.px(10); item: "wheat"; count: 6; skin: "day"; highlighted: true }
                    }
                    McPanel {
                        width: Theme.px(92); height: Theme.px(44)
                        title: "Skin: night"
                        skin: "night"
                        McSlot { y: Theme.px(10); item: "ender_eye"; skin: "night" }
                        McSlot { x: Theme.px(18); y: Theme.px(10); item: "blaze_powder"; count: 6; skin: "night"; highlighted: true }
                    }
                }
                Row {
                    y: inv.y + inv.height + Theme.px(52)
                    spacing: Theme.px(4)
                    McPanel {
                        width: Theme.px(92); height: Theme.px(44)
                        title: "fillOpacity .72"
                        fillOpacity: 0.72
                        McDivider { y: Theme.px(12); width: parent.width }
                    }
                    McPanel {
                        width: Theme.px(92); height: Theme.px(44)
                        title: "List scroller"
                        fillOpacity: 0.72
                        McScrollbar { anchors.right: parent.right; y: 0; height: Theme.px(24); position: 0; pageRatio: 0.9; highlighted: true }
                        McScrollbar { anchors.right: parent.right; anchors.rightMargin: Theme.px(10); y: 0; height: Theme.px(24); position: 1; pageRatio: 1 }
                    }
                }
                Head { y: inv.y + inv.height + Theme.px(100); text: "McTooltip" }
                McTooltip {
                    x: -Theme.px(12) + Theme.px(4); y: inv.y + inv.height + Theme.px(102)
                    title: "Kitty"
                    description: "Fast GPU terminal"
                    category: "Utilities"
                }
                McTooltip {
                    x: -Theme.px(12) + Theme.px(4); y: inv.y + inv.height + Theme.px(146)
                    title: "Enchanted Pickaxe"
                    lines: ["§7Efficiency V", "§9+5 Attack Damage", "§8minecraft:diamond_pickaxe"]
                }
            }

            // ------------------------------------------------------------ column C: HUD, toasts, animated
            Column {
                x: Theme.px(522); y: Theme.px(4)
                spacing: Theme.px(2)
                Head { text: "HeartsRow 7.5/10, 10/10, jiggle, regen, styles" }
                Row {
                    spacing: Theme.px(6)
                    Column {
                        spacing: Theme.px(2)
                        HeartsRow { value: 7.5 }
                        HeartsRow { value: 1.5 }
                        HeartsRow { value: 6; regen: true }
                        HeartsRow { value: 4.5; hardcore: true }
                    }
                    Column {
                        spacing: Theme.px(2)
                        HeartsRow { value: 6.5; style: "poisoned" }
                        HeartsRow { value: 6.5; style: "withered" }
                        HeartsRow { value: 6.5; style: "frozen" }
                        HeartsRow { value: 6.5; blinking: true }
                    }
                }
                Head { text: "HungerRow, ArmorRow, AirRow" }
                Row {
                    spacing: Theme.px(6)
                    Column {
                        spacing: Theme.px(2)
                        HungerRow { value: 7.5 }
                        HungerRow { value: 2.5; shake: true }
                        HungerRow { value: 5; hunger: true }
                    }
                    Column {
                        spacing: Theme.px(2)
                        ArmorRow { value: 7.5 }
                        AirRow { value: 7.5 }
                        ArmorRow { value: 10 }
                    }
                }
                Head { text: "McToast: all frames" }
                Grid {
                    columns: 2
                    spacing: Theme.px(3)
                    McToast { shown: true; silent: true; autoHideMs: 0; icon: "diamond_pickaxe"; description: "Getting an Upgrade" }
                    McToast { kind: "goal"; shown: true; silent: true; autoHideMs: 0; icon: "elytra"; description: "Sky's the Limit" }
                    McToast { kind: "challenge"; shown: true; silent: true; autoHideMs: 0; icon: "nether_star"; description: "Return to Sender" }
                    McToast { kind: "recipe"; shown: true; silent: true; autoHideMs: 0; icon: "bread"; title: "New Recipes Unlocked!"; description: "Check your recipe book" }
                    McToast { kind: "system"; shown: true; silent: true; autoHideMs: 0; title: "Battery low"; description: "12% left, plug in soon" }
                    McToast { kind: "tutorial"; shown: true; silent: true; autoHideMs: 0; iconSprite: "toast/tree"; title: "Punch a tree"; description: "Hold left click" }
                    McToast { kind: "now_playing"; shown: true; silent: true; autoHideMs: 0; icon: "music_disc_cat"; title: "Now Playing"; description: "C418 - cat" }
                    McToast { shown: true; silent: true; autoHideMs: 0; icon: "paper"; maxWidth: 240; title: "Long notification"; description: "A body long enough to wrap onto a second line of the frame" }
                }
                Head { text: "McAnimatedSprite, McSplash" }
                Row {
                    spacing: Theme.px(4)
                    McAnimatedSprite { sprite: "block/water_still"; tint: Theme.water }
                    McAnimatedSprite { sprite: "block/lava_still" }
                    McAnimatedSprite { sprite: "block/nether_portal" }
                    McAnimatedSprite { sprite: "block/fire_0" }
                    McAnimatedSprite { sprite: "block/magma" }
                    McAnimatedSprite { sprite: "misc/enchanted_glint_item"; scroll: true; width: Theme.px(16); height: Theme.px(16) }
                    McAnimatedSprite { sprite: "block/water_still"; tint: Theme.water; columns: 3; width: Theme.px(48); height: Theme.px(16) }
                    McItemIcon { name: "golden_apple"; glint: true }
                }
                Item {
                    width: Theme.px(300); height: Theme.px(40)
                    McSplash { x: Theme.px(70); y: Theme.px(20); text: "Also try Hyprland!" }
                    McSplash { x: Theme.px(200); y: Theme.px(20); text: "Short!" }
                }
            }
        }
    }

    Component {
        id: pageTwo
        Item {
            // left half: the in-world gradient screen with the pause menu
            Item {
                x: 0; y: 0; width: Theme.px(320); height: parent.height
                clip: true
                McScreen {
                    anchors.fill: parent
                    opened: true
                    title: "Game Menu"
                    titleY: 40
                    Column {
                        y: Theme.px(64)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.px(4)
                        McButton { text: "Back to Game"; wide: true; highlighted: true }
                        Row {
                            spacing: Theme.px(4)
                            McButton { text: "Advancements"; small: true }
                            McButton { text: "Statistics"; small: true }
                        }
                        Row {
                            spacing: Theme.px(4)
                            McButton { text: "Options..."; small: true }
                            McButton { text: "Open to LAN"; small: true; enabled: false }
                        }
                        McButton { text: "Save and Quit to Title"; wide: true }
                    }
                    McSlider { anchors.horizontalCenter: parent.horizontalCenter; y: Theme.px(190); label: "Master Volume"; value: 0.75; width: Theme.px(200) }
                }
            }
            // middle: dirt screen with a list and the list scrollbar
            Item {
                x: Theme.px(320); y: 0; width: Theme.px(320); height: parent.height
                clip: true
                McScreen {
                    anchors.fill: parent
                    opened: true
                    title: "Select World"
                    background: "menu"
                    Flickable {
                        id: worlds
                        x: Theme.px(10); y: Theme.px(33); width: parent.width - Theme.px(30); height: parent.height - Theme.px(66)
                        contentHeight: Theme.px(36) * 20
                        contentY: Theme.px(20)
                        clip: true
                        interactive: false
                        Column {
                            Repeater {
                                model: 20
                                Item {
                                    required property int index
                                    width: worlds.width; height: Theme.px(36)
                                    McItemIcon { x: Theme.px(2); y: Theme.px(2); name: "grass_block"; size: 32 }
                                    McText { x: Theme.px(36); y: Theme.px(1); text: "New World (" + index + ")"; color: Theme.hudText }
                                    McText { x: Theme.px(36); y: Theme.px(11); text: "Last played 05/11/2026"; color: Theme.tooltipDesc }
                                    McText { x: Theme.px(36); y: Theme.px(21); text: "Survival Mode"; color: Theme.chat["7"] }
                                }
                            }
                        }
                    }
                    McScrollbar { flickable: worlds; x: Theme.px(296); y: worlds.y; height: worlds.height }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - Theme.px(26)
                        spacing: Theme.px(4)
                        McButton { text: "Play Selected World"; small: true; width: Theme.px(150) }
                        McButton { text: "Cancel"; small: true }
                    }
                }
            }
            // right: type, legacy wrappers
            Column {
                x: Theme.px(646); y: Theme.px(4)
                spacing: Theme.px(2)
                width: Theme.px(308)
                Head { text: "McText" }
                Head { codes: "§aGreen §cRed §eYellow §bAqua §dPurple §6Gold §7Gray"; darkGround: true }
                Head { codes: "§lBold§r §oItalic§r §nUnderline§r §mStrike§r plain"; darkGround: true }
                McPanel {
                    width: Theme.px(306); height: Theme.px(44); padding: Theme.px(6)
                    Column {
                        McText { text: "Panel text, no shadow on light"; guiTitle: true }
                        McText { codes: "§aReadable §cchat §ecolours §bon this ground" }
                        McText { text: "Monocraft: F3 debug 0123 "; mono: true }
                    }
                }
                Head { text: "Now Playing: C418 - cat"; rainbow: true }
                Head { text: "Big /title text"; units: 3 }
                McOutlineText { text: "30" }
                McDivider { variant: "header"; width: parent.width }
                McDivider { variant: "footer"; width: parent.width }
                Head { text: "Legacy wrappers (DEPRECATED)" }
                PaperPanel {
                    width: Theme.px(150); height: Theme.px(50); title: "药"; subtitle: "PaperPanel"
                    Row {
                        spacing: Theme.px(3)
                        Seal { size: 24; glyph: "印" }
                        InkText { role: "small"; text: "InkText"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Row {
                    spacing: Theme.px(2)
                    InkButton { text: "InkButton"; icon: "" }
                    InkButton { text: "primary"; primary: true }
                    InkButton { text: "quiet"; quiet: true }
                }
                PaperBackground { width: Theme.px(100); height: Theme.px(24) }
                TitleBar { width: Theme.px(150); title: "TitleBar"; subtitle: "legacy" }
                InkDivider { width: Theme.px(150) }
                Head { text: "McPanel next to gui/demo_background (Day)" }
                Row {
                    spacing: Theme.px(4)
                    McPanel { objectName: "cmpPanel"; width: Theme.px(64); height: Theme.px(40); skin: "day" }
                    Item {
                        width: Theme.px(64); height: Theme.px(40)
                        clip: true
                        // the real 248×166 panel texture, top-left corner at the same scale (page 3 compares all of it)
                        Image {
                            source: Theme.tex("gui/demo_background")
                            transformOrigin: Item.TopLeft
                            scale: Theme.gui
                            smooth: false
                        }
                    }
                }
            }
        }
    }

    // Page 3: pixel comparison. McPanel (Day) sized like the game's 248×166 panel at (0,0) on black, for an offline compare with
    // gui/demo_background; a McNineSlice button at a width that forces tiling sits below it for the same check.
    Component {
        id: pageThree
        Rectangle {
            color: "#000000"
            McPanel { x: 0; y: 0; width: Theme.px(248); height: Theme.px(166); skin: "day" }
            McNineSlice { x: 0; y: Theme.px(170); sprite: "widget/button"; width: Theme.px(200); height: Theme.px(20) }
            McNineSlice { x: 0; y: Theme.px(192); sprite: "widget/button"; width: Theme.px(90); height: Theme.px(20) }

            readonly property bool placeTest: Quickshell.env("OW_SELFTEST") === "1"
            // Tooltip placement: no pointer is available here, so targets and coordinates are set from code.
            Rectangle { id: anchorRight; visible: placeTest; x: parent.width - Theme.px(20); y: Theme.px(200); width: Theme.px(16); height: Theme.px(16); color: "red" }
            McTooltip { id: tipRight; visible: placeTest; title: "Flips left at the window edge"; description: "Target at the right edge"; target: anchorRight; targetX: 8; targetY: 8 }
            Rectangle { id: anchorLeft; visible: placeTest; x: Theme.px(300); y: Theme.px(120); width: Theme.px(16); height: Theme.px(16); color: "red" }
            McTooltip { id: tipLeft; visible: placeTest; title: "Right of the pointer"; target: anchorLeft; targetX: 8; targetY: 8 }
            Rectangle { id: anchorTop; visible: placeTest; x: Theme.px(500); y: 0; width: Theme.px(16); height: Theme.px(16); color: "red" }
            McTooltip { id: tipTop; visible: placeTest; title: "Clamped to the top"; target: anchorTop; targetX: 8; targetY: 8 }
            Timer {
                running: Quickshell.env("OW_SELFTEST") === "1"
                interval: 200
                onTriggered: {
                    const check = (name, ok) => console.warn((ok ? "PASS " : "FAIL ") + name);
                    const root = anchorRight.Window.contentItem;
                    check("tooltip reparents to the window content item", tipRight.parent === root && tipLeft.parent === root);
                    check("tooltip flips left, 12 GUI px from the pointer", tipRight.x + tipRight.width - tipRight.margin === anchorRight.x + 8 - Theme.px(12));
                    check("tooltip stays inside the window", tipRight.x + tipRight.margin >= 0 && tipRight.x + tipRight.width - tipRight.margin <= root.width);
                    check("tooltip sits right of the pointer by default", tipLeft.x + tipLeft.margin === anchorLeft.x + 8 + Theme.px(12));
                    check("tooltip clamps to the top edge", tipTop.y + tipTop.margin >= 0);
                    check("tooltip follows targetX", (tipLeft.targetX = 16, tipLeft.x + tipLeft.margin === anchorLeft.x + 16 + Theme.px(12)));
                    check("tooltip draws above siblings", tipRight.z > anchorRight.z);
                    console.warn("TOOLTIP TEST DONE");
                }
            }
        }
    }

    // ---------------------------------------------------------------- logic self-test (OW_SELFTEST=1), no pointer needed
    Item {
        id: selftestHost
        visible: Quickshell.env("OW_SELFTEST") === "1"
        McButton { id: tBtn; soundId: ""; property int hits: 0; onClicked: hits++ }
        McButton { id: tBtnOff; soundId: ""; enabled: false; property int hits: 0; onClicked: hits++ }
        McToggle { id: tTog; soundId: ""; label: "X" }
        McCheckbox { id: tChk; soundId: "" }
        property bool storeVal: true      // a store the bound toggle/checkbox write through (like Options / WidgetsState)
        McToggle { id: tTogB; soundId: ""; label: "B"; checked: selftestHost.storeVal; onToggled: c => selftestHost.storeVal = c }
        McCheckbox { id: tChkB; soundId: ""; checked: selftestHost.storeVal; onToggled: c => selftestHost.storeVal = c }
        McSlider { id: tSl; soundId: ""; label: "V"; value: 0.5; stepSize: 0.25; property real seen: -1; onMoved: v => seen = v }
        McTextField { id: tTf; text: "abc" }
        McSlider { id: tDrag; soundId: ""; height: 20 }
        Flickable { id: tFlick; width: 10; height: 100; contentHeight: 400 }
        McScrollbar { id: tBar; flickable: tFlick; height: 100 }
        McTabs { id: tTabs; soundId: ""; tabs: [{ item: "compass" }, { item: "apple" }] }
        McToast { id: tToast; silent: true; autoHideMs: 60; property int gone: 0; onDismissed: gone++ }
        McScreen { id: tScr; property int shut: 0; onClosed: shut++ }
        HeartsRow { id: tHearts; value: 1 }
        McText { id: tTxt; codes: "§aA<b>§r&"; darkGround: true }
        McTicker { id: tTick; active: false }
        function check(name, ok) { console.warn((ok ? "PASS " : "FAIL ") + name); }
        Timer {
            running: selftestHost.visible
            interval: 300
            onTriggered: {
                const t = selftestHost;
                tBtn.activate(); t.check("button activate fires clicked", tBtn.hits === 1);
                tBtnOff.activate(); t.check("disabled button ignores activate", tBtnOff.hits === 0);
                tTog.activate(); t.check("toggle flips and prints ON", tTog.checked && tTog.text === "X: ON");
                tChk.toggle(); t.check("checkbox toggles", tChk.checked);
                tTogB.activate(); t.check("bound toggle writes false", t.storeVal === false && !tTogB.checked);
                t.storeVal = true; t.check("bound toggle still follows its store after a click", tTogB.checked && tChkB.checked);
                tChkB.toggle(); t.storeVal = true; t.check("bound checkbox still follows its store after a click", tChkB.checked);
                tSl._nudge(1); t.check("slider step + moved", tSl.value === 0.75 && tSl.seen === 0.75 && tSl.text === "V: 75%");
                t.check("§ parser escapes markup", tTxt.text.indexOf("&lt;b&gt;") >= 0 && tTxt.text.indexOf("#55ff55") >= 0);
                t.check("tex resolves mojang", Theme.tex("gui/sprites/hud/heart/full").indexOf("/assets/mc/textures/") >= 0);
                t.check("tex missing -> magenta", Theme.tex("gui/sprites/nope/nope") === Theme.missingTexture);
                t.check("spritePath roots", Theme.spritePath("widget/button") === "gui/sprites/widget/button" && Theme.spritePath("block/stone") === "block/stone");
                const m = Theme.spriteMeta("toast/system").scaling;
                t.check("mcmeta border object", m.type === "nine_slice" && m.border.left === 17 && m.border.top === 30);
                t.check("mcmeta border number", Theme.spriteMeta("widget/button").scaling.border.right === 3);
                t.check("mcmeta animation", Theme.spriteMeta("block/water_still").animation.frametime === 2);
                t.check("no mcmeta = stretch", Theme.spriteMeta("hud/heart/full").scaling.type === "stretch");
                t.check("px", Theme.px(9) === 9 * Theme.gui);
                const savedConfig = Theme.config;   // in memory only, nothing is written to config.json
                Theme.config = { widgets: { opacity: 0.5 } };
                t.check("widgetOpacity reads config widgets.opacity", Theme.widgetOpacity === 0.5);
                Theme.config = {};
                t.check("widgetOpacity default", Math.abs(Theme.widgetOpacity - 0.72) < 0.001);
                Theme.config = savedConfig;
                t.check("itemFor class key", Theme.itemFor("kitty") === "command_block" && Theme.itemFor("KITTY") === "command_block");
                t.check("itemFor title rule first", Theme.itemFor("kitty", "nvim notes.txt") === "writable_book" && Theme.itemFor("kitty", "hermes") === "enchanting_table");
                t.check("itemFor default", Theme.itemFor("no-such-app-xyz") === "stone");
                Theme.playSound("ui.click");   // dry run only: the self-test runs with OW_SOUND_DRYRUN=1 and config sounds:false
                t.check("chat table", Qt.colorEqual(Theme.chat.a, "#55FF55"));
                t.check("tooltip fill alpha", Math.abs(Theme.tooltipFill.a - 0xF0 / 255) < 0.01 && Qt.colorEqual(Qt.rgba(Theme.tooltipFill.r, Theme.tooltipFill.g, Theme.tooltipFill.b, 1), "#100010"));
                const held = Theme._tickUsers;
                tDrag.width = 100;
                tDrag._setFromX(8 * Theme.gui / 2 + (100 - 8 * Theme.gui) / 2);    // handle centre at mid-track
                t.check("slider drag maps x to value", Math.abs(tDrag.value - 0.5) < 0.01);
                tDrag._setFromX(-50); t.check("slider drag clamps low", tDrag.value === 0);
                tDrag._setFromX(5000); t.check("slider drag clamps high", tDrag.value === 1);
                tBar._setPos(0.5);
                t.check("scrollbar drives its flickable", Math.abs(tFlick.contentY - 150) < 1 && tBar.scrollable);
                tBar._setPos(9); t.check("scrollbar clamps", Math.abs(tFlick.contentY - 300) < 1);
                tTick.active = true;
                t.check("ticker acquires", Theme._tickUsers === held + 1);
                tTick.active = false;
                t.check("ticker releases", Theme._tickUsers === held);
                tScr.open(); t.check("screen opens", tScr.opened && tScr.visible);
                tScr.close();
                tToast.reveal();
                late.start();
            }
        }
        Timer {
            id: late
            interval: 1500
            onTriggered: {
                const t = selftestHost;
                t.check("toast auto-dismisses after its hold", tToast.gone === 1);
                t.check("screen closed signal after fade", tScr.shut === 1 && !tScr.visible);
                const a = Theme.tick;
                tTick.active = true;
                after.startTick = a;
                after.start();
            }
        }
        Timer {
            id: after
            property int startTick: 0
            interval: 500
            onTriggered: {
                const t = selftestHost;
                const n = Theme.tick - startTick;
                t.check("tick clock runs about 10 ticks in 500 ms (" + n + ")", n >= 7 && n <= 12);
                console.warn("SELFTEST DONE");
            }
        }
    }
}
