import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  CalendarCard — Minecraft clock + map table (190 × 148 GUI px).
 *  Top: the real clock item (item/clock_00…63, the game's 64 frames) showing the actual time of day — frame 0 is noon,
 *  32 midnight, chosen with the game's own celestial-angle formula, the clock's 06:00 = tick 0 — with "Day N"
 *  (day of the year) and the time.  Below: the month as a grid of inventory slots, weekends in yellow like stack
 *  counts, today inside the hotbar selection frame.  Month arrows; click the month name to jump back to today.
 *  Week starts Monday.  No external data.
 */
WidgetCard {
    id: card
    title: "Clock & Calendar"
    guiW: 190
    guiH: 156

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()          // 0-based
    readonly property var dow: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    readonly property bool isCurrentMonth: year === today.getFullYear() && month === today.getMonth()
    readonly property int dayOfYear: Math.floor((new Date(today.getFullYear(), today.getMonth(), today.getDate()) - new Date(today.getFullYear(), 0, 0)) / 86400000)
    readonly property string timeText: ("0" + today.getHours()).slice(-2) + ":" + ("0" + today.getMinutes()).slice(-2)

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

    function shift(n) {
        let m = month + n, y = year;
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        month = m; year = y;
    }
    function goToday() { year = today.getFullYear(); month = today.getMonth() }
    readonly property var cells: {   // 42 cells, Monday first
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;
        const daysIn = new Date(year, month + 1, 0).getDate();
        const daysPrev = new Date(year, month, 0).getDate();
        const out = [];
        for (let i = 0; i < 42; i++) {
            const n = i - lead + 1;
            if (n < 1) out.push({ d: daysPrev + n, inMonth: false });
            else if (n > daysIn) out.push({ d: n - daysIn, inMonth: false });
            else out.push({ d: n, inMonth: true });
        }
        return out;
    }

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

    // ---- month bar
    Item {
        id: monthBar
        y: Theme.px(35); width: Theme.px(176); height: Theme.px(12)
        McButton { width: Theme.px(22); height: Theme.px(12); text: "<"; tooltip: "Previous month"; onClicked: card.shift(-1) }
        McButton { x: parent.width - width; width: Theme.px(22); height: Theme.px(12); text: ">"; tooltip: "Next month"; onClicked: card.shift(1) }
        McText {
            anchors.centerIn: parent
            text: new Date(card.year, card.month, 1).toLocaleDateString(Qt.locale("en_GB"), "MMMM yyyy")
            color: monthHover.containsMouse && !card.isCurrentMonth ? Theme.chatReadable("6") : Theme.guiText
            MouseArea { id: monthHover; anchors.fill: parent; hoverEnabled: true; onClicked: card.goToday() }
        }
    }

    // ---- weekday header + slot grid
    Row {
        id: dowRow
        y: Theme.px(49)
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
    Grid {
        id: grid
        y: Theme.px(59)
        columns: 7
        Repeater {
            model: card.cells
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool isToday: card.isCurrentMonth && modelData.inMonth && modelData.d === card.today.getDate()
                width: Theme.px(25); height: Theme.px(12)
                z: isToday ? 2 : 0
                readonly property real dim: modelData.inMonth ? 1 : 0.45
                Rectangle { anchors.fill: parent; color: Theme.slot; opacity: cell.dim }
                Rectangle { width: parent.width - Theme.gui; height: Theme.gui; color: Theme.slotDark; opacity: cell.dim }
                Rectangle { width: Theme.gui; height: parent.height - Theme.gui; color: Theme.slotDark; opacity: cell.dim }
                Rectangle { x: Theme.gui; y: parent.height - Theme.gui; width: parent.width - Theme.gui; height: Theme.gui; color: Theme.slotLight; opacity: cell.dim }
                Rectangle { x: parent.width - Theme.gui; y: Theme.gui; width: Theme.gui; height: parent.height - Theme.gui; color: Theme.slotLight; opacity: cell.dim }
                McText {
                    anchors.centerIn: parent
                    text: modelData.d
                    color: !modelData.inMonth ? Theme.withAlpha(Theme.hudText, 0.5) : (index % 7 >= 5 ? Theme.chat["e"] : Theme.hudText)
                    shadowColor: Theme.guiTextShadow
                    shadow: modelData.inMonth
                }
                McNineSlice {   // today: the hotbar selection frame, a little larger than the slot
                    visible: cell.isToday
                    x: -Theme.px(4); y: -Theme.px(2)
                    width: cell.width + Theme.px(8); height: cell.height + Theme.px(4)
                    sprite: "hud/hotbar_selection"
                    scaling: ({ type: "nine_slice", width: 24, height: 23, border: 4 })
                }
            }
        }
    }
}
