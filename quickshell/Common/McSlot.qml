import QtQuick
import qs.Common

/*  McSlot — the 18×18 inventory slot (same texels as container/slot, skinned for Night): item, stack count, hover overlay.
 *    item: string          item name, see McItemIcon
 *    app, appTitle: string app class and window title: icon through tokens/items.json
 *    iconSource: url       explicit icon image
 *    count: int            stack count, bottom-right, white with shadow; hidden when ≤ 1
 *    highlighted: bool     force the hover overlay (keyboard cursor, previews)
 *    selected: bool        white 1 GUI px frame, for "the" selected slot in a grid
 *    empty: bool           read-only: nothing to show
 *    skin: "auto"|"day"|"night"
 *    soundId: string       default ""; slots click silently unless asked
 *    tooltip, tooltipDescription, tooltipCategory: string, tooltipLines: var   instant hover tooltip, like the game
 *    readonly hovered;  signals clicked(), rightClicked()
 *
 *    McSlot { app: "kitty"; count: 3; tooltip: "kitty"; tooltipCategory: "Terminal"; onClicked: launch() }
 */
Item {
    id: root
    property string item: ""
    property string app: ""
    property string appTitle: ""
    property url iconSource: ""
    property int count: 1
    property bool highlighted: false
    property bool selected: false
    property string skin: "auto"
    property string soundId: ""
    property string tooltip: ""
    property string tooltipDescription: ""
    property string tooltipCategory: ""
    property var tooltipLines: []
    property bool glint: false
    readonly property bool empty: !item.length && !app.length && !iconSource.toString().length
    readonly property alias hovered: area.containsMouse
    default property alias extraContent: extra.data
    signal clicked()
    signal rightClicked()

    readonly property int g: Theme.gui
    readonly property color _dark: skin === "day" ? Theme.colOf("light", "slotDark") : skin === "night" ? Theme.colOf("dark", "slotDark") : Theme.slotDark
    readonly property color _light: skin === "day" ? Theme.colOf("light", "slotLight") : skin === "night" ? Theme.colOf("dark", "slotLight") : Theme.slotLight
    readonly property color _fill: skin === "day" ? Theme.colOf("light", "slot") : skin === "night" ? Theme.colOf("dark", "slot") : Theme.slot

    implicitWidth: Theme.px(18)
    implicitHeight: Theme.px(18)
    z: selected ? 1 : 0     // the frame extends over the neighbouring slots

    Rectangle { anchors.fill: parent; color: root._fill }
    Rectangle { width: 17 * root.g; height: root.g; color: root._dark }
    Rectangle { width: root.g; height: 17 * root.g; color: root._dark }
    Rectangle { x: root.g; y: 17 * root.g; width: 17 * root.g; height: root.g; color: root._light }
    Rectangle { x: 17 * root.g; y: root.g; width: root.g; height: 17 * root.g; color: root._light }

    McItemIcon {
        visible: !root.empty
        x: root.g; y: root.g
        name: root.item
        app: root.app
        appTitle: root.appTitle
        source: root.iconSource
        glint: root.glint
    }
    Rectangle {   // the game's slot highlight: #80FFFFFF over the 16×16 item area
        x: root.g; y: root.g
        width: 16 * root.g; height: 16 * root.g
        color: Theme.slotHover
        visible: root.highlighted || area.containsMouse
    }
    Item { id: extra; anchors.fill: parent }
    McText {
        visible: root.count > 1
        text: String(root.count)
        color: Theme.hudText
        anchors.right: parent.right
        y: 9 * root.g
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -root.g
        color: "transparent"
        border.width: root.g
        border.color: Theme.focusRing
        visible: root.selected
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) { root.rightClicked(); return; }
            if (root.soundId.length) Theme.playSound(root.soundId);
            root.clicked();
        }
    }

    Loader {
        active: area.containsMouse && root.tooltip.length > 0
        sourceComponent: McTooltip {
            title: root.tooltip
            description: root.tooltipDescription
            category: root.tooltipCategory
            lines: root.tooltipLines
            target: root
            targetX: area.mouseX
            targetY: area.mouseY
        }
    }
}
