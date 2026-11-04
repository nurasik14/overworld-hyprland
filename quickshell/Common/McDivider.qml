import QtQuick
import qs.Common

/*  McDivider — a separator.
 *    variant "bevel"   1 px shadow + 1 px highlight, carved into a panel (default)
 *    variant "header"  gui/header_separator tile (lists on a dark screen); "footer" likewise
 *    vertical: bool    bevel only
 *    skin: "auto"|"day"|"night"
 *
 *    McDivider { width: parent.width }
 */
Item {
    id: root
    property string variant: "bevel"
    property bool vertical: false
    property string skin: "auto"
    readonly property color _dark: skin === "day" ? Theme.colOf("light", "panelShadow") : skin === "night" ? Theme.colOf("dark", "panelShadow") : Theme.panelShadow
    readonly property color _light: skin === "day" ? Theme.colOf("light", "panelLight") : skin === "night" ? Theme.colOf("dark", "panelLight") : Theme.panelLight

    implicitWidth: vertical ? Theme.px(2) : Theme.px(100)
    implicitHeight: vertical ? Theme.px(100) : Theme.px(2)

    Rectangle {
        visible: root.variant === "bevel"
        width: root.vertical ? Theme.gui : root.width
        height: root.vertical ? root.height : Theme.gui
        color: root._dark
    }
    Rectangle {
        visible: root.variant === "bevel"
        x: root.vertical ? Theme.gui : 0
        y: root.vertical ? 0 : Theme.gui
        width: root.vertical ? Theme.gui : root.width
        height: root.vertical ? root.height : Theme.gui
        color: root._light
    }
    McNineSlice {
        visible: root.variant !== "bevel"
        anchors.fill: parent
        sprite: visible ? (root.variant === "footer" ? "gui/footer_separator" : "gui/header_separator") : ""
        scaling: ({ type: "tile", width: 32, height: 2 })
    }
}
