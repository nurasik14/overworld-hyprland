import QtQuick
import qs.Common as Common

/*  PaperBackground — full-surface ground for big panels (launcher cabinet, network panel, notification centre).
 *  ground: "bg0" | "bg1" | "bg2" | "surface"   (colour role)   default bg1
 *  textured: tile the mode's paper/lacquer grain at Theme.textureOpacity
 *  framed:   2 px Theme.frame border + inner hairline (same double rule as PaperPanel)
 *  radius:   default lg (12)
 */
Rectangle {
    id: root
    property string ground: "bg1"
    property bool textured: true
    property bool framed: true
    property real textureOpacity: Common.Theme.textureOpacity
    radius: Common.Theme.radius.lg
    color: Common.Theme.col(ground, Common.Theme.bg1)
    border.width: framed ? Common.Theme.border.frame : 0
    border.color: Common.Theme.frame
    Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }

    Item {
        anchors.fill: parent
        anchors.margins: root.border.width
        clip: true
        visible: root.textured
        Image {
            anchors.fill: parent
            source: Common.Theme.texture("ground-tile")
            fillMode: Image.Tile
            opacity: root.textureOpacity
            smooth: false
            asynchronous: true
        }
    }
    Rectangle {
        visible: root.framed
        anchors.fill: parent
        anchors.margins: Common.Theme.sizes.hairline_inset || 4
        radius: Math.max(2, root.radius - 3)
        color: "transparent"
        border.width: Common.Theme.border.hairline
        border.color: Common.Theme.hairline
        Behavior on border.color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
    }
}
