import QtQuick
import qs.Common as Common

/*  InkDivider — a separator.  brush: false → 1 px hairline; brush: true → the generated ink brush stroke
 *  (black on paper, cream on lacquer).  Horizontal by default; vertical: true for a column rule.
 */
Item {
    id: root
    property bool brush: false
    property bool vertical: false
    property real brushOpacity: 0.85
    implicitWidth: vertical ? 1 : 200
    implicitHeight: vertical ? 200 : (brush ? 14 : 1)

    Rectangle {
        visible: !root.brush
        anchors.centerIn: parent
        width: root.vertical ? Common.Theme.border.hairline : parent.width
        height: root.vertical ? parent.height : Common.Theme.border.hairline
        color: Common.Theme.hairline
        Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
    }
    Image {
        visible: root.brush
        anchors.fill: parent
        source: root.brush ? Common.Theme.texture("divider") : ""
        fillMode: Image.PreserveAspectFit
        rotation: root.vertical ? 90 : 0
        opacity: root.brushOpacity
        smooth: true
        mipmap: true
        asynchronous: true
    }
}
