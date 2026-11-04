import QtQuick
import qs.Common

/*  XpOrbs — "+1" and green experience orbs rising from the XP bar when a level is gained (event xp.levelup).
 *  Drawn as pixel orbs in three shades (like the experience_orb texture, which is not tintable), colour pulsing green ↔ yellow
 *  the way the game's orbs do. The item is the XP bar's rect; finished() when everything has faded.
 */
Item {
    id: root
    property int level: 0
    property int count: 14
    signal finished()

    property var orbs: []
    Component.onCompleted: orbs = _make()
    property real t: 0
    readonly property real life: 1.5

    function _make() {
        const out = [];
        for (let i = 0; i < count; i++) {
            out.push({
                x0: (0.04 + Math.random() * 0.92) * width,
                delay: Math.random() * 0.35,
                vy: Theme.px(18 + Math.random() * 26),        // px/s, decelerating
                sway: (Math.random() - 0.5) * Theme.px(26),
                phase: Math.random() * 6.28,
                big: Math.random() < 0.3 ? 3 : 2
            });
        }
        return out;
    }
    FrameAnimation {
        running: true
        onTriggered: { root.t = elapsedTime / InteractFx.slow; if (root.t > root.life + 0.4) { running = false; root.finished(); } }
    }

    Repeater {
        model: root.orbs
        Item {
            id: orb
            required property var modelData
            readonly property real age: Math.max(0, root.t - modelData.delay)
            readonly property real k: Math.min(1, age / (root.life - modelData.delay + 0.2))
            readonly property real hue: 0.5 * (Math.sin((root.t * 5 + modelData.phase)) + 1)
            readonly property color core: Qt.rgba(0.5 + 0.5 * hue, 1, 0.12, 1)       // #80FF20 … #FFFF20
            readonly property int u: modelData.big * Theme.gui
            visible: root.t >= modelData.delay && k < 1
            opacity: k < 0.65 ? 1 : 1 - (k - 0.65) / 0.35
            x: Math.round((modelData.x0 + Math.sin(age * 4 + modelData.phase) * modelData.sway * 0.5) / Theme.gui) * Theme.gui
            y: -Math.round((modelData.vy * age * (1.4 - 0.5 * k)) / Theme.gui) * Theme.gui - Theme.px(2)
            width: u * 3; height: u * 3
            Rectangle { x: orb.u; y: 0; width: orb.u; height: orb.u * 3; color: Qt.darker(orb.core, 1.9); opacity: 0.8 }
            Rectangle { x: 0; y: orb.u; width: orb.u * 3; height: orb.u; color: Qt.darker(orb.core, 1.9); opacity: 0.8 }
            Rectangle { x: orb.u / 2; y: orb.u / 2; width: orb.u * 2; height: orb.u * 2; color: orb.core }
            Rectangle { x: orb.u; y: orb.u; width: orb.u; height: orb.u; color: Qt.lighter(orb.core, 1.7) }
        }
    }

    McOutlineText {   // the "+1", floating up from the level number
        id: plus
        readonly property real k: Math.min(1, root.t / 1.2)
        text: "+1"
        color: "#55ff55"
        x: Math.round((root.width - width) / 2 / Theme.gui) * Theme.gui
        y: -Theme.px(12) - Math.round(k * Theme.px(18) / Theme.gui) * Theme.gui
        opacity: k < 0.6 ? 1 : 1 - (k - 0.6) / 0.4
        visible: root.t < 1.2
    }
}
