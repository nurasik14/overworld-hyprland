import QtQuick
import qs.Common
import qs.Widgets.Services

/*  AgendaRow — one event of the selected day (176 × 11 GUI px): time, tag chip, title, location.  Over events are dimmed, the running
 *  one is yellow.  Hover = slot highlight + a tooltip with the full title, time, place and notes; click opens the event in the browser.
 *    event: var (a CalendarService event) · day: "YYYY-MM-DD" it is listed under · pinHover: previews only
 */
Item {
    id: row
    property var event: null
    property string day: ""
    property bool pinHover: false
    signal opened(string id)
    width: Theme.px(176); height: Theme.px(11)

    readonly property bool hot: area.containsMouse || pinHover
    readonly property real nowMs: CalendarService.nowMs
    readonly property bool over: event ? (event.allDay ? event.lastDay < CalendarService.todayKey : event.endMs <= nowMs && event.startMs < nowMs) : false
    readonly property bool running: event ? (!event.allDay && event.startMs <= nowMs && event.endMs > nowMs) : false
    // the list shows the start (the end is in the tooltip)
    readonly property string when: event ? CalendarService.startLabel(event, day) : ""

    Rectangle { visible: row.hot; anchors.fill: parent; color: Theme.withAlpha(Theme.slotHover, 0.35) }
    opacity: over ? 0.55 : 1
    McText {
        id: timeText
        x: Theme.px(2); y: 0
        width: Theme.px(38)
        text: row.when
        elide: Text.ElideRight
        color: row.running ? Theme.chatReadable("e") : (row.event && row.event.allDay ? Theme.chatReadable("b") : Theme.textMuted)
        shadow: false
    }
    TagChip {
        id: chip
        x: Theme.px(41); y: Theme.px(1)
        tag: row.event ? row.event.tag : ""
    }
    McText {
        x: Theme.px(41) + (chip.visible ? chip.width + Theme.px(3) : 0); y: 0
        width: parent.width - x - Theme.px(2)
        text: (row.event ? row.event.title : "") + (row.event && row.event.location ? "  @" + row.event.location : "")
        elide: Text.ElideRight
        color: Theme.guiText
        shadow: false
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.event && row.event.link ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (row.event && row.event.link) row.opened(row.event.id)
    }

    Loader {
        active: row.hot && row.event !== null
        sourceComponent: McTooltip {
            title: row.event.title
            description: {
                const e = row.event;
                const l = [CalendarService.fmtDay(row.day, "ddd d MMM") + ", " + (e.allDay ? "all day" : (e.day === e.lastDay ? e.startHM + "-" + e.endHM : e.startHM + " → " + CalendarService.fmtDay(e.lastDay, "d MMM") + " " + e.endHM))];
                if (e.location) l.push("@ " + e.location);
                if (e.description) l.push(e.description.split("\n").slice(0, 4).join(" · ").slice(0, 160));
                return l.join("\n");
            }
            category: row.event.link ? "Click: open in browser" : ""
            maxWidth: 170
            target: row
            targetX: area.containsMouse ? area.mouseX : row.width / 2
            targetY: area.containsMouse ? area.mouseY : row.height / 2
        }
    }
}
