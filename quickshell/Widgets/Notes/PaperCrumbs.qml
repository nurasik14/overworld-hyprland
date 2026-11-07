import QtQuick
import qs.Common
import qs.Services

/*  PaperCrumbs — a tear-off's bits of paper: 12 GUI-pixel crumbs thrown from the sheet that fall under gravity, stepping 20 times a second like
 *  the game's item-break particles.  burst() does nothing with reduced motion or particles "minimal" ("decreased" = half as many).
 */
Item {
    id: root
    property color colorA: "#FCFCF2"
    property color colorB: "#AEAEAE"
    readonly property int life: 16
    property int age: -1
    property var crumbs: []
    readonly property int g: Theme.gui

    function burst() {
        if (Theme.reducedMotion || ConfigService.particles === "minimal") return;
        const n = ConfigService.particles === "decreased" ? 6 : 12, out = [];
        for (let i = 0; i < n; i++)
            out.push({ x: Math.random() * root.width, y: Math.random() * root.height * 0.7,
                       vx: (Math.random() - 0.5) * 2.4, vy: -0.6 - Math.random() * 1.8, size: Math.random() < 0.3 ? 2 : 1, b: i % 3 === 0 });
        root.crumbs = out;
        root.age = 0;
    }
    Timer {
        interval: 50                 // one game tick
        repeat: true
        running: root.age >= 0
        onTriggered: {
            root.age++;
            if (root.age >= root.life) { root.age = -1; root.crumbs = []; }
        }
    }
    Repeater {
        model: root.crumbs
        Rectangle {
            required property var modelData
            readonly property int a: Math.max(0, root.age)
            x: Math.round(modelData.x / root.g + modelData.vx * a) * root.g
            y: Math.round(modelData.y / root.g + modelData.vy * a + 0.12 * a * a) * root.g
            width: modelData.size * root.g; height: modelData.size * root.g
            color: modelData.b ? root.colorB : root.colorA
            opacity: a > root.life - 4 ? 0.5 : 1
        }
    }
}
