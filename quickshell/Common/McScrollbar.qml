import QtQuick
import qs.Common

/*  McScrollbar — vertical scrollbar, two looks from the game:
 *    variant "list"      widget/scroller_background + widget/scroller, 6 GUI px wide, proportional thumb (world / server lists)
 *    variant "creative"  recessed slot track + container/creative_inventory/scroller, 14 GUI px wide, fixed 15 px thumb
 *    flickable: Flickable  bind position and size automatically; dragging and the wheel scroll it
 *    Or drive by hand: position (0..1), pageRatio (0..1 visible fraction), signal moved(real position)
 *    highlighted: bool     previews; skin: "auto"|"day"|"night" for the creative track
 *    readonly scrollable: bool   content overflows; otherwise the thumb shows disabled (creative) or hides (list)
 *
 *    ListView { id: list; clip: true; … }
 *    McScrollbar { flickable: list; anchors.right: parent.right; anchors.top: list.top; anchors.bottom: list.bottom }
 */
Item {
    id: root
    property Flickable flickable: null
    property string variant: "list"
    property real position: 0
    property real pageRatio: 1
    property string skin: "auto"
    property bool highlighted: false
    signal moved(real position)

    readonly property bool creative: variant === "creative"
    readonly property real _maxY: flickable ? Math.max(0, flickable.contentHeight - flickable.height) : 0
    readonly property real _pos: flickable ? (_maxY > 0 ? Math.min(1, Math.max(0, (flickable.contentY - flickable.originY) / _maxY)) : 0) : position
    readonly property real _page: flickable ? (flickable.contentHeight > 0 ? Math.min(1, flickable.height / flickable.contentHeight) : 1) : pageRatio
    readonly property bool scrollable: _page < 1

    readonly property int inset: creative ? Theme.gui : 0
    readonly property int thumbW: Theme.px(creative ? 12 : 6)
    readonly property int thumbH: creative ? Theme.px(15) : Math.min(height, Math.max(Theme.px(32), Math.round(_page * height)))
    readonly property int travel: Math.max(0, height - inset * 2 - thumbH)

    implicitWidth: Theme.px(creative ? 14 : 6)
    implicitHeight: Theme.px(112)

    function _setPos(p) {
        p = Math.min(1, Math.max(0, p));
        if (flickable) flickable.contentY = flickable.originY + p * _maxY;
        else position = p;
        moved(p);
    }

    McNineSlice {
        visible: !root.creative
        anchors.fill: parent
        sprite: "widget/scroller_background"
    }
    Item {   // creative track: the recessed 14 px column of the tab texture, drawn with slot greys
        visible: root.creative
        anchors.fill: parent
        readonly property color dark: root.skin === "day" ? Theme.colOf("light", "slotDark") : root.skin === "night" ? Theme.colOf("dark", "slotDark") : Theme.slotDark
        readonly property color light: root.skin === "day" ? Theme.colOf("light", "slotLight") : root.skin === "night" ? Theme.colOf("dark", "slotLight") : Theme.slotLight
        readonly property color fill: root.skin === "day" ? Theme.colOf("light", "slot") : root.skin === "night" ? Theme.colOf("dark", "slot") : Theme.slot
        Rectangle { anchors.fill: parent; color: parent.fill }
        Rectangle { width: parent.width - Theme.gui; height: Theme.gui; color: parent.dark }
        Rectangle { width: Theme.gui; height: parent.height - Theme.gui; color: parent.dark }
        Rectangle { x: Theme.gui; y: parent.height - Theme.gui; width: parent.width - Theme.gui; height: Theme.gui; color: parent.light }
        Rectangle { x: parent.width - Theme.gui; y: Theme.gui; width: Theme.gui; height: parent.height - Theme.gui; color: parent.light }
    }

    McNineSlice {
        id: thumb
        visible: root.creative || root.scrollable
        x: root.inset
        y: root.inset + Math.round(root._pos * root.travel / Theme.gui) * Theme.gui
        width: root.thumbW
        height: root.thumbH
        sprite: !root.creative ? "widget/scroller"
              : root.scrollable ? "container/creative_inventory/scroller" : "container/creative_inventory/scroller_disabled"
    }
    Rectangle {   // the game has no hover sprite for the list thumb: previews and hover get a faint white lift
        visible: !root.creative && root.scrollable && (root.highlighted || area.containsMouse)
        x: thumb.x; y: thumb.y
        width: thumb.width; height: thumb.height
        color: Theme.inkWash
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.scrollable
        preventStealing: true
        property real grab: root.thumbH / 2
        onPressed: mouse => {
            const onThumb = mouse.y >= thumb.y && mouse.y < thumb.y + thumb.height;
            grab = onThumb ? mouse.y - thumb.y : root.thumbH / 2;
            root._setPos((mouse.y - grab - root.inset) / Math.max(1, root.travel));
        }
        onPositionChanged: mouse => { if (pressed) root._setPos((mouse.y - grab - root.inset) / Math.max(1, root.travel)); }
        onWheel: wheel => root._setPos(root._pos - (wheel.angleDelta.y / 120) * Math.max(0.05, root._page / 3))
    }
}
