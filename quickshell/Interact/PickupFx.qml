import QtQuick
import qs.Common

/*  PickupFx — the item-pickup pop: the item hops up in the middle of the screen, then flies down into the hotbar and shrinks
 *  (like an item entity being collected). Used for a saved screenshot (filled_map). The item is the whole output.
 */
Item {
    id: root
    property string item: "filled_map"
    property real targetY: height - Theme.px(11)      // the hotbar
    signal finished()
    property real t: 0
    readonly property real hop: 0.22
    readonly property real fly: 0.28

    FrameAnimation {
        running: true
        onTriggered: { root.t = elapsedTime / InteractFx.slow; if (root.t > root.hop + root.fly) { running = false; root.finished(); } }
    }
    McItemIcon {
        id: icon
        name: root.item
        size: 16
        readonly property real kf: Math.max(0, Math.min(1, (root.t - root.hop) / root.fly))
        readonly property real kh: Math.min(1, root.t / root.hop)
        scale: 1.5 - kf * 1.1
        transformOrigin: Item.Center
        x: Math.round((root.width / 2 - width / 2) / Theme.gui) * Theme.gui
        y: Math.round((root.height * 0.42 - Theme.px(10) * Math.sin(kh * Math.PI / 2)
                       + (root.targetY - root.height * 0.42) * kf * kf) / Theme.gui) * Theme.gui
        opacity: kf < 0.85 ? 1 : 1 - (kf - 0.85) / 0.15
    }
}
