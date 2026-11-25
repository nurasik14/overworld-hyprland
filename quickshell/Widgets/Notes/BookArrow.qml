import QtQuick
import qs.Common

/*  BookArrow — the page-turn sprite (gui/sprites/widget/page_forward|backward, 23 × 13 texels); hover swaps to the _highlighted one, like the game's
 *  PageButton.  Drawn nearest-neighbour at `u` screen px per texel.  Without the sprites: a drawn arrow in a small brown plate.
 *    forward: bool    which arrow
 *    u: int           screen px per texel
 *  signal clicked()
 */
Item {
    id: arrow
    property bool forward: true
    property int u: Theme.gui
    property bool pinned: false                // previews only: draw it highlighted
    readonly property alias hovered: area.containsMouse
    signal clicked()
    width: 23 * u
    height: 13 * u
    readonly property string name: "widget/page_" + (forward ? "forward" : "backward") + (area.containsMouse || pinned ? "_highlighted" : "")
    readonly property url src: Theme.gs(name)
    readonly property bool real: src.toString() !== String(Theme.missingTexture)

    Image {
        anchors.fill: parent
        visible: arrow.real
        source: arrow.real ? arrow.src : ""
        smooth: false
        mipmap: false
    }
    Item {   // fallback
        anchors.fill: parent
        visible: !arrow.real
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: arrow.u; border.color: (area.containsMouse || arrow.pinned) ? "#FFFFFF" : "#3A2112" }
        Repeater {   // a stepped triangle, pointing the way
            model: 5
            Rectangle {
                required property int index
                x: arrow.u * (arrow.forward ? 8 + index : 14 - index)
                y: arrow.u * (3 + index)
                width: arrow.u * (arrow.forward ? 1 : 1); height: arrow.u * (7 - index * 2)
                color: (area.containsMouse || arrow.pinned) ? "#FFFFFF" : "#3A2112"
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: arrow.clicked()
        Accessible.role: Accessible.Button
        Accessible.name: arrow.forward ? "Next page" : "Previous page"
    }
}
