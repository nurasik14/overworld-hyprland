pragma Singleton
import QtQuick
import Quickshell

/*  TimeService — clock + the traditional two-hour period (時辰 / 时辰).
 *  TimeService.now (Date, 1 s precision) · TimeService.hhmm · TimeService.dateLabel ("Thu 29 Oct")
 *  TimeService.shichen(hour) → { glyph, name, pinyin, animal, range, start, end }
 *  TimeService.current → shichen(now.getHours())
 */
Singleton {
    id: root

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property date now: clock.date
    readonly property string hhmm: Qt.formatDateTime(now, "HH:mm")
    readonly property string dateLabel: Qt.formatDateTime(now, "ddd d MMM")
    readonly property string dateLong: Qt.formatDateTime(now, "dddd d MMMM")

    // 子23–1 丑1–3 寅3–5 卯5–7 辰7–9 巳9–11 午11–13 未13–15 申15–17 酉17–19 戌19–21 亥21–23
    readonly property var table: [
        { glyph: "子", pinyin: "zǐ",   animal: "Rat",     start: 23, end: 1,  name: "Hour of the Rat" },
        { glyph: "丑", pinyin: "chǒu", animal: "Ox",      start: 1,  end: 3,  name: "Hour of the Ox" },
        { glyph: "寅", pinyin: "yín",  animal: "Tiger",   start: 3,  end: 5,  name: "Hour of the Tiger" },
        { glyph: "卯", pinyin: "mǎo",  animal: "Rabbit",  start: 5,  end: 7,  name: "Hour of the Rabbit" },
        { glyph: "辰", pinyin: "chén", animal: "Dragon",  start: 7,  end: 9,  name: "Hour of the Dragon" },
        { glyph: "巳", pinyin: "sì",   animal: "Snake",   start: 9,  end: 11, name: "Hour of the Snake" },
        { glyph: "午", pinyin: "wǔ",   animal: "Horse",   start: 11, end: 13, name: "Hour of the Horse" },
        { glyph: "未", pinyin: "wèi",  animal: "Goat",    start: 13, end: 15, name: "Hour of the Goat" },
        { glyph: "申", pinyin: "shēn", animal: "Monkey",  start: 15, end: 17, name: "Hour of the Monkey" },
        { glyph: "酉", pinyin: "yǒu",  animal: "Rooster", start: 17, end: 19, name: "Hour of the Rooster" },
        { glyph: "戌", pinyin: "xū",   animal: "Dog",     start: 19, end: 21, name: "Hour of the Dog" },
        { glyph: "亥", pinyin: "hài",  animal: "Pig",     start: 21, end: 23, name: "Hour of the Pig" }
    ]

    function shichen(hour) {
        const h = ((Math.floor(hour) % 24) + 24) % 24;
        const idx = Math.floor(((h + 1) % 24) / 2);       // 23→0, 0→0, 1→1, 2→1, …
        const t = table[idx];
        const pad = n => (n < 10 ? "0" : "") + n;
        return {
            glyph: t.glyph, name: t.name, pinyin: t.pinyin, animal: t.animal,
            start: t.start, end: t.end,
            range: pad(t.start) + ":00–" + pad(t.end) + ":00",
            label: t.glyph + " · " + t.name + " (" + pad(t.start) + "–" + pad(t.end) + ")"
        };
    }
    readonly property var current: shichen(now.getHours())

    // Chinese numerals for workspaces 1–10
    readonly property var numerals: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    function numeral(n) { return (n >= 1 && n <= 10) ? numerals[n - 1] : String(n); }

    function relative(ms) {   // "now" · "3 min" · "2 h" · "Tue"
        const d = Date.now() - ms;
        if (d < 60000) return "now";
        if (d < 3600000) return Math.floor(d / 60000) + " min";
        if (d < 86400000) return Math.floor(d / 3600000) + " h";
        return Qt.formatDateTime(new Date(ms), "ddd");
    }
}
