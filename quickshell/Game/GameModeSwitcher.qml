import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  GameModeSwitcher — the F3+F4 overlay: four slots (survival, creative, adventure, spectator), the chosen mode's name above.
 *  Keys: ←/→ or Tab/Shift+Tab move · 1–4 pick · Enter applies · Esc closes. Click a slot to apply. IPC: `gamemode switcher`.
 */
Variants {
    model: Quickshell.screens

    ScreenWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-gamemode"
        open: GameUi.switcherOpen
        onCloseRequested: GameUi.close("switcher")

        property int selected: GameMode.modes.indexOf(GameMode.mode)
        // switcher order of the game: creative, survival, adventure, spectator; ours keeps the contract order (survival first)
        onShownChanged: if (shown) selected = Math.max(0, GameMode.modes.indexOf(GameMode.mode))
        function apply(i) {
            GameMode.set(GameMode.modes[i]);
            GameUi.close("switcher");
        }
        function move(d) { selected = (selected + d + GameMode.modes.length) % GameMode.modes.length; Theme.playSound("ui.click"); }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) { win.move(1); event.accepted = true; }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) { win.move(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { win.apply(win.selected); event.accepted = true; }
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) { win.apply(event.key - Qt.Key_1); event.accepted = true; }
            }

            readonly property var info: GameMode.info(GameMode.modes[win.selected])
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - Theme.px(58)
                text: parent.info.name
                color: Theme.hudText
                units: 1
            }
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - Theme.px(47)
                text: parent.info.summary
                color: "#aaaaaa"
            }
            Row {
                id: slots
                anchors.centerIn: parent
                spacing: Theme.px(5)
                Repeater {
                    model: GameMode.modes
                    Item {
                        id: slot
                        required property string modelData
                        required property int index
                        readonly property bool current: index === win.selected
                        width: Theme.px(26); height: Theme.px(26)
                        McSprite { anchors.fill: parent; sprite: "gamemode_switcher/slot" }
                        McItemIcon { x: Theme.px(5); y: Theme.px(5); name: GameMode.info(slot.modelData).item }
                        McSprite { anchors.fill: parent; sprite: "gamemode_switcher/selection"; visible: slot.current }
                        Rectangle {   // the mode that is active right now keeps a small tick
                            visible: slot.modelData === GameMode.mode
                            x: Theme.px(19); y: Theme.px(19); width: Theme.px(5); height: Theme.px(5); color: Theme.xp
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: win.selected = slot.index
                            onClicked: win.apply(slot.index)
                        }
                    }
                }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + Theme.px(24)
                spacing: Theme.px(2)
                Repeater {
                    model: parent.parent.info.lines
                    McText { required property string modelData; anchors.horizontalCenter: parent.horizontalCenter; text: modelData; color: "#cccccc" }
                }
            }
            McText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 + Theme.px(60)
                text: "[ Left/Right ] Select    [ Enter ] Apply    [ Esc ] Close"
                color: "#aaaaaa"
            }
        }
    }
}
