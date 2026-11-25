import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Widgets.Projects
import qs.Widgets.Services

/*  CalendarCard — Minecraft clock + map table with the user's Google Calendar events (190 × 182 GUI px).
 *  Top: the real clock item (item/clock_00…63, the game's 64 frames, chosen with the game's own celestial-angle formula, the clock's 06:00
 *  = tick 0) with "Day N" (day of the year), the CityU teaching week and the time.  Under it, while no day is selected, the strip
 *  "Next: 14:00 Lab" (+ how many are left today; yellow when it starts within 15 min).  Then the month as a grid of inventory slots,
 *  weekends yellow like stack counts, today in the hotbar selection frame, and a stack count in a slot's corner for every day with events.
 *    hover a day            slot highlight + a tooltip with that day's events
 *    click a day            select it: the month folds into its week and the agenda of that day opens below (wheel scrolls it);
 *                           click an event to open it in the browser; ▲ shows the month again
 *    double-click a day / + quick-add on that day (Calendar/CalendarEditor.qml, a layer that takes the keyboard)
 *    month arrows / wheel over the grid   change month  ·  in the week view: the week  ·  click the month name: today
 *  State (month, selected day, adding) lives in CalendarService, so IPC `calendar …` drives the same card on every screen.
 *  Week starts Monday.
 */
WidgetCard {
    id: card
    title: "Clock & Calendar"
    guiW: 190
    guiH: 182

    property string screenName: ""             // WidgetLayout: which output's rectangle this card publishes (the quick-add layer opens over it)
    property string pinDay: ""                 // previews only: draw this day / the nth agenda row as hovered
    property int pinRow: -1
    readonly property var svc: CalendarService
    readonly property alias monthGrid: grid         // for the render harness' real-event tests
    readonly property alias weekRow: week
    readonly property alias agendaList: list
    readonly property alias agendaFlick: flick
    readonly property alias nextStrip: strip
    readonly property alias addButton: addBtn
    readonly property alias monthButton: monthBtn
    readonly property alias monthBarItem: monthBar

    property date today: new Date()
    readonly property int year: svc.year
    readonly property int month: svc.month        // 0-based
    readonly property bool agenda: svc.expanded
    readonly property var dow: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    readonly property string todayKey: svc.dayKey(today)
    readonly property bool isCurrentMonth: year === today.getFullYear() && month === today.getMonth()
    readonly property int dayOfYear: Math.floor((new Date(today.getFullYear(), today.getMonth(), today.getDate()) - new Date(today.getFullYear(), 0, 0)) / 86400000)
    readonly property string timeText: ("0" + today.getHours()).slice(-2) + ":" + ("0" + today.getMinutes()).slice(-2)
    readonly property var semester: SemesterService.state
    readonly property string weekText: !semester ? "" : semester.phase === "teaching" ? "Wk " + semester.week : semester.phase === "revision" ? "Revision" : semester.phase === "exams" ? "Exams" : "Break"

    // the game's clock: angle = (2d + (0.5 − cos(πd)/2)) / 3 with d = frac(dayTime/24000 − 0.25); 64 frames, 0 = noon.
    // dayTime 0 is 06:00, so the day fraction is (hours − 6) / 24.
    readonly property int clockFrame: {
        const h = today.getHours() + today.getMinutes() / 60;
        const t = ((h - 6) / 24 + 1) % 1;
        const d = ((t - 0.25) % 1 + 1) % 1;
        const angle = (d * 2 + (0.5 - Math.cos(d * Math.PI) / 2)) / 3;
        return Math.round(angle * 64) % 64;
    }

    Timer { interval: 10000; running: card.visible; repeat: true; triggeredOnStart: true; onTriggered: card.today = new Date() }

    // where the card is on the output: the quick-add layer opens right over it
    readonly property var cardRect: ({ x: card.x, y: card.y, w: card.width, h: card.height, shown: card.shown })
    onCardRectChanged: svc.setCardRect(screenName, cardRect)
    onScreenNameChanged: svc.setCardRect(screenName, cardRect)

    property real wheelRest: 0
    function wheelBy(dy, step) {               // a notch is 120; a touchpad's small steps add up to one
        wheelRest += dy;
        if (Math.abs(wheelRest) < 120) return;
        const d = wheelRest > 0 ? -1 : 1;
        wheelRest = 0;
        step(d);
    }
    function pick(key) { svc.selectDay(key); }
    function addOn(key) { svc.openAdd(key); }
    // A click in the month folds the grid into the week, so the second click of a double-click would land on something else: for one double-click
    // interval an invisible catcher sits over the slot that was clicked, and a click on it is the double-click (quick-add for that day).
    property var dbl: null                      // {key, x, y, w, h} in card coordinates
    function pickGrid(key, cell) {
        const p = cell.mapToItem(card, 0, 0);
        card.dbl = { key: key, x: p.x, y: p.y, w: cell.width, h: cell.height };
        dblTimer.restart();
        svc.selectDay(key);
    }
    Timer { id: dblTimer; interval: Qt.styleHints.mouseDoubleClickInterval; onTriggered: card.dbl = null }
    MouseArea {
        parent: card
        z: 1000
        enabled: card.dbl !== null
        x: card.dbl ? card.dbl.x : 0; y: card.dbl ? card.dbl.y : 0
        width: card.dbl ? card.dbl.w : 0; height: card.dbl ? card.dbl.h : 0
        onClicked: { const k = card.dbl.key; card.dbl = null; dblTimer.stop(); card.addOn(k); }
    }

    readonly property var cells: {   // 42 cells, Monday first
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;
        const daysIn = new Date(year, month + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < 42; i++) {
            const n = i - lead + 1;
            const d = new Date(year, month, n);
            out.push({ d: d.getDate(), inMonth: n >= 1 && n <= daysIn, key: svc.dayKey(d) });
        }
        return out;
    }
    readonly property var weekCells: {   // the week of the selected day
        if (!svc.expanded) return [];
        const s = svc.keyDate(svc.selectedDay);
        const mon = new Date(s.getFullYear(), s.getMonth(), s.getDate() - ((s.getDay() + 6) % 7));
        const out = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(mon.getFullYear(), mon.getMonth(), mon.getDate() + i);
            out.push({ d: d.getDate(), inMonth: d.getMonth() === month, key: svc.dayKey(d) });
        }
        return out;
    }
    readonly property var dayEvents: svc.expanded ? svc.eventsOn(svc.selectedDay) : []

    // ---- clock + day
    Image {
        id: clockIcon
        width: Theme.px(32); height: Theme.px(32)
        source: Theme.tex("item/clock_" + ("0" + card.clockFrame).slice(-2))
        smooth: false
    }
    McText { x: Theme.px(38); y: Theme.px(1); units: 2; text: "Day " + card.dayOfYear; color: Theme.guiText }
    McText {
        x: Theme.px(38); y: Theme.px(21); width: Theme.px(138)
        color: Theme.textMuted
        text: card.timeText + " · " + Qt.locale("en_GB").dayName(card.today.getDay(), Locale.LongFormat) + " " + card.today.getDate()
    }
    McText {   // the CityU teaching week, like the bar clock
        visible: card.weekText.length > 0
        anchors.right: parent.right
        y: Theme.px(5)
        text: card.weekText
        color: Theme.chatReadable("2")
        shadow: false
        MouseArea { id: weekHover; anchors.fill: parent; anchors.margins: -Theme.px(2); hoverEnabled: true }
        Loader {
            active: weekHover.containsMouse
            sourceComponent: McTooltip { title: SemesterService.title; description: SemesterService.detail; target: weekHover; targetX: weekHover.mouseX; targetY: weekHover.mouseY }
        }
    }

    // ---- under the clock: what is next (no day selected)
    Item {
        id: strip
        visible: !card.agenda
        y: Theme.px(34); width: Theme.px(176); height: Theme.px(10)
        readonly property var info: card.svc.nextInfo
        readonly property string st: card.svc.state
        readonly property bool notConfigured: st === "not-configured"
        readonly property string text: notConfigured ? "Connect Google Calendar"
                                     : info.event ? info.text
                                     : (st === "loading" ? "Loading events…" : "Nothing planned")
        McText {
            id: stripText
            width: parent.width - (leftText.visible ? leftText.width + Theme.px(4) : 0)
            text: strip.text
            elide: Text.ElideRight
            color: strip.notConfigured ? Theme.chatReadable("6") : strip.info.soon ? Theme.chatReadable("e") : strip.info.event && !strip.info.now ? Theme.guiText : Theme.textMuted
            shadow: false
        }
        McText {
            id: leftText
            visible: strip.info.left > 0 && !strip.notConfigured
            anchors.right: parent.right
            text: strip.info.left + " left"
            color: Theme.textMuted
            shadow: false
        }
        MouseArea {
            id: stripArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: strip.info.event ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (strip.info.event) card.pick(strip.info.event.day <= card.todayKey ? card.todayKey : strip.info.event.day)
        }
        Loader {
            active: stripArea.containsMouse && (strip.notConfigured || strip.info.event)
            sourceComponent: McTooltip {
                title: strip.notConfigured ? "Connect Google Calendar" : strip.info.event.title
                description: strip.notConfigured ? "Run: overworld help calendar" : card.svc.lineOf(strip.info.event, strip.info.event.day)
                category: strip.notConfigured ? "" : "Click: open that day"
                maxWidth: 170
                target: stripArea; targetX: stripArea.mouseX; targetY: stripArea.mouseY
            }
        }
    }

    // ---- month bar (in the week view the arrows move by a week)
    Item {
        id: monthBar
        y: Theme.px(card.agenda ? 35 : 46); width: Theme.px(176); height: Theme.px(12)
        McButton {
            width: Theme.px(22); height: Theme.px(12); text: "<"
            tooltip: card.agenda ? "Previous week" : "Previous month"
            onClicked: card.agenda ? card.svc.shiftSelected(-7) : card.svc.shiftMonth(-1)
        }
        McButton {
            x: parent.width - width; width: Theme.px(22); height: Theme.px(12); text: ">"
            tooltip: card.agenda ? "Next week" : "Next month"
            onClicked: card.agenda ? card.svc.shiftSelected(7) : card.svc.shiftMonth(1)
        }
        McText {
            anchors.centerIn: parent
            text: new Date(card.year, card.month, 1).toLocaleDateString(Qt.locale("en_GB"), "MMMM yyyy")
            color: monthHover.containsMouse && !card.isCurrentMonth ? Theme.chatReadable("6") : Theme.guiText
            MouseArea { id: monthHover; anchors.fill: parent; hoverEnabled: true; onClicked: card.svc.goToday() }
        }
    }

    // ---- weekday header
    Row {
        id: dowRow
        y: Theme.px(card.agenda ? 49 : 60)
        Repeater {
            model: card.dow
            McText {
                required property string modelData
                required property int index
                width: Theme.px(25); height: Theme.px(10)
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? Theme.chatReadable("6") : Theme.textMuted
            }
        }
    }

    // ---- the month: 42 slots
    MouseArea {
        x: 0; y: grid.y; width: grid.width; height: grid.height
        visible: !card.agenda
        acceptedButtons: Qt.NoButton
        onWheel: wheel => card.wheelBy(wheel.angleDelta.y, d => card.svc.shiftMonth(d))
    }
    Grid {
        id: grid
        visible: !card.agenda
        y: Theme.px(70)
        columns: 7
        Repeater {
            model: card.agenda ? [] : card.cells
            delegate: DayCell {
                id: monthCell
                required property var modelData
                required property int index
                key: modelData.key
                day: modelData.d
                inMonth: modelData.inMonth
                weekend: index % 7 >= 5
                isToday: modelData.key === card.todayKey
                selected: modelData.key === card.svc.selectedDay
                pinHover: card.pinDay === modelData.key
                onClicked: key => card.pickGrid(key, monthCell)
                onDoubleClicked: key => card.addOn(key)
            }
        }
    }

    // ---- the week of the selected day
    MouseArea {
        x: 0; y: week.y; width: week.width; height: week.height
        visible: card.agenda
        acceptedButtons: Qt.NoButton
        onWheel: wheel => card.wheelBy(wheel.angleDelta.y, d => card.svc.shiftSelected(7 * d))
    }
    Row {
        id: week
        visible: card.agenda
        y: Theme.px(59)
        Repeater {
            model: card.weekCells
            delegate: DayCell {
                required property var modelData
                required property int index
                key: modelData.key
                day: modelData.d
                inMonth: modelData.inMonth
                weekend: index >= 5
                isToday: modelData.key === card.todayKey
                selected: modelData.key === card.svc.selectedDay
                pinHover: card.pinDay === modelData.key
                onClicked: key => card.pick(key)
                onDoubleClicked: key => card.addOn(key)
            }
        }
    }

    // ---- the agenda of the selected day
    Item {
        id: head
        visible: card.agenda
        y: Theme.px(75); width: Theme.px(176); height: Theme.px(12)
        McText {
            id: headDay
            y: Theme.px(1)
            text: card.agenda ? card.svc.fmtDay(card.svc.selectedDay, "ddd d MMM") : ""
            color: Theme.guiText
            shadow: false
        }
        McText {
            x: headDay.width + Theme.px(5); y: Theme.px(1)
            text: card.dayEvents.length === 0 ? "no events" : card.dayEvents.length + (card.dayEvents.length === 1 ? " event" : " events")
            color: Theme.textMuted
            shadow: false
        }
        McButton {
            id: monthBtn
            x: parent.width - Theme.px(31); width: Theme.px(14); height: Theme.px(12)
            horizontalPadding: 0
            tooltip: "Show the month"
            onClicked: card.svc.deselect()
            PixelGlyph { anchors.centerIn: parent; kind: "down"; rotation: 180; color: monthBtn.labelColor }
        }
        McButton {
            id: addBtn
            x: parent.width - Theme.px(14); width: Theme.px(14); height: Theme.px(12)
            horizontalPadding: 0
            text: "+"
            tooltip: "Add an event"
            tooltipDescription: "Double-click a day too"
            onClicked: card.addOn(card.svc.selectedDay)
        }
    }
    Flickable {
        id: flick
        visible: card.agenda
        y: Theme.px(89); width: Theme.px(176); height: Theme.px(55)      // five rows of 11
        contentWidth: width
        contentHeight: list.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property bool scrollable: contentHeight > height
        Column {
            id: list
            Repeater {
                model: card.dayEvents
                delegate: AgendaRow {
                    required property var modelData
                    required property int index
                    event: modelData
                    day: card.svc.selectedDay
                    width: flick.scrollable ? Theme.px(168) : Theme.px(176)
                    pinHover: card.pinRow === index
                    onOpened: id => card.svc.openEvent(id)
                }
            }
        }
    }
    McScrollbar {
        visible: card.agenda && flick.scrollable
        flickable: flick
        x: Theme.px(170); y: flick.y
        height: flick.height
    }
    McText {      // an empty day, or why there is nothing
        visible: card.agenda && card.dayEvents.length === 0
        x: 0; y: flick.y + Theme.px(8); width: Theme.px(176)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: Theme.textMuted
        shadow: false
        text: card.svc.state === "not-configured" ? "Connect Google Calendar:\noverworld help calendar"
            : card.svc.state === "loading" ? "Loading events…"
            : "Nothing planned.\nDouble-click a day or press + to add."
    }

    // ---- footer: when it was synced (click = sync now)
    Item {
        id: foot
        y: Theme.px(148); width: Theme.px(176); height: Theme.px(10)
        McText {
            width: parent.width
            text: card.svc.statusText
            elide: Text.ElideRight
            color: footArea.containsMouse ? Theme.guiText : Theme.withAlpha(Theme.textMuted, card.svc.state === "ok" ? 0.9 : 1)
            shadow: false
        }
        MouseArea {
            id: footArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: card.svc.sync()
        }
        Loader {
            active: footArea.containsMouse
            sourceComponent: McTooltip {
                title: "Google Calendar"
                description: card.svc.state === "not-configured" ? "Not connected. Run: overworld help calendar"
                           : card.svc.state === "offline" ? "Offline: showing the saved events.\n" + card.svc.error
                           : "Click to sync now"
                maxWidth: 170
                target: footArea; targetX: footArea.mouseX; targetY: footArea.mouseY
            }
        }
    }
}
