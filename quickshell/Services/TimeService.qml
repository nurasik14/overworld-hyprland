pragma Singleton
import QtQuick
import Quickshell

/*  TimeService — clock + the Minecraft way of saying it.
 *  TimeService.now (Date, 1 s precision) · hhmm · dateLabel ("Thu 5 Nov") · dateLong ("Thursday 5 November")
 *  TimeService.dayOfYear (309) · mcClock ("Day 309, 14:32") · phase ("Morning" … the game's named times)
 *  TimeService.relative(ms) ("now" · "3 min" · "2 h" · "Tue") · numeral(n) (workspace label)
 */
Singleton {
    id: root

    SystemClock { id: clock; precision: SystemClock.Seconds }
    // clock.date is briefly undefined while a hot reload rebuilds the singleton ("Unable to assign [undefined] to QDateTime")
    readonly property date now: clock.date instanceof Date && !isNaN(clock.date.getTime()) ? clock.date : new Date()
    readonly property string hhmm: Qt.formatDateTime(now, "HH:mm")
    readonly property string dateLabel: Qt.formatDateTime(now, "ddd d MMM")
    readonly property string dateLong: Qt.formatDateTime(now, "dddd d MMMM yyyy")
    readonly property int dayOfYear: Math.round((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - new Date(now.getFullYear(), 0, 1)) / 86400000) + 1
    readonly property string mcClock: "Day " + dayOfYear + ", " + hhmm
    // the names /time set uses
    readonly property string phase: {
        const h = now.getHours();
        if (h < 5) return "Midnight";
        if (h < 11) return "Morning";
        if (h < 14) return "Noon";
        if (h < 18) return "Afternoon";
        if (h < 21) return "Sunset";
        return "Night";
    }

    function numeral(n) { return String(n); }

    function relative(ms) {   // "now" · "3 min" · "2 h" · "Tue"
        const d = Date.now() - ms;
        if (d < 60000) return "now";
        if (d < 3600000) return Math.floor(d / 60000) + " min";
        if (d < 86400000) return Math.floor(d / 3600000) + " h";
        return Qt.formatDateTime(new Date(ms), "ddd");
    }
}
