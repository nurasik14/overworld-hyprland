import QtQuick
import qs.Common

// A hover area with the game's tooltip, for the rows of the HUD.
MouseArea {
    id: root
    property string title: ""
    property string description: ""
    property string category: ""
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    Loader {
        active: root.containsMouse && root.enabled
        sourceComponent: McTooltip {
            title: root.title
            description: root.description
            category: root.category
            target: root
            targetX: root.mouseX
            targetY: root.mouseY
        }
    }
}
