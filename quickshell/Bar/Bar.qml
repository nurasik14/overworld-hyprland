import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

/*  Bar — the HUD, one per screen, namespace overworld-bar (layer top, bottom edge). It replaces Apothecary's top bar, and the
 *  numbers are the game's own (GUI px from the bottom):
 *    hotbar y-22 · XP bar y-29, level y-35 · hearts (battery) y-39 left · hunger (free RAM) y-39 right · air (CPU headroom) y-49 right
 *    item name y-59, fades after 2 s
 *  The flanks hold what the old bar held: launcher, widgets, window title on the left; tray, wifi, bluetooth, volume, day/night,
 *  bell, game menu, clock on the right.
 *  Reserves 40 GUI px (80 px at scale 2) of the bottom edge. The surface is taller, for tooltips and the item name; everything
 *  but the widgets is click-through (mask). Hidden in spectator mode and by `ipc call hud hide`.
 *  The air row is the only part drawn over windows: it stays small on purpose (see docs/QUICKSHELL.md for why air and not armour).
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: hud
        required property var modelData
        screen: modelData
        WlrLayershell.namespace: "overworld-bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { bottom: true; left: true; right: true }
        implicitHeight: Theme.px(150)
        exclusiveZone: ShellState.preview ? 0 : Theme.px(40)
        exclusionMode: ShellState.preview ? ExclusionMode.Ignore : ExclusionMode.Normal
        color: "transparent"
        visible: !ConfigService.isSpectator && !ShellState.hudHidden

        mask: Region {
            Region { item: hotbar }
            Region { item: stats }
            Region { item: leftFlank }
            Region { item: rightFlank }
            Region { item: clockText }
        }

        function showItemName(id) { itemName.reveal(id); }      // previews
        readonly property int centerX: Math.round(width / 2 / Theme.gui) * Theme.gui
        readonly property int hotbarLeft: centerX - Theme.px(91)
        readonly property bool warnings: !ConfigService.isCreative
        // Big GUI scales or a full tray: the clock moves above the slots rather than into the hotbar.
        readonly property bool clockStacked: rightFlank.implicitWidth + clockText.implicitWidth + Theme.px(6)
            > width - (centerX + Theme.px(91 + 29 + 4))

        // ------------------------------------------------------------ hotbar
        Hotbar {
            id: hotbar
            x: hud.centerX - Theme.px(91 + 29)
            anchors.bottom: parent.bottom
            onSwitched: id => itemName.reveal(id)
        }

        // ------------------------------------------------------------ item name above the hotbar
        McText {
            id: itemName
            property string label: ""
            property real alphaShown: 0
            anchors.horizontalCenter: hotbar.horizontalCenter
            y: hud.height - Theme.px(59) - Theme.gui
            text: label
            color: Theme.hudText
            opacity: alphaShown
            function reveal(id) {
                label = WorkspaceNotes.displayTitle(id);
                fade.stop();
                alphaShown = 1;
                fade.start();
            }
            SequentialAnimation {
                id: fade
                PauseAnimation { duration: (Theme.ticks.item_name_hold || 40) * 50 }
                NumberAnimation { target: itemName; property: "alphaShown"; to: 0; duration: Theme.ticksMs(Theme.ticks.item_name_fade || 10) }
            }
        }

        // ------------------------------------------------------------ hearts, hunger, air, XP
        Item {
            id: stats
            x: hud.hotbarLeft
            y: hud.height - Theme.px(49)
            width: Theme.px(182)
            height: Theme.px(25)

            McProgressBar {
                id: xpBar
                x: 0; y: Theme.px(20)
                width: parent.width
                value: SystemStats.levelProgress
            }
            McOutlineText {
                id: levelText
                visible: SystemStats.level > 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.px(13)
                text: String(SystemStats.level)
            }
            LevelSparkle { id: sparkle; anchors.centerIn: levelText }
            Connections {
                target: SystemStats
                function onLevelUp(level) { sparkle.play(); }
            }

            HeartsRow {
                id: hearts
                visible: SystemStats.batteryPresent
                x: 0; y: Theme.px(10)
                value: Math.round(SystemStats.batteryPct * 20) / 2
                regen: SystemStats.charging && !SystemStats.fullyCharged
                hardcore: hud.warnings && SystemStats.batteryPct <= 0.05
                jiggle: hud.warnings && SystemStats.discharging && SystemStats.batteryPct < 0.2
                blinking: SystemStats.batteryFlash
            }
            HungerRow {
                id: hunger
                x: parent.width - width; y: Theme.px(10)
                value: Math.round(SystemStats.memFree * 20) / 2
                shake: hud.warnings && SystemStats.swapHeavy
                hunger: hud.warnings && SystemStats.swapHeavy
            }
            AirRow {
                id: air
                x: parent.width - width; y: 0
                value: Math.round((1 - SystemStats.cpuLoad) * 20) / 2
            }

            StatHover {
                x: 0; y: Theme.px(10); width: hearts.width; height: Theme.px(9)
                enabled: SystemStats.batteryPresent
                title: "Health: " + SystemStats.percent + "%"
                description: (SystemStats.charging ? "Charging" : "On battery")
                    + (SystemStats.timeToEmpty > 0 && !SystemStats.charging ? "\n" + Math.round(SystemStats.timeToEmpty / 60) + " min left" : "")
                    + (SystemStats.timeToFull > 0 && SystemStats.charging ? "\n" + Math.round(SystemStats.timeToFull / 60) + " min to full" : "")
                category: "Battery"
            }
            StatHover {
                x: hunger.x; y: Theme.px(10); width: hunger.width; height: Theme.px(9)
                title: "Hunger: " + Math.round(SystemStats.memFree * 100) + "% free"
                description: Math.round(SystemStats.memAvailableMb / 102.4) / 10 + " of " + Math.round(SystemStats.memTotalMb / 102.4) / 10 + " GB available"
                    + (SystemStats.swapUsed > 0 ? "\nSwap " + Math.round(SystemStats.swapUsed * 100) + "% used" : "")
                category: "Memory"
            }
            StatHover {
                x: air.x; y: 0; width: air.width; height: Theme.px(9)
                title: "Air: " + Math.round((1 - SystemStats.cpuLoad) * 100) + "%"
                description: "CPU load " + Math.round(SystemStats.cpuLoad * 100) + "%"
                category: "Processor"
            }
            StatHover {
                x: 0; y: Theme.px(19); width: parent.width; height: Theme.px(6)
                title: "Level " + SystemStats.level
                description: "Uptime " + SystemStats.level + " h " + Math.floor(SystemStats.levelProgress * 60) + " min"
                category: "Experience"
            }
        }

        // ------------------------------------------------------------ left flank
        Row {
            id: leftFlank
            x: Theme.px(2)
            y: hud.height - Theme.px(20)
            spacing: 0

            HudSlot {
                item: "crafting_table"
                tooltip: "Crafting Table"
                tooltipDescription: "Open the creative inventory\nSuper+Space"
                tooltipCategory: "Launcher"
                highlighted: ShellState.launcherOpen
                onClicked: ShellState.toggle("launcher")
            }
            WidgetsChip { id: widgetsChip }

            Item { width: Theme.px(4); height: 1 }
            HudText {
                readonly property string title: HyprlandState.title
                readonly property int room: hud.hotbarLeft - Theme.px(29 + 10) - leftFlank.x - Theme.px(36 + 4)
                anchors.verticalCenter: parent.verticalCenter
                maxWidth: room
                icon: title.length && HyprlandState.appClass.length ? Theme.itemFor(HyprlandState.appClass, title) : ""
                text: title.length ? title : "Nothing in hand"
                dim: title.length === 0
            }
        }

        // ------------------------------------------------------------ right flank
        Row {
            id: rightFlank
            anchors.right: parent.right
            anchors.rightMargin: hud.clockStacked ? Theme.px(2) : Theme.px(6) + clockText.width
            y: hud.height - Theme.px(20)
            spacing: 0

            Repeater {
                model: SystemTrayModel.items
                TrayItem {}
            }
            Item { width: SystemTrayModel.count > 0 ? Theme.px(4) : 0; height: 1 }

            WifiChip {}
            BluetoothChip {}
            HudSlot {
                item: AudioService.muted ? "barrier" : "note_block"
                count: AudioService.ready && !AudioService.muted ? AudioService.percent : 1
                tooltip: AudioService.muted ? "Master Volume: OFF" : "Master Volume: " + AudioService.percent + "%"
                tooltipDescription: "Click: mute\nScroll: change"
                tooltipCategory: "Sound"
                onClicked: {
                    if (ShellState.preview) { console.warn("DRYRUN toggleMute"); return; }
                    AudioService.toggleMute();
                }
                onWheelMoved: d => {
                    if (ShellState.preview) { console.warn("DRYRUN volume", d); return; }
                    AudioService.change(d * 0.05);
                }
            }
            HudSlot {   // sun or moon: the mode toggle
                tooltip: Theme.isDark ? "Night" : "Day"
                tooltipDescription: Theme.isDark ? "Click for Day" : "Click for Night"
                tooltipCategory: "Time"
                onClicked: Theme.toggleMode()
                SunMoonIcon { x: Theme.gui; y: Theme.gui }
            }
            HudSlot {   // bell
                item: "bell"
                opacity: NotificationService.dnd ? 0.55 : 1
                count: NotificationService.unread
                highlighted: ShellState.notifCenterOpen
                tooltip: NotificationService.dnd ? "Difficulty: Peaceful" : "Notifications"
                tooltipDescription: NotificationService.unread + " unread, " + NotificationService.count + " in history\nSuper+I"
                tooltipCategory: "Chat"
                onClicked: ShellState.toggle("notifCenter")
                onMiddleClicked: NotificationService.toggleDnd()
            }
            HudSlot {   // game menu
                item: "oak_door"
                highlighted: ShellState.powerOpen
                tooltip: "Game Menu"
                tooltipDescription: "Lock, sleep, quit\nSuper+Escape"
                tooltipCategory: "Power"
                onClicked: ShellState.toggle("power")
            }

        }
        HudText {
            id: clockText
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(2)
            y: hud.height - Theme.px(hud.clockStacked ? 33 : 16)
            text: TimeService.mcClock
            hoverEnabled: true
            tooltip: TimeService.dateLong
            tooltipDescription: TimeService.phase + "\nDay " + TimeService.dayOfYear + " of the year"
            tooltipCategory: "Clock"
        }
    }
}
