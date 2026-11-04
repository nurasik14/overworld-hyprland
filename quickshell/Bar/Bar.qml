import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  Bar — 36 px top bar (DESIGN §7.1), one per screen, namespace overworld-bar.
 *  left: 猫 seal (launcher) · workspaces 一…十 · focused title    centre: HH:MM · 時辰 · date
 *  right: tray · wifi · bluetooth · battery · volume · mode toggle · bell · power
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar
        required property var modelData
        screen: modelData
        WlrLayershell.namespace: "overworld-bar"
        WlrLayershell.layer: WlrLayer.Top
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.sizes.bar_height || 36
        exclusiveZone: implicitHeight
        color: "transparent"

        readonly property real sideWidth: Math.max(leftRow.implicitWidth, rightRow.implicitWidth)

        Rectangle {   // bg0 @ 0.92 + hairline bottom
            anchors.fill: parent
            color: Theme.withAlpha(Theme.bg0, Theme.opacity.bar !== undefined ? Theme.opacity.bar : 0.92)
            Behavior on color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: Theme.hairline
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
        }

        // ---------------------------------------------------------------- left
        Row {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm

            Item {   // 猫 seal button → launcher
                id: catBtn
                width: 28; height: 28
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool hovered: catMouse.containsMouse
                Accessible.role: Accessible.Button
                Accessible.name: "Open the medicine cabinet (launcher)"
                Rectangle {
                    anchors.fill: parent; radius: Theme.radius.sm
                    color: Theme.inkWash; opacity: catBtn.hovered ? 0.7 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                }
                Seal {
                    anchors.centerIn: parent
                    size: 22; glyph: "猫"; label: "Launcher"; outline: false
                    scale: catMouse.pressed ? 0.92 : (ShellState.launcherOpen ? 1.08 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }
                }
                MouseArea {
                    id: catMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.toggle("launcher")
                }
                BarTooltip { target: catBtn; shown: catBtn.hovered; text: "薬櫃 · Medicine cabinet (Super+Space)" }
            }
            Workspaces { anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 1; height: 16; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
            InkText {
                role: "ui"
                text: HyprlandState.title.length ? HyprlandState.title : "— 後宮 · Rear Palace —"
                muted: HyprlandState.title.length === 0
                width: Math.min(implicitWidth, 420)
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontBody
            }
        }

        // ---------------------------------------------------------------- centre: clock
        Item {
            id: clockChip
            anchors.centerIn: parent
            width: clockRow.implicitWidth + Theme.space.md * 2
            height: 28
            readonly property bool hovered: clockMouse.containsMouse
            readonly property var sc: TimeService.current
            Accessible.role: Accessible.StaticText
            Accessible.name: TimeService.hhmm + " " + sc.name + " " + TimeService.dateLong
            Rectangle {
                anchors.fill: parent; radius: Theme.radius.sm
                color: Theme.inkWash; opacity: clockChip.hovered ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            }
            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: Theme.space.sm
                InkText { role: "clock_bar"; text: TimeService.hhmm; anchors.verticalCenter: parent.verticalCenter }
                InkText { role: "clock_bar"; text: "·"; muted: true; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: clockChip.sc.glyph
                    color: Theme.seal
                    font.family: Theme.fontDisplay
                    font.pixelSize: 17
                    renderType: Text.NativeRendering
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Theme.durTheme } }
                }
                Rectangle { width: 1; height: 12; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
                InkText { role: "small"; text: TimeService.dateLabel; muted: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true }
            BarTooltip {
                target: clockChip; shown: clockChip.hovered
                text: clockChip.sc.glyph + " · " + clockChip.sc.name + " · " + clockChip.sc.range + " · " + TimeService.dateLong
            }
        }

        // ---------------------------------------------------------------- right
        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Row {   // system tray
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                Repeater { model: SystemTray.items; TrayItem {} }
            }
            Rectangle {
                visible: SystemTray.items.values.length > 0
                width: 1; height: 16; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter
            }

            BarChip {   // Wi-Fi
                glyph: NetworkService.glyph
                text: NetworkService.connected ? NetworkService.activeSsid : (NetworkService.wiredConnected ? "wired" : "")
                glyphColor: NetworkService.connected || NetworkService.wiredConnected ? Theme.text : Theme.textMuted
                active: ShellState.networkOpen
                tooltip: !NetworkService.wifiEnabled ? "Wi-Fi off · open network panel (Super+N)"
                       : NetworkService.connected ? NetworkService.activeSsid + " · " + NetworkService.activeSignal + "% · Super+N"
                       : "Not connected · open network panel (Super+N)"
                onClicked: ShellState.toggle("network")
                anchors.verticalCenter: parent.verticalCenter
            }
            BarChip {   // Bluetooth
                id: btChip
                readonly property var adapter: Bluetooth.defaultAdapter
                readonly property bool btOn: adapter ? adapter.enabled : false
                readonly property int btConnected: Bluetooth.devices.values.filter(d => d.connected).length
                glyph: !adapter ? "󰂲" : (btConnected > 0 ? "󰂱" : (btOn ? "󰂯" : "󰂲"))
                glyphColor: btConnected > 0 ? Theme.accent : (btOn ? Theme.text : Theme.textMuted)
                text: btConnected > 0 ? String(btConnected) : ""
                tooltip: !adapter ? "No Bluetooth adapter" : (btOn ? ("Bluetooth on · " + btConnected + " connected · click: blueman") : "Bluetooth off · click: blueman")
                onClicked: Quickshell.execDetached(["sh", "-c", "command -v blueman-manager >/dev/null 2>&1 && exec blueman-manager"])
                anchors.verticalCenter: parent.verticalCenter
            }
            BarChip {   // Battery
                id: batChip
                readonly property var dev: UPower.displayDevice
                readonly property bool present: dev && dev.ready && dev.isLaptopBattery
                readonly property real pct: present ? dev.percentage : 1
                readonly property bool charging: present && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
                readonly property bool low: present && !charging && pct < 0.15
                visible: present
                glyph: charging ? "󰂄" : ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.max(0, Math.min(9, Math.round(pct * 10) - 1))]
                text: Math.round(pct * 100) + "%"
                glyphColor: low ? Theme.warning : Theme.text
                textColor: low ? Theme.warning : Theme.textMuted
                tooltip: !present ? "No battery" : (Math.round(pct * 100) + "% · " + (charging ? "charging" : "on battery")
                         + (dev.timeToEmpty > 0 && !charging ? " · " + Math.round(dev.timeToEmpty / 60) + " min left" : "")
                         + (dev.timeToFull > 0 && charging ? " · " + Math.round(dev.timeToFull / 60) + " min to full" : ""))
                anchors.verticalCenter: parent.verticalCenter
            }
            BarChip {   // Volume
                glyph: AudioService.volumeGlyph()
                text: AudioService.ready ? AudioService.percent + "%" : ""
                glyphColor: AudioService.muted ? Theme.textMuted : Theme.text
                tooltip: AudioService.muted ? "Muted · click to unmute · scroll to change" : ("Volume " + AudioService.percent + "% · click: mute · scroll: change")
                onClicked: AudioService.toggleMute()
                onWheel: d => AudioService.change(d * 0.05)
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle { width: 1; height: 16; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
            BarChip {   // Desktop widgets: click = menu (all + per card), middle-click = all on/off
                id: widgetsChip
                glyph: "󰕮"
                glyphColor: WidgetsState.visible ? Theme.text : Theme.textMuted
                active: widgetsMenu.open
                tooltip: widgetsMenu.open ? "" : ("Desk widgets · " + (WidgetsState.visible ? "shown" : "hidden") + " · click: choose cards · middle-click / Super+G: all")
                onClicked: ev => { if (ev.button === Qt.MiddleButton) WidgetsState.toggle(); else WidgetsState.menuOpen = !WidgetsState.menuOpen }
                anchors.verticalCenter: parent.verticalCenter
                WidgetsMenu { id: widgetsMenu; target: widgetsChip }
            }
            BarChip {   // Mode toggle
                glyph: Theme.isDark ? "󰖔" : "󰖙"
                glyphColor: Theme.isDark ? Theme.gold : Theme.accent2
                tooltip: Theme.isDark ? "后宫 · Inner Palace (dark) · click for 药屋 Overworld (light)" : "药屋 · Overworld (light) · click for 后宫 Inner Palace (dark)"
                onClicked: Theme.toggleMode()
                anchors.verticalCenter: parent.verticalCenter
            }
            BarChip {   // Bell
                id: bellChip
                glyph: NotificationService.dnd ? "󰂛" : "󰂚"
                glyphColor: NotificationService.dnd ? Theme.textMuted : Theme.text
                active: ShellState.notifCenterOpen
                tooltip: (NotificationService.dnd ? "Do not disturb · " : "") + NotificationService.unread + " unread · " + NotificationService.count + " notes (Super+I)"
                onClicked: ShellState.toggle("notifCenter")
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {   // unread badge
                    visible: NotificationService.unread > 0
                    anchors.right: parent.right; anchors.top: parent.top
                    anchors.rightMargin: 2; anchors.topMargin: 2
                    width: Math.max(12, badge.implicitWidth + 5); height: 12; radius: 2
                    color: Theme.seal
                    Text {
                        id: badge
                        anchors.centerIn: parent
                        text: NotificationService.unread > 99 ? "99" : String(NotificationService.unread)
                        color: Theme.textOnSeal
                        font.family: Theme.fontUi; font.pixelSize: 9; font.weight: 600
                        renderType: Text.NativeRendering
                    }
                }
            }
            BarChip {   // Power
                glyph: "󰐥"
                glyphColor: Theme.seal
                active: ShellState.powerOpen
                tooltip: "Power menu (Super+Escape)"
                onClicked: ShellState.toggle("power")
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
