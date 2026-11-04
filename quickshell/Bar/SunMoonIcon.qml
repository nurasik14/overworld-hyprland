import QtQuick
import qs.Common

// The mode toggle's icon, 16 GUI px: a blocky sun by day, a crescent moon at night. Own pixel art: the game's sun and moon textures have
// an opaque black ground meant for additive blending in the sky, which a slot cannot do.
Item {
    id: root
    width: Theme.px(16); height: Theme.px(16)
    readonly property var sun: [
        [5, 1, 6, 1, "#FFC81E"], [3, 2, 10, 2, "#FFC81E"], [2, 3, 12, 10, "#FFC81E"], [1, 5, 14, 6, "#FFC81E"], [3, 13, 10, 1, "#FFC81E"], [5, 14, 6, 1, "#FFC81E"],
        [4, 4, 8, 8, "#FFE85A"], [5, 5, 4, 4, "#FFF8C0"]
    ]
    readonly property var moon: [
        [6, 2, 5, 1, "#DCE0F0"], [4, 3, 5, 1, "#DCE0F0"], [3, 4, 5, 2, "#DCE0F0"], [2, 6, 5, 4, "#DCE0F0"], [3, 10, 6, 1, "#DCE0F0"],
        [3, 11, 9, 1, "#DCE0F0"], [4, 12, 8, 1, "#DCE0F0"], [6, 13, 5, 1, "#DCE0F0"], [4, 6, 2, 2, "#AEB4CC"], [5, 10, 2, 1, "#AEB4CC"]
    ]
    Repeater {
        model: Theme.isDark ? root.moon : root.sun
        Rectangle {
            required property var modelData
            x: Theme.px(modelData[0]); y: Theme.px(modelData[1])
            width: Theme.px(modelData[2]); height: Theme.px(modelData[3])
            color: modelData[4]
        }
    }
}
