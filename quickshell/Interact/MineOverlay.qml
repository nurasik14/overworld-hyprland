import QtQuick
import qs.Common

/*  MineOverlay — the crack texture over the mined window: block/destroy_stage_<stage> tiled, exactly the window's rect. The tile
 *  is an integer multiple of 16 px, about a quarter of the window's short side (never below 16 px × GUI scale), so a big window
 *  reads as a wall of cracking blocks, not as a fine repeating pattern.
 */
Item {
    id: root
    property int stage: 0
    readonly property int texel: Math.max(Theme.gui, Math.floor(Math.min(width, height) / 4 / 16))
    McSprite {
        anchors.fill: parent
        scaleFactor: root.texel
        sprite: "block/destroy_stage_" + Math.max(0, Math.min(9, root.stage))
        scaling: ({ type: "tile", width: 16, height: 16 })
    }
}
