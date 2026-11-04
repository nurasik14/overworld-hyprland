import QtQuick
import qs.Common

/*  HudText — text over the world on the chat-line plate (#80000000 behind white text with the hard shadow).
 *    text, icon (item name), dim, maxWidth (screen px), hoverEnabled + tooltip, tooltipDescription, tooltipCategory
 */
Item {
    id: root
    property string text: ""
    property string icon: ""
    property bool dim: false
    property int maxWidth: Theme.px(400)
    property bool hoverEnabled: false
    property string tooltip: ""
    property string tooltipDescription: ""
    property string tooltipCategory: ""
    readonly property int pad: Theme.px(3)
    readonly property int iconRoom: icon.length ? Theme.px(11) : 0

    implicitWidth: Math.min(maxWidth, label.implicitWidth + iconRoom + pad * 2)
    implicitHeight: Theme.px(12)

    Rectangle { anchors.fill: parent; color: "#80000000" }
    McItemIcon {
        visible: root.icon.length > 0
        x: root.pad; anchors.verticalCenter: parent.verticalCenter
        size: 8
        name: root.icon
    }
    McText {
        id: label
        x: root.pad + root.iconRoom
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.pad * 2 - root.iconRoom
        text: root.text
        color: root.dim ? Theme.tooltipDesc : Theme.hudText
        elide: Text.ElideRight
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        acceptedButtons: Qt.NoButton
    }
    Loader {
        active: root.hoverEnabled && area.containsMouse && root.tooltip.length > 0
        sourceComponent: McTooltip {
            title: root.tooltip
            description: root.tooltipDescription
            category: root.tooltipCategory
            target: area
            targetX: area.mouseX
            targetY: area.mouseY
        }
    }
}
