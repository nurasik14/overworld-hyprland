import QtQuick
import qs.Common

/*  MineOverlay — the crack texture over the mined window: block/destroy_stage_<stage> tiled at 16 px × GUI scale, exactly the
 *  window's rect. A faint dark veil grows with the stage so the cracks stay readable on bright windows.
 */
Item {
    id: root
    property int stage: 0
    McSprite {
        anchors.fill: parent
        sprite: "block/destroy_stage_" + Math.max(0, Math.min(9, root.stage))
        scaling: ({ type: "tile", width: 16, height: 16 })
    }
}
