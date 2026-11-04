import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  OptionsScreen — layer `overworld-options` (IPC `options open|page <name>`): the game's Options menu on config.json.
 *    main:  Widget Opacity · Difficulty (Peaceful = Do Not Disturb) · Video Settings… · Music & Sounds… · Controls… · Accessibility… · Time of Day · Game Mode
 *    video: GUI Scale (applies live) · Animations · Particles · Weather Effects · Day/Night cycle · Widget Opacity
 *    sounds: master + ui + toasts + blocks + ambient · Sounds ON/OFF       controls: live `hyprctl binds -j` table (read-only)
 *    access: Reduced Motion · Animations · GUI Scale
 *  Esc / Done: back one page, then close. Every change is written to config.json at once (scripts/game/set-config.sh) and read back
 *  by Theme / ConfigService / ow-sound / fx-world (key list: Options.qml, docs/GAMEPLAY.md).
 */
Variants {
    model: Quickshell.screens

    ScreenWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-options"
        open: GameUi.optionsOpen
        titleY: 15
        title: ({ main: "Options", video: "Video Settings", sounds: "Music & Sounds", controls: "Controls", access: "Accessibility Settings" })[page]
        onCloseRequested: win.back()

        property string page: GameUi.optionsPage
        function back() {
            if (page !== "main") { GameUi.optionsPage = "main"; Theme.playSound("ui.click"); }
            else GameUi.close("options");
        }
        function go(p) { GameUi.optionsPage = p; }
        onShownChanged: if (shown && page === "controls") binds.load()
        onPageChanged: if (shown && page === "controls") binds.load()

        // ------------------------------------------------------------ value helpers
        readonly property var guiOrder: ["auto", 1, 2, 3, 4]
        readonly property var guiNow: { const r = Options.revision; const v = Options.get("gui_scale", Theme.gui); return v; }
        function guiLabel(v) { return v === "auto" ? "Auto" : String(v); }
        function guiNext() {
            const i = guiOrder.findIndex(x => x === guiNow);
            Options.set("gui_scale", guiOrder[(i + 1) % guiOrder.length]);
        }
        readonly property var particleOrder: ["all", "decreased", "minimal"]
        readonly property string particlesNow: Options.get("particles", "all")
        function particlesNext() { Options.set("particles", particleOrder[(Math.max(0, particleOrder.indexOf(particlesNow)) + 1) % 3]); }
        readonly property var cycleOrder: ["auto", "day", "night"]
        readonly property string cycleNow: Options.get("daycycle", "auto")
        function cycleNext() { ChatService.setTime(cycleOrder[(Math.max(0, cycleOrder.indexOf(cycleNow)) + 1) % 3]); }
        function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

        BindsModel { id: binds }
        readonly property int pageRows: ({ main: 4, video: 3, sounds: 3, access: 2, controls: 0 })[page]
        readonly property real baseY: Math.max(Theme.px(40), win.height / 6 - Theme.px(12))

        component OptButton: McButton { }
        component Grid2: Grid { columns: 2; columnSpacing: Theme.px(4); rowSpacing: Theme.px(4) }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (win.page === "controls") {
                    if (event.key === Qt.Key_Down) { bindList.contentY = Math.min(Math.max(0, bindList.contentHeight - bindList.height), bindList.contentY + Theme.px(20)); event.accepted = true; }
                    else if (event.key === Qt.Key_Up) { bindList.contentY = Math.max(0, bindList.contentY - Theme.px(20)); event.accepted = true; }
                    else if (event.key === Qt.Key_PageDown) { bindList.contentY = Math.min(Math.max(0, bindList.contentHeight - bindList.height), bindList.contentY + bindList.height); event.accepted = true; }
                    else if (event.key === Qt.Key_PageUp) { bindList.contentY = Math.max(0, bindList.contentY - bindList.height); event.accepted = true; }
                }
            }

            // ---------------------------------------------------------- main
            Grid2 {
                visible: win.page === "main"
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.baseY
                OptSlider { width: Theme.px(150); height: Theme.px(20); key: "widgets.opacity"; dflt: 0.72; scale: 1; minimum: 0.3; offAt0: false; labelText: "Widget Opacity" }
                McButton {
                    text: "Difficulty: " + (NotificationService.dnd ? "Peaceful" : "Normal")
                    tooltip: "Difficulty"; tooltipDescription: "Peaceful silences notifications (Do Not Disturb)."
                    onClicked: NotificationService.toggleDnd()
                }
                McButton { text: "Music & Sounds..."; onClicked: win.go("sounds") }
                McButton { text: "Video Settings..."; onClicked: win.go("video") }
                McButton { text: "Controls..."; onClicked: win.go("controls") }
                McButton { text: "Accessibility Settings..."; onClicked: win.go("access") }
                McButton { text: "Time of Day: " + win.cap(win.cycleNow); onClicked: win.cycleNext()
                           tooltip: "Day / Night"; tooltipDescription: "Auto follows the sun; Day and Night pin the theme." }
                McButton { text: "Game Mode: " + GameMode.info(GameMode.mode).name.replace(" Mode", ""); onClicked: { GameUi.close("options"); GameUi.open("switcher"); } }
            }

            // ---------------------------------------------------------- video
            Grid2 {
                visible: win.page === "video"
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.baseY
                McButton { text: "GUI Scale: " + win.guiLabel(win.guiNow); onClicked: win.guiNext()
                           tooltip: "GUI Scale"; tooltipDescription: "Size of every menu and HUD element. Applies at once." }
                McToggle { label: "Animations"; checked: Options.get("animations", true) !== false; onToggled: c => Options.set("animations", c) }
                McButton { text: "Particles: " + win.cap(win.particlesNow); onClicked: win.particlesNext()
                           tooltip: "Particles"; tooltipDescription: "Block break dust, XP sparkles, rain splashes." }
                McToggle { label: "Weather Effects"; checked: Options.get("weather_effects", true) !== false; onToggled: c => Options.set("weather_effects", c) }
                McButton { text: "Day/Night Cycle: " + win.cap(win.cycleNow); onClicked: win.cycleNext() }
                OptSlider { width: Theme.px(150); height: Theme.px(20); key: "widgets.opacity"; dflt: 0.72; scale: 1; minimum: 0.3; offAt0: false; labelText: "Widget Opacity" }
            }

            // ---------------------------------------------------------- sounds
            Grid2 {
                visible: win.page === "sounds"
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.baseY
                OptSlider { width: Theme.px(150); height: Theme.px(20); key: "sound_volume.master"; labelText: "Master Volume" }
                McToggle { label: "Sounds"; checked: Options.get("sounds", true) !== false; onToggled: c => Options.set("sounds", c) }
                OptSlider { width: Theme.px(150); height: Theme.px(20); key: "sound_volume.ui"; labelText: "Interface" }
                OptSlider { width: Theme.px(150); height: Theme.px(20); key: "sound_volume.toasts"; labelText: "Toasts" }
                OptSlider { width: Theme.px(150); height: Theme.px(20); key: "sound_volume.blocks"; labelText: "Blocks" }
                OptSlider { width: Theme.px(150); height: Theme.px(20); key: "sound_volume.ambient"; labelText: "Ambient" }
            }

            // ---------------------------------------------------------- accessibility
            Grid2 {
                visible: win.page === "access"
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.baseY
                McToggle { label: "Reduced Motion"; checked: Options.get("reduced_motion", false) === true; onToggled: c => Options.set("reduced_motion", c)
                           tooltip: "Reduced Motion"; tooltipDescription: "Stops sprite animation, jiggling and fades." }
                McToggle { label: "Animations"; checked: Options.get("animations", true) !== false; onToggled: c => Options.set("animations", c) }
                McButton { text: "GUI Scale: " + win.guiLabel(win.guiNow); onClicked: win.guiNext() }
                McToggle { label: "Sounds"; checked: Options.get("sounds", true) !== false; onToggled: c => Options.set("sounds", c) }
            }

            // ---------------------------------------------------------- controls (read-only)
            Item {
                visible: win.page === "controls"
                anchors.fill: parent
                McText {
                    anchors.horizontalCenter: parent.horizontalCenter; y: Theme.px(34)
                    text: binds.error.length ? binds.error : binds.rows.length + " keybinds (read-only, from Hyprland)"
                    color: binds.error.length ? "#ff5555" : "#aaaaaa"
                }
                Flickable {
                    id: bindList
                    x: (parent.width - Theme.px(360)) / 2; y: Theme.px(48)
                    width: Theme.px(360); height: parent.height - Theme.px(48 + 36)
                    clip: true
                    contentWidth: width; contentHeight: bindCol.height
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: bindCol
                        width: bindList.width
                        Repeater {
                            model: binds.rows
                            Rectangle {
                                id: brow
                                required property var modelData
                                required property int index
                                width: bindCol.width; height: Theme.px(14)
                                color: index % 2 === 0 ? "#30000000" : "transparent"
                                McText { x: Theme.px(4); anchors.verticalCenter: parent.verticalCenter; text: brow.modelData.keys; color: brow.modelData.mine ? "#ffff55" : "#ffffff"; width: Theme.px(150); elide: Text.ElideRight }
                                McText { x: Theme.px(158); anchors.verticalCenter: parent.verticalCenter; text: brow.modelData.action; color: "#cccccc"; width: parent.width - Theme.px(162); elide: Text.ElideRight }
                            }
                        }
                    }
                }
                McScrollbar { visible: scrollable; flickable: bindList; anchors { left: bindList.right; top: bindList.top; bottom: bindList.bottom; leftMargin: Theme.px(2) } }
            }

            McButton {
                id: done
                wide: true
                text: "Done"
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.page === "controls" ? parent.height - Theme.px(34) : win.baseY + Theme.px(24 * win.pageRows + 12)
                onClicked: win.back()
            }
        }
    }
}
