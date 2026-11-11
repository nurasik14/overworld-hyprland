pragma Singleton
import QtQuick
import Quickshell
import qs.Services

/*  SemesterService — where we are in the CityU academic year, for the bar clock.
 *  SemesterService.label ("Sem A Wk 11" · "Sem A Revision" · "Sem A Exams" · "Sem Break" · "" outside any term)
 *  SemesterService.title ("Semester A 2026/27") · detail (tooltip line) · week (1-13, 0 outside teaching)
 *
 *  Dates: CityU Academic Calendar 2026/27, https://www.cityu.edu.hk/en/calendar/academic/2026-2027
 *  CityU numbers weeks Sunday to Saturday: WK 1 = Sun 30 Aug 2026, WK 13 = 22-28 Nov (last day of teaching).
 *  Add next terms as new rows (months are 0-based like JS Date: 0 = Jan, 7 = Aug).
 */
Singleton {
    id: root

    readonly property var terms: [
        { name: "A", title: "Semester A 2026/27",
          week1: [2026, 7, 30],          // Sunday of WK 1 (teaching starts Mon 31 Aug)
          teachEnd: [2026, 10, 28],      // last day of teaching
          revisionEnd: [2026, 11, 5],    // revision 30 Nov - 5 Dec
          examEnd: [2026, 11, 19],       // exams 7 - 19 Dec
          breakEnd: [2027, 0, 9] }       // semester break 21 Dec - 9 Jan
    ]

    function _d(a) { return new Date(a[0], a[1], a[2]); }
    function _fmt(a) { return Qt.formatDate(_d(a), "ddd d MMM"); }

    readonly property date today: {
        const n = TimeService.now;
        return new Date(n.getFullYear(), n.getMonth(), n.getDate());
    }

    // { term, phase: "teaching"|"revision"|"exams"|"break", week } or null
    readonly property var state: {
        const t = today;
        for (let i = 0; i < terms.length; i++) {
            const s = terms[i];
            if (t < _d(s.week1)) continue;
            if (t <= _d(s.teachEnd))
                return { term: s, phase: "teaching", week: Math.floor(Math.round((t - _d(s.week1)) / 86400000) / 7) + 1 };
            if (t <= _d(s.revisionEnd)) return { term: s, phase: "revision", week: 0 };
            if (t <= _d(s.examEnd)) return { term: s, phase: "exams", week: 0 };
            if (t <= _d(s.breakEnd)) return { term: s, phase: "break", week: 0 };
        }
        return null;
    }

    readonly property int week: state ? state.week : 0
    readonly property string title: state ? state.term.title : ""
    readonly property string label: {
        if (!state) return "";
        const n = "Sem " + state.term.name;
        switch (state.phase) {
        case "teaching": return n + " Wk " + state.week;
        case "revision": return n + " Revision";
        case "exams": return n + " Exams";
        default: return "Sem Break";
        }
    }
    readonly property string detail: {
        if (!state) return "";
        const s = state.term;
        const lastWeek = Math.floor(Math.round((_d(s.teachEnd) - _d(s.week1)) / 86400000) / 7) + 1;
        switch (state.phase) {
        case "teaching": return "Week " + state.week + " of " + lastWeek + ", teaching ends " + _fmt(s.teachEnd);
        case "revision": return "Revision week, exams from " + Qt.formatDate(new Date(_d(s.revisionEnd).getTime() + 2 * 86400000), "ddd d MMM");
        case "exams": return "Examination period until " + _fmt(s.examEnd);
        default: return "Semester break until " + _fmt(s.breakEnd);
        }
    }
}
