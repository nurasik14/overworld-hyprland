import QtQuick
import qs.Common

/*  PixelGlyph — a tiny glyph drawn as 1 GUI px squares, so it stays crisp at every GUI scale and needs no font.
 *    kind: "check"  7 × 6 (the tick of the game's checkbox)     "cross"  7 × 7 (the ✕ remove button)
 *          "down" 7 × 4 / "right" 4 × 7 (fold arrows of a section header)
 *    color: color
 *  Used by the Projects card (checkbox tick, "Built" header, ✕ on a row) and its dialog.
 */
Item {
    id: root
    property string kind: "check"
    property color color: "white"
    readonly property var maps: ({
        check: { w: 7, h: 6, px: [[6, 0], [5, 1], [6, 1], [0, 2], [4, 2], [5, 2], [0, 3], [1, 3], [3, 3], [4, 3], [1, 4], [2, 4], [3, 4], [2, 5]] },
        down: { w: 7, h: 4, px: [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [2, 2], [3, 2], [4, 2], [3, 3]] },
        right: { w: 4, h: 7, px: [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5], [0, 6], [1, 1], [1, 2], [1, 3], [1, 4], [1, 5], [2, 2], [2, 3], [2, 4], [3, 3]] },
        cross: { w: 7, h: 7, px: [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6], [6, 0], [5, 1], [4, 2], [2, 4], [1, 5], [0, 6]] }
    })
    readonly property var m: maps[kind] || maps.check
    width: Theme.px(m.w)
    height: Theme.px(m.h)
    Repeater {
        model: root.m.px
        Rectangle {
            required property var modelData
            x: Theme.px(modelData[0]); y: Theme.px(modelData[1])
            width: Theme.gui; height: Theme.gui
            color: root.color
            antialiasing: false
        }
    }
}
