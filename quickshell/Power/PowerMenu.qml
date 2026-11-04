import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  PowerMenu — five hanging scrolls (DESIGN §7.4).  SUPER+Escape · `ipc call power toggle`, namespace overworld-power.
 *  锁 Lock → hyprlock · 出 Logout → hyprctl dispatch exit · 眠 Suspend → systemctl suspend · 启 Reboot · 关 Shutdown
 *  Keys: ←/→ move · Enter activates (destructive ones need a second Enter on the 印 Confirm seal) · Esc closes.
 */
Variants {
    model: Quickshell.screens

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-power"
        open: ShellState.powerOpen
        onCloseRequested: ShellState.close("power")

        readonly property var actions: [
            { glyph: "锁", name: "Lock",     key: "L", cmd: ["hyprlock"],                        confirm: false },
            { glyph: "出", name: "Logout",   key: "O", cmd: ["hyprctl", "dispatch", "exit"],     confirm: true },
            { glyph: "眠", name: "Suspend",  key: "S", cmd: ["systemctl", "suspend"],            confirm: false },
            { glyph: "启", name: "Reboot",   key: "R", cmd: ["systemctl", "reboot"],             confirm: true },
            { glyph: "关", name: "Shutdown", key: "P", cmd: ["systemctl", "poweroff"],           confirm: true }
        ]
        property int selected: 0
        property int confirming: -1      // index awaiting its second Enter

        onShownChanged: if (shown) { win.selected = 0; win.confirming = -1; }

        function activate(i) {
            const a = win.actions[i];
            if (!a) return;
            if (a.confirm && win.confirming !== i) { win.confirming = i; win.selected = i; return; }
            SoundService.play("seal");
            Quickshell.execDetached(a.cmd);
            ShellState.close("power");
        }
        function move(d) {
            win.selected = (win.selected + d + win.actions.length) % win.actions.length;
            win.confirming = -1;
        }

        Item {
            focus: true
            Keys.onPressed: event => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { win.move(-1); event.accepted = true; }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) { win.move(1); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { win.activate(win.selected); event.accepted = true; }
            else {
                const t = event.text.toUpperCase();
                for (let i = 0; i < win.actions.length; i++) if (win.actions[i].key === t) { win.selected = i; win.activate(i); event.accepted = true; }
            }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Theme.space.xl
            opacity: win.progress
            transform: Translate { y: (1 - win.progress) * 12 }

            Repeater {
                model: win.actions
                Item {
                    id: scroll
                    required property var modelData
                    required property int index
                    readonly property bool current: win.selected === index
                    readonly property bool armed: win.confirming === index
                    width: 140; height: 360 + 16
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name

                    Item {
                        id: body
                        width: parent.width; height: 360
                        y: scroll.current ? 8 : 0
                        Behavior on y { NumberAnimation { duration: Theme.durBase; easing.type: Theme.easeDrift } }

                        Rectangle {   // shadow
                            anchors.fill: paper; anchors.topMargin: 6
                            radius: 3; color: Theme.shadowStrong
                            opacity: scroll.current ? 1 : 0.5
                        }
                        Rectangle {   // top roller
                            width: parent.width + 8; height: 8; x: -4; y: 0; radius: 4
                            color: Theme.woodDark
                        }
                        Rectangle {   // bottom roller
                            width: parent.width + 8; height: 8; x: -4; anchors.bottom: parent.bottom; radius: 4
                            color: Theme.woodDark
                        }
                        Rectangle {
                            id: paper
                            anchors.fill: parent
                            anchors.topMargin: 6; anchors.bottomMargin: 6
                            color: Theme.surface
                            border.width: Theme.border.frame
                            border.color: scroll.armed ? Theme.seal : Theme.frame
                            Behavior on color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
                            Item {
                                anchors.fill: parent; anchors.margins: 2; clip: true
                                Image { anchors.fill: parent; source: Theme.texture("ground-tile"); fillMode: Image.Tile; opacity: Theme.textureOpacity; smooth: false; asynchronous: true }
                            }
                            Rectangle { anchors.fill: parent; anchors.margins: 6; color: "transparent"; border.width: 1; border.color: Theme.hairline }
                            Rectangle {   // hover / selected wash
                                anchors.fill: parent; anchors.margins: 2
                                color: Theme.inkWash
                                opacity: scroll.current ? 0.8 : (mouse.containsMouse ? 0.5 : 0)
                                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                            }
                            Column {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -24
                                spacing: Theme.space.md
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: scroll.modelData.glyph
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: 56
                                    color: scroll.armed ? Theme.seal : Theme.text
                                    renderType: Text.NativeRendering
                                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: scroll.modelData.name
                                    font.family: Theme.fontSerif
                                    font.pixelSize: 14; font.weight: 600
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: 1.5
                                    color: Theme.text
                                    renderType: Text.NativeRendering
                                }
                                InkText { anchors.horizontalCenter: parent.horizontalCenter; role: "small"; muted: true; text: "key " + scroll.modelData.key }
                            }
                            // confirm seal / selection seal at the bottom
                            Item {
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 22
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 96; height: 40
                                InkButton {
                                    anchors.centerIn: parent
                                    visible: scroll.armed
                                    primary: true
                                    text: "Confirm"
                                    icon: "印"
                                    tooltip: "Confirm " + scroll.modelData.name
                                    onClicked: win.activate(scroll.index)
                                    scale: scroll.armed ? 1 : 1.15
                                    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeDrift } }
                                }
                                Seal {
                                    anchors.centerIn: parent
                                    visible: !scroll.armed
                                    size: 24; glyph: "印"; label: scroll.modelData.name
                                    opacity: scroll.current || mouse.containsMouse ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                                }
                            }
                            InkText {
                                visible: scroll.armed
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                role: "small"; text: "press again to confirm"; color: Theme.error
                            }
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.selected = scroll.index
                            onClicked: win.activate(scroll.index)
                        }
                    }
                }
            }
        }
        InkText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 120
            role: "small"; muted: true
            opacity: win.progress
            text: "←→ move · ⏎ select · esc close · L O S R P"
        }
    }
}
