import QtQuick
import qs.Common as Common

/*  DEPRECATED: use McPanel.  Full-surface ground for big panels.
 *    ground: colour role, used only when framed is false; framed: draw the McPanel bevel; textured, textureOpacity: ignored, kept for callers
 */
Rectangle {
    id: root
    property string ground: "bg1"
    property bool textured: true
    property bool framed: true
    property real textureOpacity: 0
    radius: 0
    color: framed ? "transparent" : Common.Theme.col(ground, Common.Theme.bg1)
    Common.McPanel {
        visible: root.framed
        anchors.fill: parent
    }
}
