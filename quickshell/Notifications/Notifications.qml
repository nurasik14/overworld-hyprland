import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

/*  Notifications — paper-note popups, top-right under the bar (DESIGN §6.4), namespace overworld-notif.
 *  The daemon itself lives in Services/NotificationService (NotificationServer).  Notes enter from the right (16 px + fade,
 *  ink 350 ms), leave in 160 ms; the stack re-flows with drift.  Hidden entirely while the notification centre is open.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        WlrLayershell.namespace: "overworld-notif"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Normal
        anchors { top: true; right: true }
        margins.top: Theme.space.lg
        margins.right: Theme.space.margin
        implicitWidth: 340 + 4
        implicitHeight: Math.max(1, stack.implicitHeight + 8)
        color: "transparent"
        readonly property var popups: NotificationService.popups
        visible: popups.length > 0 && !ShellState.notifCenterOpen

        Column {
            id: stack
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.rightMargin: 4
            spacing: Theme.space.md
            move: Transition { NumberAnimation { properties: "y"; duration: Theme.durBase; easing.type: Theme.easeDrift } }

            Repeater {
                model: win.popups
                Item {
                    id: slot
                    required property var modelData
                    width: stack.width
                    height: card.implicitHeight
                    NoteCard {
                        id: card
                        note: slot.modelData
                        width: parent.width
                        opacity: 0
                        transform: Translate { id: slide; x: 16 }
                        onCloseClicked: NotificationService.dismissPopup(slot.modelData)
                        Component.onCompleted: enter.start()
                        ParallelAnimation {
                            id: enter
                            NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.durBase; easing.type: Theme.easeInk }
                            NumberAnimation { target: slide; property: "x"; to: 0; duration: Theme.durBase; easing.type: Theme.easeInk }
                        }
                        ParallelAnimation {
                            id: leave
                            NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.durFast; easing.type: Theme.easeBrush }
                            NumberAnimation { target: slide; property: "x"; to: 16; duration: Theme.durFast; easing.type: Theme.easeBrush }
                        }
                        Connections {
                            target: slot.modelData
                            function onClosingChanged() { if (slot.modelData.closing) { enter.stop(); leave.start(); } }
                        }
                    }
                }
            }
        }
    }
}
