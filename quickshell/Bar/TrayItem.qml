import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Common

/*  TrayItem — one StatusNotifierItem: 16 px icon, left click activate, middle secondaryActivate, right = native menu. */
Item {
    id: root
    required property SystemTrayItem modelData
    implicitWidth: 24
    implicitHeight: 28
    readonly property bool hovered: mouse.containsMouse

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.sm
        color: Theme.inkWash
        opacity: root.hovered ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }
    IconImage {
        anchors.centerIn: parent
        implicitSize: Theme.sizes.icon || 16
        source: root.modelData.icon
    }
    QsMenuAnchor {
        id: menuAnchor
        menu: root.modelData.menu
        anchor.item: root
        anchor.window: root.QsWindow.window
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 6
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: ev => {
            if (ev.button === Qt.LeftButton) {
                if (root.modelData.onlyMenu && root.modelData.hasMenu) menuAnchor.open();
                else root.modelData.activate();
            } else if (ev.button === Qt.MiddleButton) {
                root.modelData.secondaryActivate();
            } else if (root.modelData.hasMenu) {
                menuAnchor.open();
            }
        }
        onWheel: ev => root.modelData.scroll(ev.angleDelta.y, false)
    }
    BarTooltip {
        target: root
        shown: root.hovered
        text: root.modelData.tooltipTitle.length ? root.modelData.tooltipTitle : (root.modelData.title || root.modelData.id)
    }
}
