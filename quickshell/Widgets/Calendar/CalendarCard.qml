import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  CalendarCard — 日历 · CALENDAR (380 × 260).  Month grid Mon–Sun, today marked with a small seal behind
 *  the number, previous / next month, header "October 2026 · 十月".  No external data.
 */
WidgetCard {
    id: card
    title: "日历"
    subtitle: "Calendar"
    sealGlyph: "印"
    width: 380
    height: 260

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()          // 0-based
    readonly property var cjkMonths: ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
    readonly property var dow: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property bool isCurrentMonth: year === today.getFullYear() && month === today.getMonth()

    Timer { interval: 60000; running: true; repeat: true; onTriggered: { const d = new Date(); if (d.getDate() !== card.today.getDate()) card.today = d } }

    function shift(n) {
        let m = month + n, y = year;
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        month = m; year = y;
    }
    function monthName() { return new Date(year, month, 1).toLocaleDateString(Qt.locale("en_GB"), "MMMM yyyy") }
    // 42 cells; day numbers; `inMonth` flags; week starts Monday
    readonly property var cells: {
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;                 // Mon = 0
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

    // ---- header
    Item {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 26
        Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm
            InkText { role: "title"; text: card.monthName(); anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 1; height: 12; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: card.cjkMonths[card.month]
                color: Theme.seal
                font.family: Theme.fontDisplay
                font.pixelSize: 20
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            InkButton { quiet: true; icon: "󰅁"; tooltip: "Previous month"; implicitHeight: 24; implicitWidth: 26; onClicked: card.shift(-1) }
            InkButton { quiet: true; icon: "󰋜"; tooltip: "Today"; implicitHeight: 24; implicitWidth: 26; visible: !card.isCurrentMonth; onClicked: { card.year = card.today.getFullYear(); card.month = card.today.getMonth() } }
            InkButton { quiet: true; icon: "󰅂"; tooltip: "Next month"; implicitHeight: 24; implicitWidth: 26; onClicked: card.shift(1) }
        }
    }

    // ---- day-of-week headers
    Row {
        id: dowRow
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: header.bottom
        anchors.topMargin: 4
        height: 18
        Repeater {
            model: card.dow
            delegate: Item {
                required property string modelData
                required property int index
                width: dowRow.width / 7; height: dowRow.height
                InkText {
                    anchors.centerIn: parent
                    role: "body"; font.pixelSize: 12; muted: true
                    color: index >= 5 ? Theme.accent2 : Theme.textMuted
                    text: modelData
                }
            }
        }
    }
    InkDivider { anchors.left: parent.left; anchors.right: parent.right; anchors.top: dowRow.bottom; anchors.topMargin: 2 }

    // ---- grid
    Grid {
        id: grid
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: dowRow.bottom; anchors.bottom: parent.bottom
        anchors.topMargin: 5
        columns: 7
        readonly property real cellW: width / 7
        readonly property real cellH: height / 6
        Repeater {
            model: card.cells
            delegate: Item {
                required property var modelData
                required property int index
                readonly property bool isToday: card.isCurrentMonth && modelData.inMonth && modelData.d === card.today.getDate()
                readonly property bool weekend: index % 7 >= 5
                width: grid.cellW; height: grid.cellH
                Seal {
                    visible: isToday
                    anchors.centerIn: parent
                    size: 22
                    glyph: ""
                    label: "Today"
                    outline: false
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.d
                    font.family: Theme.fontBody
                    font.pixelSize: 13
                    font.weight: isToday ? 600 : 400
                    color: isToday ? Theme.textOnSeal : (!modelData.inMonth ? Theme.withAlpha(Theme.textMuted, 0.45) : (weekend ? Theme.accent2 : Theme.text))
                    renderType: Text.NativeRendering
                    Behavior on color { ColorAnimation { duration: Theme.durTheme } }
                }
            }
        }
    }
}
