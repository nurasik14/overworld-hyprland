import QtQuick
import qs.Common

/*  PaperSheet — one sheet of Minecraft Paper, drawn in GUI pixels from the paper item's palette (item/paper: #FCFCF2 face, #E9EAEB /
 *  #D6D6D6 shades, #AEAEAE edge, #878787 outline), warmed a little towards cream.  Perforated top edge (torn off a pad), a folded corner, a red pin at the top,
 *  faint fibres, and a hard 1 GUI px shadow.  Night dims the paper as if by moonlight.  The Notes card and the editor layer both draw it, so typing
 *  happens on the same sheet.  Children go on top of the paper; keep clear of `fold` at the bottom right.
 *    fillAlpha: real    translucency of the paper face (the card follows the widget opacity, with a floor so ink stays readable)
 *    fold: int          folded corner size in GUI px (a multiple of 2)
 *    behind: int        sheets of the pad peeking out behind this one, 0–2 (draws outside width/height, 2 GUI px each)
 *    pinned: bool       draw the pin
 *    seed: int          where the fibres fall
 *  Read-only for what is written on it: ink, inkMuted.
 */
Item {
    id: sheet
    property real fillAlpha: 1
    property int fold: 10
    property int behind: 0
    property bool pinned: true
    property int seed: 7
    readonly property int g: Theme.gui
    readonly property int gw: Math.round(width / g)
    readonly property int gh: Math.round(height / g)
    readonly property int s: 2                                   // stair step of the fold, GUI px
    readonly property int perf: 2                                // height of the perforated strip, GUI px

    function tone(day, night) { return Theme.isDark ? night : day; }
    readonly property color face: Theme.withAlpha(tone("#FBF8E6", "#DED8BE"), fillAlpha)
    readonly property color shade: tone("#EAE6D2", "#CAC4AB")
    readonly property color crease: tone("#D6D2BE", "#B4AE96")
    readonly property color edge: tone("#AEAA98", "#8E8974")
    readonly property color outline: tone("#878477", "#66624F")
    readonly property color ink: tone("#2A2A26", "#1C1C19")
    readonly property color inkMuted: tone("#6E6E68", "#55554F")

    // ---- the sheets behind, then the hard shadow (right + bottom strips only, so the paper's alpha does not double up)
    Repeater {
        model: sheet.behind
        Item {
            required property int index
            readonly property int off: (sheet.behind - index) * 2
            Rectangle { x: sheet.width; y: (parent.off + sheet.perf) * sheet.g; width: parent.off * sheet.g; height: sheet.height - (sheet.fold + sheet.perf) * sheet.g; color: index === 0 ? sheet.edge : sheet.crease }
            Rectangle { x: parent.off * sheet.g; y: sheet.height; width: sheet.width - sheet.fold * sheet.g; height: parent.off * sheet.g; color: index === 0 ? sheet.edge : sheet.crease }
        }
    }
    Rectangle { x: sheet.width; y: (sheet.perf + 1) * sheet.g; width: sheet.g; height: sheet.height - (sheet.fold + sheet.perf) * sheet.g; color: "#40000000"; visible: sheet.behind === 0 }
    Rectangle { x: sheet.g; y: sheet.height; width: sheet.width - sheet.fold * sheet.g; height: sheet.g; color: "#40000000"; visible: sheet.behind === 0 }

    // ---- the perforated top: teeth 4 on, 1 off
    Repeater {
        model: Math.ceil(sheet.gw / 5)
        Rectangle {
            required property int index
            x: index * 5 * sheet.g
            width: Math.min(4, sheet.gw - index * 5) * sheet.g
            height: sheet.perf * sheet.g
            color: sheet.face
            Rectangle { width: parent.width; height: sheet.g; color: sheet.outline }
        }
    }
    // ---- the face: the top part, then the bottom left beside the fold
    Rectangle { y: sheet.perf * sheet.g; width: sheet.width; height: sheet.height - (sheet.perf + sheet.fold) * sheet.g; color: sheet.face }
    Rectangle { y: sheet.height - sheet.fold * sheet.g; width: sheet.width - sheet.fold * sheet.g; height: sheet.fold * sheet.g; color: sheet.face }

    // ---- edges: left, right, bottom, with a shaded inner row at the bottom like the item
    Rectangle { y: sheet.g; width: sheet.g; height: sheet.height - sheet.g; color: sheet.outline }
    Rectangle { x: sheet.width - sheet.g; y: sheet.g; width: sheet.g; height: sheet.height - (sheet.fold + 1) * sheet.g; color: sheet.outline }
    Rectangle { y: sheet.height - sheet.g; width: sheet.width - sheet.fold * sheet.g; height: sheet.g; color: sheet.outline }
    Rectangle { x: sheet.g; y: sheet.height - 2 * sheet.g; width: sheet.width - (sheet.fold + 1) * sheet.g; height: sheet.g; color: sheet.shade }
    Rectangle { x: sheet.width - 2 * sheet.g; y: (sheet.perf) * sheet.g; width: sheet.g; height: sheet.height - (sheet.fold + sheet.perf) * sheet.g; color: sheet.shade }

    // ---- fibres: a few darker specks, always the same for a seed
    Repeater {
        model: {
            const out = [];
            let r = sheet.seed * 2654435761 >>> 0;
            const rnd = n => { r = (r ^ (r << 13)) >>> 0; r = (r ^ (r >>> 17)) >>> 0; r = (r ^ (r << 5)) >>> 0; return r % n; };
            const n = Math.floor(sheet.gw * sheet.gh / 140);
            for (let i = 0; i < n; i++) {
                const x = 3 + rnd(Math.max(1, sheet.gw - 6)), y = 4 + rnd(Math.max(1, sheet.gh - 7));
                if (x > sheet.gw - sheet.fold - 2 && y > sheet.gh - sheet.fold - 2) continue;
                out.push([x, y, 1 + rnd(3)]);
            }
            return out;
        }
        Rectangle {
            required property var modelData
            x: modelData[0] * sheet.g; y: modelData[1] * sheet.g
            width: modelData[2] * sheet.g; height: sheet.g
            color: sheet.shade
            opacity: 0.6
        }
    }

    // ---- the folded corner: the flap (right angle inward), its stepped outer edge, a crease along its top and left
    Repeater {
        model: sheet.fold / sheet.s
        Item {
            required property int index
            readonly property int rowY: sheet.gh - sheet.fold + index * sheet.s
            readonly property int rightEnd: sheet.gw - (index + 1) * sheet.s
            Rectangle {       // flap
                x: (sheet.gw - sheet.fold) * sheet.g; y: parent.rowY * sheet.g
                width: Math.max(0, parent.rightEnd - (sheet.gw - sheet.fold)) * sheet.g; height: sheet.s * sheet.g
                color: sheet.crease
            }
            Rectangle {       // step of the diagonal
                x: parent.rightEnd * sheet.g; y: parent.rowY * sheet.g
                width: sheet.g; height: sheet.s * sheet.g
                color: sheet.outline
            }
            Rectangle {
                x: parent.rightEnd * sheet.g; y: parent.rowY * sheet.g
                width: sheet.s * sheet.g; height: sheet.g
                color: sheet.outline
            }
        }
    }
    Rectangle { x: (sheet.gw - sheet.fold) * sheet.g; y: (sheet.gh - sheet.fold) * sheet.g; width: (sheet.fold - sheet.s) * sheet.g; height: sheet.g; color: sheet.edge }
    Rectangle { x: (sheet.gw - sheet.fold) * sheet.g; y: (sheet.gh - sheet.fold) * sheet.g; width: sheet.g; height: sheet.fold * sheet.g; color: sheet.edge }

    // ---- the pin: a red head with a highlight, its point in the paper
    Item {
        visible: sheet.pinned
        z: 5
        x: Math.round(sheet.gw / 2 - 3) * sheet.g
        y: -3 * sheet.g
        Repeater {
            model: [[1, 0, 3, 1, "#7A1010"], [0, 1, 5, 3, "#7A1010"], [1, 1, 3, 2, "#C62B2B"], [1, 1, 1, 1, "#FF6B6B"], [1, 4, 3, 1, "#7A1010"], [2, 5, 1, 2, "#5A5A5A"]]
            Rectangle {
                required property var modelData
                x: modelData[0] * sheet.g; y: modelData[1] * sheet.g
                width: modelData[2] * sheet.g; height: modelData[3] * sheet.g
                color: modelData[4]
            }
        }
    }
}
