import QtQuick
import qs.Common

/*  McPanel — the inventory-style bevelled panel. Drawn procedurally with the exact pixel pattern of the game's
 *  gui/demo_background (black stepped outline, 2 px white top-left bevel, 2 px #555555 bottom-right bevel), so the
 *  Night skin and see-through fills are possible while the Day skin matches the original texel for texel.
 *    title: string          optional, GUI title style at (8,6) GUI px
 *    titleColor: color      default Theme.guiTitle
 *    skin: "auto"|"day"|"night"   auto follows Theme.mode and cross-fades
 *    fillOpacity: real      centre fill alpha for see-through widgets; bevels stay solid. Default 1, negative = 1
 *    padding: int           content inset in screen px; default px(7), the game's slot margin
 *    content                default property: children go inside the padded content area
 *    contentItem            that area, for anchoring from outside
 *    Keep width/height multiples of Theme.gui for a clean bevel.
 *  Size it explicitly; it does not grow from its content.
 *
 *    McPanel { title: "Inventory"; width: Theme.px(176); height: Theme.px(166); fillOpacity: 0.72
 *        McSlot { item: "compass" }
 *    }
 */
Item {
    id: root
    property string title: ""
    property color titleColor: skin === "day" ? Theme.colOf("light", "guiTitle") : skin === "night" ? Theme.colOf("dark", "guiTitle") : Theme.guiTitle
    property string skin: "auto"
    property real fillOpacity: 1
    property int padding: Theme.px(7)
    default property alias content: contentArea.data
    readonly property alias contentItem: contentArea
    readonly property alias titleItem: titleText
    readonly property int g: Theme.gui
    readonly property int gw: Math.ceil(width / g)
    readonly property int gh: Math.ceil(height / g)

    readonly property color _outline: skin === "day" ? Theme.colOf("light", "panelOutline") : skin === "night" ? Theme.colOf("dark", "panelOutline") : Theme.panelOutline
    readonly property color _light: skin === "day" ? Theme.colOf("light", "panelLight") : skin === "night" ? Theme.colOf("dark", "panelLight") : Theme.panelLight
    readonly property color _shadow: skin === "day" ? Theme.colOf("light", "panelShadow") : skin === "night" ? Theme.colOf("dark", "panelShadow") : Theme.panelShadow
    readonly property color _fill: skin === "day" ? Theme.colOf("light", "panel") : skin === "night" ? Theme.colOf("dark", "panel") : Theme.panel
    readonly property var _inks: [_outline, _light, _shadow, _fill, Theme.withAlpha(_fill, fillOpacity < 0 ? 1 : fillOpacity)]

    implicitWidth: Theme.px(176)
    implicitHeight: Theme.px(166)

    // Pixel map read from gui/demo_background.png. Each row: x = a + b·gw, y = c + d·gh, w = e + f·gw, h = g + h·gh, ink index.
    // Inks: 0 outline, 1 highlight, 2 shadow, 3 solid fill (corner texels), 4 fill with fillOpacity.
    readonly property var _map: [
        [3, 0, 4, 0, -6, 1, -7, 1, 4],  [4, 0, 3, 0, -7, 1, 1, 0, 4],                     // centre
        [2, 0, 0, 0, -5, 1, 1, 0, 0],   [0, 0, 2, 0, 1, 0, -5, 1, 0],                     // outline top, left
        [-1, 1, 3, 0, 1, 0, -5, 1, 0],  [3, 0, -1, 1, -5, 1, 1, 0, 0],                    // outline right, bottom
        [1, 0, 1, 0, 1, 0, 1, 0, 0],    [-3, 1, 1, 0, 1, 0, 1, 0, 0],  [-2, 1, 2, 0, 1, 0, 1, 0, 0],    // stepped corners
        [1, 0, -3, 1, 1, 0, 1, 0, 0],   [2, 0, -2, 1, 1, 0, 1, 0, 0],  [-2, 1, -2, 1, 1, 0, 1, 0, 0],
        [2, 0, 1, 0, -5, 1, 1, 0, 1],   [1, 0, 2, 0, -4, 1, 1, 0, 1],                     // highlight rows
        [1, 0, 3, 0, 2, 0, -6, 1, 1],   [3, 0, 3, 0, 1, 0, 1, 0, 1],                      // highlight column + inner step
        [-3, 1, 3, 0, 2, 0, -5, 1, 2],  [3, 0, -3, 1, -5, 1, 2, 0, 2],                    // shadow column, rows
        [-4, 1, -4, 1, 1, 0, 1, 0, 2],                                                    // shadow inner step
        [-3, 1, 2, 0, 1, 0, 1, 0, 3],   [2, 0, -3, 1, 1, 0, 1, 0, 3]                      // the two light corner texels
    ]
    Repeater {
        model: root._map
        Rectangle {
            required property var modelData
            readonly property var d: modelData
            x: (d[0] + d[1] * root.gw) * root.g
            y: (d[2] + d[3] * root.gh) * root.g
            width: (d[4] + d[5] * root.gw) * root.g
            height: (d[6] + d[7] * root.gh) * root.g
            color: root._inks[d[8]]
            antialiasing: false
        }
    }

    McText {
        id: titleText
        visible: root.title.length > 0
        x: Theme.px(8); y: Theme.px(5)      // glyphs start 1 GUI px below the line box: the game's title row is y = 6
        width: root.width - Theme.px(16)
        text: root.title
        color: root.titleColor
        elide: Text.ElideRight
    }

    Item {
        id: contentArea
        anchors.fill: parent
        anchors.margins: root.padding
        anchors.topMargin: root.title.length > 0 ? Theme.px(17) : root.padding
    }
}
