import QtQuick
import qs.Common

/*  McOutlineText — the XP-level style: coloured text over four black copies offset by 1 GUI px.
 *    text, color (default Theme.xp), outlineColor (default black), units
 *
 *    McOutlineText { text: "30" }
 */
Item {
    id: root
    property string text: ""
    property color color: Theme.xp
    property color outlineColor: "#000000"
    property int units: 1

    implicitWidth: main.implicitWidth
    implicitHeight: main.implicitHeight

    Repeater {
        model: [[-1, 0], [1, 0], [0, -1], [0, 1]]
        McText {
            required property var modelData
            x: modelData[0] * main.shadowOffset
            y: modelData[1] * main.shadowOffset
            text: root.text
            units: root.units
            color: root.outlineColor
            shadow: false
        }
    }
    McText {
        id: main
        text: root.text
        units: root.units
        color: root.color
        shadow: false
    }
}
