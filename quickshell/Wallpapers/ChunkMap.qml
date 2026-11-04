import QtQuick
import qs.Common

/*  ChunkMap — the coloured square on the game's "Generating world" screen: chunks fill in a spiral from the centre,
 *  from the far stages (dark grey, pale stone) to loaded terrain (green). progress: 0..1. Side 11 chunks at 3 GUI px each.
 */
Item {
    id: root
    property real progress: 0
    readonly property int side: 11
    readonly property int cell: Theme.px(3)
    readonly property var order: {
        const out = [];
        for (let y = 0; y < side; y++) for (let x = 0; x < side; x++) out.push({ x: x, y: y, d: Math.max(Math.abs(x - 5), Math.abs(y - 5)) + Math.atan2(y - 5, x - 5) / 10 });
        out.sort((a, b) => a.d - b.d);
        for (let i = 0; i < out.length; i++) out[i].rank = i / out.length;
        return out;
    }
    implicitWidth: side * cell
    implicitHeight: side * cell

    Repeater {
        model: root.order
        Rectangle {
            required property var modelData
            x: modelData.x * root.cell
            y: modelData.y * root.cell
            width: root.cell
            height: root.cell
            readonly property real done: root.progress * 1.15 - modelData.rank
            color: done > 0.12 ? "#7CBD6B" : done > 0.07 ? "#A08850" : done > 0.03 ? "#8F8F8F" : done > 0 ? "#555555" : "#202020"
        }
    }
}
