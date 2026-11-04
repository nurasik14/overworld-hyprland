import QtQuick
import qs.Common

/*  FragmentBurst — a burst of small square particles inside an item the size of the effect rect.
 *    mode: "break"  fragments of the closed window: spawn all over the rect, fly outward and up, fall with gravity (~0.6 s)
 *          "dust"   the block-place puff: grey specks rise from the rect's lower edge and corners and fade (~0.5 s)
 *    palette: [ "rrggbb", … ]  colours sampled from the window (break); dust uses its own greys
 *    count: int     number of particles (already scaled by the particles setting)
 *  finished() fires once the last particle is gone. Square sizes are whole GUI pixels so every fragment stays crisp.
 */
Item {
    id: root
    property string mode: "break"
    property var palette: []
    property int count: 40
    signal finished()

    readonly property real gravity: mode === "break" ? Theme.px(1100) : -Theme.px(10)   // px/s²
    property var parts: []
    readonly property real maxLife: parts.reduce((m, p) => Math.max(m, p.life), 0)
    Component.onCompleted: parts = _make()
    property real t: 0

    function _rand(a, b) { return a + Math.random() * (b - a); }
    function _shade(hex, k) {
        const c = Qt.color("#" + hex);
        return Qt.rgba(Math.min(1, c.r * k), Math.min(1, c.g * k), Math.min(1, c.b * k), 1);
    }
    function _make() {
        const out = [], g = Theme.gui, w = width, h = height, cx = w / 2, cy = h / 2;
        const pal = palette && palette.length ? palette : ["7d7d7d", "6b6b6b", "8f8f8f"];
        for (let i = 0; i < count; i++) {
            if (mode === "break") {
                const x0 = _rand(0.04, 0.96) * w, y0 = _rand(0.04, 0.96) * h;
                const nx = (x0 - cx) / Math.max(1, cx), ny = (y0 - cy) / Math.max(1, cy);
                out.push({
                    x0: x0, y0: y0,
                    vx: nx * Theme.px(70) + _rand(-1, 1) * Theme.px(45),
                    vy: -Theme.px(_rand(30, 150)) + ny * Theme.px(35),
                    size: g * Math.round(_rand(2.5, 4.5 + Math.min(w, h) / 450)),
                    life: _rand(0.42, 0.62),
                    color: _shade(pal[Math.floor(Math.random() * pal.length)], _rand(0.65, 1.0))
                });
            } else {
                const edge = Math.random();             // mostly the lower edge, some of the sides
                let x0, y0;
                if (edge < 0.65) { x0 = _rand(0, 1) * w; y0 = h - _rand(0, g * 3); }
                else if (edge < 0.83) { x0 = _rand(-g * 2, g * 2); y0 = _rand(0.55, 1) * h; }
                else { x0 = w + _rand(-g * 2, g * 2); y0 = _rand(0.55, 1) * h; }
                const dir = (x0 - cx) / Math.max(1, cx);
                const grey = Math.round(_rand(150, 236));
                out.push({
                    x0: x0, y0: y0,
                    vx: dir * Theme.px(14) + _rand(-1, 1) * Theme.px(8),
                    vy: -Theme.px(_rand(8, 34)),
                    size: g * Math.round(_rand(2, 4.4)),
                    life: _rand(0.4, 0.7),
                    color: Qt.rgba(grey / 255, grey / 255, (grey - 6) / 255, 1)
                });
            }
        }
        return out;
    }

    FrameAnimation {
        running: true
        onTriggered: {
            root.t = elapsedTime / InteractFx.slow;
            if (root.t > root.maxLife + 0.02) { running = false; root.finished(); }
        }
    }

    Repeater {
        model: root.parts
        Rectangle {
            required property var modelData
            readonly property real tt: Math.min(root.t, modelData.life)
            readonly property real k: tt / modelData.life
            readonly property real fall: root.mode === "break" ? 0.5 * root.gravity * tt * tt : 0.5 * root.gravity * tt * tt
            x: Math.round((modelData.x0 + modelData.vx * tt) / Theme.gui) * Theme.gui
            y: Math.round((modelData.y0 + modelData.vy * tt + fall) / Theme.gui) * Theme.gui
            width: modelData.size
            height: modelData.size
            color: modelData.color
            opacity: root.mode === "break" ? (k < 0.7 ? 1 : 1 - (k - 0.7) / 0.3) : (k < 0.5 ? 0.95 : 0.95 * (1 - (k - 0.5) / 0.5))
            visible: root.t < modelData.life
            antialiasing: false
        }
    }
}
