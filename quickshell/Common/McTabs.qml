import QtQuick
import qs.Common

/*  McTabs — creative-inventory tabs (26×32 sprites, one every 27 GUI px). The selected tab overlaps the panel by 4 GUI px
 *  so it joins it; unselected tabs are cut at the panel edge, as if drawn behind it.
 *    tabs: var             [{ item: "compass", sprite: "icon/search", label: "Search", description: "", category: "" }, …]
 *                          item or sprite is the 16 GUI px icon; label feeds the hover tooltip
 *    currentIndex: int
 *    side: "top"|"bottom"  default top
 *    skin: "auto"|"day"|"night"    night swaps the grey sprites for the Night palette
 *    soundId: string       default "ui.click"
 *    hoveredIndex: int     read; forceHover: int to preview a tab's tooltip-less hover overlay
 *    signal tabClicked(int index)
 *  Placement: put the row flush with the panel, overlapping it: anchors.bottom = panel.top with bottomMargin = -overlap.
 *
 *    McTabs { id: tabs; tabs: [{ item: "compass", label: "Search" }, { item: "nether_star", label: "Favourites" }]
 *             anchors { left: panel.left; bottom: panel.top; bottomMargin: -tabs.overlap }
 *             onTabClicked: i => currentIndex = i }
 */
Item {
    id: root
    property var tabs: []
    property int currentIndex: 0
    property string side: "top"
    property string skin: "auto"
    property string soundId: "ui.click"
    property int forceHover: -1
    property int hoveredIndex: -1
    readonly property int overlap: Theme.px(4)
    signal tabClicked(int index)

    readonly property bool night: skin === "night" || (skin === "auto" && Theme.isDark)
    readonly property bool isTop: side === "top"
    z: 1      // above a sibling panel, so the selected tab joins it wherever it is declared
    implicitWidth: Math.max(0, tabs.length * Theme.px(27) - Theme.gui)
    implicitHeight: Theme.px(32)

    Repeater {
        model: root.tabs
        Item {
            id: tabItem
            required property var modelData
            required property int index
            readonly property bool selected: index === root.currentIndex
            readonly property int column: Math.min(index + 1, 7)
            x: index * Theme.px(27)
            y: !selected && !root.isTop ? root.overlap : 0
            z: selected ? 2 : 1
            width: Theme.px(26)
            height: selected ? Theme.px(32) : Theme.px(28)
            clip: true

            McSprite {
                y: !tabItem.selected && !root.isTop ? -root.overlap : 0
                width: Theme.px(26)
                height: Theme.px(32)
                sprite: "container/creative_inventory/tab_" + (root.isTop ? "top" : "bottom") + (tabItem.selected ? "_selected_" : "_unselected_") + tabItem.column
                nightRemap: root.night
            }
            McItemIcon {
                visible: !!(tabItem.modelData.item)
                x: Theme.px(5)
                y: root.isTop ? Theme.px(tabItem.selected ? 9 : 8) : Theme.px(tabItem.selected ? 7 : 4)
                name: tabItem.modelData.item || ""
            }
            McSprite {
                visible: !!(tabItem.modelData.sprite)
                x: Theme.px(5)
                y: root.isTop ? Theme.px(tabItem.selected ? 9 : 8) : Theme.px(tabItem.selected ? 7 : 4)
                sprite: tabItem.modelData.sprite || ""
            }
            MouseArea {
                id: tabArea
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: root.hoveredIndex = containsMouse ? tabItem.index : (root.hoveredIndex === tabItem.index ? -1 : root.hoveredIndex)
                onClicked: {
                    if (root.soundId.length) Theme.playSound(root.soundId);
                    root.currentIndex = tabItem.index;
                    root.tabClicked(tabItem.index);
                }
            }
            Loader {
                active: tabArea.containsMouse && !!(tabItem.modelData.label)
                sourceComponent: McTooltip {
                    title: tabItem.modelData.label || ""
                    description: tabItem.modelData.description || ""
                    category: tabItem.modelData.category || ""
                    target: tabItem
                    targetX: tabArea.mouseX
                    targetY: tabArea.mouseY
                }
            }
        }
    }
}
