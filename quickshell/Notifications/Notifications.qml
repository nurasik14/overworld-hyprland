import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

/*  Notifications — toasts stacking down from the top-right corner, namespace overworld-notif. The daemon itself lives in
 *  Services/NotificationService. Like the game, at most what fits is drawn (5 here); the rest wait in the service, and
 *  every note stays in the notification centre. Hidden while the centre is open.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        WlrLayershell.namespace: "overworld-notif"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        implicitWidth: Theme.px(240)
        implicitHeight: Math.max(1, stack.implicitHeight)
        color: "transparent"
        readonly property var popups: NotificationService.popups.slice(0, 5)
        visible: popups.length > 0 && !ShellState.notifCenterOpen

        Column {
            id: stack
            width: parent.width
            spacing: 0
            move: Transition { NumberAnimation { properties: "y"; duration: Theme.ms(150); easing.type: Easing.OutQuad } }

            Repeater {
                model: win.popups
                NoteToast {
                    required property var modelData
                    note: modelData
                    width: stack.width
                    onCloseClicked: NotificationService.dismissPopup(modelData)
                }
            }
        }
    }
}
