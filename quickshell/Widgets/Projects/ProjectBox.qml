import QtQuick
import qs.Common

/*  ProjectBox — the game's checkbox at card size: 11 × 11 GUI px (the 20 px sprite is too big for a list row), same look as
 *  widget/checkbox — black outline, grey frame (white when highlighted), dark fill — with the tick in green when checked.
 *    checked, highlighted: bool          signal clicked()
 */
Item {
    id: root
    property bool checked: false
    property bool highlighted: false
    signal clicked()
    width: Theme.px(11); height: Theme.px(11)
    Rectangle { anchors.fill: parent; color: "#000000" }
    Rectangle {
        x: Theme.gui; y: Theme.gui; width: parent.width - Theme.px(2); height: parent.height - Theme.px(2)
        color: root.highlighted ? "#ffffff" : "#a0a0a0"
    }
    Rectangle { x: Theme.px(2); y: Theme.px(2); width: parent.width - Theme.px(4); height: parent.height - Theme.px(4); color: "#303030" }
    PixelGlyph {
        visible: root.checked
        x: Theme.px(2); y: Theme.px(3)
        kind: "check"
        color: "#55ff55"
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
