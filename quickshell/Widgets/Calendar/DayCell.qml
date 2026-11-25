import QtQuick
import qs.Common
import qs.Widgets.Services

/*  DayCell — one day as an inventory slot (25 × 12 GUI px): the number, weekends yellow like stack counts, and the day's events as a
 *  stack count in the bottom-right corner (9 at most, "+" above).  Hover = the game's white slot-hover overlay and a tooltip listing
 *  the day's events; today = the hotbar selection frame; the selected day = a white outline.
 *    key "YYYY-MM-DD" · day (number) · inMonth · weekend · selected · today
 *    signals clicked(key), doubleClicked(key)
 *    pinHover: previews only — draw the hover state and its tooltip
 */
Item {
    id: cell
    property string key: ""
    property int day: 1
    property bool inMonth: true
    property bool weekend: false
    property bool selected: false
    property bool isToday: false
    property bool pinHover: false
    signal clicked(string key)
    signal doubleClicked(string key)

    width: Theme.px(25); height: Theme.px(12)
    z: isToday ? 3 : (selected || hot ? 2 : 0)

    readonly property bool hot: area.containsMouse || pinHover
    readonly property var evs: CalendarService.eventsOn(key)
    readonly property int count: evs.length
    readonly property real dim: inMonth ? 1 : 0.45

    Rectangle { anchors.fill: parent; color: Theme.slot; opacity: cell.dim }
    Rectangle { width: parent.width - Theme.gui; height: Theme.gui; color: Theme.slotDark; opacity: cell.dim }
    Rectangle { width: Theme.gui; height: parent.height - Theme.gui; color: Theme.slotDark; opacity: cell.dim }
    Rectangle { x: Theme.gui; y: parent.height - Theme.gui; width: parent.width - Theme.gui; height: Theme.gui; color: Theme.slotLight; opacity: cell.dim }
    Rectangle { x: parent.width - Theme.gui; y: Theme.gui; width: Theme.gui; height: parent.height - Theme.gui; color: Theme.slotLight; opacity: cell.dim }
    McText {
        id: num
        x: cell.count > 0 ? Theme.px(3) : Math.round((parent.width - implicitWidth) / 2 / Theme.gui) * Theme.gui    // left of the stack count when there is one
        anchors.verticalCenter: parent.verticalCenter
        text: cell.day
        color: !cell.inMonth ? Theme.withAlpha(Theme.hudText, 0.5) : (cell.weekend ? Theme.chat["e"] : Theme.hudText)
        shadowColor: Theme.guiTextShadow
        shadow: cell.inMonth
    }
    McText {          // the stack count
        visible: cell.count > 0
        anchors.right: parent.right; anchors.rightMargin: Theme.px(2)
        anchors.bottom: parent.bottom; anchors.bottomMargin: -Theme.px(1)
        text: cell.count > 9 ? "+" : cell.count
        color: Theme.hudText
        shadowColor: Theme.guiTextShadow
        opacity: cell.inMonth ? 1 : 0.7
    }
    Rectangle {       // the selected day: a white outline inside the slot
        visible: cell.selected
        anchors.fill: parent
        color: Theme.withAlpha(Theme.slotLight, 0.18)
        border.width: Theme.gui
        border.color: Theme.slotLight
        antialiasing: false
    }
    Rectangle {       // the game's slot hover: white at 50 %, inside the 1 px border
        visible: cell.hot
        x: Theme.gui; y: Theme.gui
        width: parent.width - 2 * Theme.gui; height: parent.height - 2 * Theme.gui
        color: Theme.slotHover
    }
    McNineSlice {     // today: the hotbar selection frame, a little larger than the slot
        visible: cell.isToday
        x: -Theme.px(4); y: -Theme.px(2)
        width: cell.width + Theme.px(8); height: cell.height + Theme.px(4)
        sprite: "hud/hotbar_selection"
        scaling: ({ type: "nine_slice", width: 24, height: 23, border: 4 })
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: cell.clicked(cell.key)
        onDoubleClicked: cell.doubleClicked(cell.key)
    }

    // the tooltip: the date, then up to 5 events (time, tag, title) and "+N more"
    function tipLines() {
        const out = [], list = cell.evs, n = Math.min(5, list.length);
        for (let i = 0; i < n; i++) {
            const e = list[i];
            out.push("§" + (e.allDay ? "b" : "e") + CalendarService.startLabel(e, cell.key) + " §r"
                     + (e.tag ? "§" + CalendarService.tagCode(e.tag) + e.tag + " §r" : "") + e.title);
        }
        if (list.length > n) out.push("§8+" + (list.length - n) + " more");
        return out;
    }
    Loader {
        active: cell.hot && cell.count > 0
        sourceComponent: McTooltip {
            title: CalendarService.fmtDay(cell.key, "dddd d MMMM")
            lines: cell.tipLines()
            maxWidth: 170
            target: cell
            targetX: area.containsMouse ? area.mouseX : cell.width / 2
            targetY: area.containsMouse ? area.mouseY : cell.height / 2
        }
    }
}
