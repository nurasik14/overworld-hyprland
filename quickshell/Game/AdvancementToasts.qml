import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  AdvancementToasts — layer `overworld-advtoast`: the game's advancement / goal / challenge toasts, top-right, stacked (max 4).
 *  Sits one notification-toast width (240 GUI px) to the left of the notification toasts so the two stacks never overlap.
 *  Sounds: McToast.reveal() plays ui.toast.in, or ui.toast.challenge for a challenge (and ui.toast.out when it leaves).
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property bool onFocusedScreen: !Hyprland.focusedMonitor || !win.screen || Hyprland.focusedMonitor.name === win.screen.name
        property var queue: []
        property int active: 0

        WlrLayershell.namespace: "overworld-advtoast"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins { top: Theme.px(2); right: NotificationService.popups.length > 0 ? Theme.px(246) : Theme.px(2) }
        implicitWidth: Theme.px(250)
        implicitHeight: Theme.px(4 * 44)
        color: "transparent"
        visible: active > 0
        mask: Region { x: 0; y: 0; width: 0; height: 0 }

        function enqueue(adv) {
            if (!win.onFocusedScreen) return;
            win.queue = win.queue.concat([adv]);
            pump();
        }
        function pump() {
            while (win.queue.length > 0 && win.active < 4) {
                const adv = win.queue[0];
                win.queue = win.queue.slice(1);
                win.active++;
                toastComponent.createObject(stack, { adv: adv });
            }
        }
        Connections {
            target: Advancements
            function onAdvancementUnlocked(adv, silent) { if (!silent) win.enqueue(adv); }
        }
        Column {
            id: stack
            anchors { top: parent.top; right: parent.right }
            spacing: Theme.px(2)
        }
        Component {
            id: toastComponent
            McToast {
                id: toast
                required property var adv
                kind: adv.frame === "challenge" ? "challenge" : adv.frame === "goal" ? "goal" : "advancement"
                description: adv.title
                iconSource: Advancements.iconUrl(adv.icon)
                maxWidth: 250
                Component.onCompleted: reveal()
                onDismissed: { win.active--; destroy(); win.pump(); }
            }
        }
    }
}
