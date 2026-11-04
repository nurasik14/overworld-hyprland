import QtQuick
import QtQuick.Window
import qs.Common

/*  McTooltip — the game's tooltip: real tooltip/background + tooltip/frame sprites (dark translucent, purple gradient border).
 *    title: string        first line, white, 2 GUI px gap below it
 *    description: string  grey lines (§7), "\n" separated, wrapped at maxWidth
 *    category: string     last line, blue (§9), like the creative tab name
 *    lines: var           extra lines as §-strings, appended after description (["§aActive", "§8ws 3"])
 *    maxWidth: int        wrap width of the text, GUI px; default 200
 *    Positioning, pick one:
 *      target: Item         follow the pointer over this item: mouse at (targetX, targetY) in target coordinates.
 *                           The tooltip reparents itself to the window's content item, sits above everything and flips at
 *                           the window edge like the game (12 px right of and 12 px above the pointer).
 *      none                 lay it out yourself; implicit size excludes the 9 px transparent sprite margin via `margin`
 *
 *    McTooltip { title: "Kitty"; description: "Fast GPU terminal"; category: "Utilities"
 *                target: slot; targetX: area.mouseX; targetY: area.mouseY; visible: area.containsMouse }
 *  McButton, McIconButton and McSlot already embed one through their `tooltip*` properties.
 */
Item {
    id: root
    property string title: ""
    property string description: ""
    property string category: ""
    property var lines: []
    property int maxWidth: 200
    property Item target: null
    property real targetX: 0
    property real targetY: 0
    readonly property int margin: Theme.px(12)      // the sprite extends 3 + 9 GUI px beyond the text block

    implicitWidth: textColumn.width + margin * 2
    // a line box is 10 GUI px with 1 px above the glyphs and 2 below; the game's text block has neither
    implicitHeight: textColumn.height - Theme.px(3) + margin * 2
    width: implicitWidth
    height: implicitHeight
    z: 100000
    function _place() {
        if (!target || !parent) return;
        const p = target.mapToItem(parent, targetX, targetY);
        const w = parent.width, h = parent.height;
        let nx = p.x + Theme.px(12) - margin;
        if (nx + width - margin > w) nx = p.x - Theme.px(12) - width + margin;
        let ny = p.y - Theme.px(12) - margin;
        if (ny + height - margin > h) ny = h - height + margin;
        if (ny + margin < 0) ny = -margin;
        x = Math.max(-margin, nx);
        y = ny;
    }
    onTargetXChanged: _place()
    onTargetYChanged: _place()
    onWidthChanged: _place()
    onHeightChanged: _place()
    readonly property real _boundsW: parent ? parent.width : 0
    readonly property real _boundsH: parent ? parent.height : 0
    // deferred: the target's own position may depend on the same resize and settles after this handler
    on_BoundsWChanged: Qt.callLater(_place)
    on_BoundsHChanged: Qt.callLater(_place)
    onVisibleChanged: if (visible) _place()
    // Window is null until the target is in a scene, so a statically declared tooltip reparents when it arrives.
    readonly property var _window: target ? target.Window.window : null
    on_WindowChanged: _attach()
    onTargetChanged: _attach()
    Component.onCompleted: _attach()
    function _attach() {
        if (target && target.Window.window) parent = target.Window.contentItem;
        _place();
    }

    McNineSlice { anchors.fill: parent; sprite: "tooltip/background" }
    McNineSlice { anchors.fill: parent; sprite: "tooltip/frame" }

    Column {
        id: textColumn
        x: root.margin
        y: root.margin - Theme.gui
        width: Math.min(childrenRect.width, Theme.px(root.maxWidth))
        spacing: 0
        McText {
            visible: root.title.length > 0
            text: root.title
            color: Theme.tooltipTitle
            height: implicitHeight + Theme.px(2)
        }
        Repeater {
            model: root.description.length ? root.description.split("\n") : []
            McText {
                required property string modelData
                text: modelData
                color: Theme.tooltipDesc
                wrapMode: Text.Wrap
                width: Math.min(implicitWidth, Theme.px(root.maxWidth))
            }
        }
        Repeater {
            model: root.lines
            McText {
                required property string modelData
                codes: modelData
                darkGround: true
                color: Theme.tooltipDesc
                wrapMode: Text.Wrap
                width: Math.min(implicitWidth, Theme.px(root.maxWidth))
            }
        }
        McText {
            visible: root.category.length > 0
            text: root.category
            color: Theme.tooltipCategory
        }
    }
}
