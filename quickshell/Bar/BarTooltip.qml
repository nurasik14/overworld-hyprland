import QtQuick
import Quickshell
import qs.Common

/*  BarTooltip — small paper slip under a bar item.  text (Latin meaning), target (the hovered Item), shown. */
PopupWindow {
    id: tip
    property Item target: null
    property string text: ""
    property bool shown: false
    anchor.item: target
    anchor.window: target ? target.QsWindow.window : null
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6
    anchor.adjustment: PopupAdjustment.SlideX
    implicitWidth: label.implicitWidth + Theme.space.md * 2
    implicitHeight: label.implicitHeight + Theme.space.sm * 2
    visible: shown && text.length > 0 && target !== null
    color: "transparent"
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.sm
        color: Theme.bg2
        border.width: 1
        border.color: Theme.frame
        Text {
            id: label
            anchors.centerIn: parent
            text: tip.text
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontFor("small").pixelSize
            renderType: Text.NativeRendering
        }
    }
}
