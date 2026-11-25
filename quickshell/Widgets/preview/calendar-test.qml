//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets.Services

/*  CalendarService tests, offscreen, against a temp cache and the fake backend (run: preview/calendar-render.sh svc light /tmp/x [soon]).
 *  Nothing live is touched and nothing is asked of Google.  PASS / FAIL lines and a RESULT line.
 */
ShellRoot {
    id: root
    readonly property var svc: CalendarService
    readonly property bool soonRun: Quickshell.env("OW_RENDER_STATE") === "soon"
    property int passes: 0
    property int fails: 0
    function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); if (ok) root.passes++; else root.fails++; }
    function dayAt(n) { return svc.addDays(svc.todayKey, n); }
    function sh(cmd) { runner.command = ["bash", "-c", cmd]; runner.running = true; }
    Process { id: runner }
    property int step: 0

    Window { visible: true; width: 10; height: 10 }          // something for the offscreen platform to run

    readonly property var steps: [
        () => {
            pass("loaded, state ok", svc.loaded && svc.state === "ok", svc.state);
            pass("fixture count (14, or 15 with --soon replacing one: 14)", svc.events.length === 14, svc.events.length);
            pass("lastSyncText is HH:MM", /^\d\d:\d\d$/.test(svc.lastSyncText), svc.lastSyncText);
            pass("statusText says synced", svc.statusText.indexOf("synced") === 0, svc.statusText);
            pass("todayKey format", /^\d{4}-\d\d-\d\d$/.test(svc.todayKey), svc.todayKey);
        },
        () => {
            pass("today has 5 events, all-day first", svc.countOn(dayAt(0)) === 5 && svc.eventsOn(dayAt(0))[0].allDay, svc.countOn(dayAt(0)));
            pass("a 2-day all-day event is on both days", svc.eventsOn(dayAt(3)).some(e => e.title === "Hackathon weekend") && svc.eventsOn(dayAt(4)).some(e => e.title === "Hackathon weekend"));
            pass("…and not on the day after", !svc.eventsOn(dayAt(5)).some(e => e.title === "Hackathon weekend"));
            pass("tag + stripped title", svc.eventsOn(dayAt(0)).some(e => e.tag === "class" && e.title === "Linear Algebra lecture"));
            pass("unknown tag kept", svc.eventsOn(dayAt(1)).some(e => e.tag === "weird"));
            pass("tagCode: known and unknown", svc.tagCode("class") === "a" && svc.tagCode("opp") === "6" && svc.tagCode("weird") === "7" && svc.tagCode("") === "7");
            pass("a day with nothing", svc.countOn(dayAt(20)) === 0 && svc.eventsOn(dayAt(20)).length === 0);
            const lec = svc.eventsOn(dayAt(0)).find(e => e.title === "Linear Algebra lecture");
            pass("timed event: HM strings", lec.startHM === "08:30" && lec.endHM === "10:00", lec.startHM + "-" + lec.endHM);
            pass("timeLabel / startLabel", svc.timeLabel(lec, dayAt(0)) === "08:30-10:00" && svc.startLabel(lec, dayAt(0)) === "08:30");
            const all = svc.eventsOn(dayAt(3)).find(e => e.allDay);
            pass("all-day labels", svc.timeLabel(all, dayAt(3)) === "all day" && svc.startLabel(all, dayAt(3)) === "all day");
            pass("titles carry no § (it is the colour code of the tooltips)", svc.events.every(e => e.title.indexOf("§") < 0));
        },
        () => {
            const up = svc.upcoming(20);
            let sorted = true;
            for (let i = 1; i < up.length; i++) {
                const a = up[i - 1], b = up[i];
                const ka = a.allDay ? (a.day > svc.todayKey ? a.day : svc.todayKey) + "1" : (a.startMs >= svc.nowMs ? a.day : svc.todayKey) + "0" + a.start;
                const kb = b.allDay ? (b.day > svc.todayKey ? b.day : svc.todayKey) + "1" : (b.startMs >= svc.nowMs ? b.day : svc.todayKey) + "0" + b.start;
                if (ka > kb) sorted = false;
            }
            pass("upcoming() is in the CLI's order", sorted && up.length > 0, up.length);
            pass("upcoming() has nothing that is over", up.every(e => e.allDay ? e.lastDay >= svc.todayKey : e.endMs > svc.nowMs));
            pass("upcoming(2) has 2", svc.upcoming(2).length === 2);
            const ni = svc.nextInfo;
            pass("nextInfo names an event", ni.event !== null && ni.text.length > 0, ni.text);
            if (root.soonRun) pass("--soon: within 15 min is flagged, text says In N min", ni.soon === true && /^In \d+ min: Programming lab$/.test(ni.text), ni.text);
            else pass("not flagged soon", ni.soon === false, ni.text);
            pass("left today counts timed events not over", ni.left === svc.eventsOn(dayAt(0)).filter(e => !e.allDay && e.endMs > svc.nowMs).length, ni.left);
        },
        () => {
            // view state
            svc.deselect(); svc.goToday();
            pass("goToday shows this month", svc.month === new Date().getMonth() && svc.year === new Date().getFullYear());
            svc.shiftMonth(-svc.month - 1);                          // to December of last year
            pass("shiftMonth wraps the year back", svc.month === 11 && svc.year === new Date().getFullYear() - 1, svc.year + "/" + svc.month);
            svc.shiftMonth(1);
            pass("…and forward", svc.month === 0 && svc.year === new Date().getFullYear(), svc.year + "/" + svc.month);
            svc.selectDay("2026-12-31");
            pass("selectDay selects and shows its month", svc.expanded && svc.selectedDay === "2026-12-31" && svc.month === 11 && svc.year === 2026);
            svc.shiftSelected(1);
            pass("shiftSelected crosses the year", svc.selectedDay === "2027-01-01" && svc.month === 0 && svc.year === 2027, svc.selectedDay);
            svc.selectDay("nonsense");
            pass("a bad day is ignored", svc.selectedDay === "2027-01-01");
            svc.deselect();
            pass("deselect", !svc.expanded && svc.selectedDay === "");
            svc.goToday(); svc.openAgenda();
            pass("openAgenda selects today", svc.selectedDay === svc.todayKey);
            svc.goToday();
            svc.shiftSelected(7); svc.goToday();
            pass("goToday in the agenda selects today again", svc.selectedDay === svc.todayKey);
            svc.closeAgenda();
            pass("parseDay: words, offsets, ISO, junk",
                 svc.parseDay("today") === svc.todayKey && svc.parseDay("tomorrow") === dayAt(1) && svc.parseDay("+3") === dayAt(3) && svc.parseDay("-1") === dayAt(-1)
                 && svc.parseDay("2026-12-05") === "2026-12-05" && svc.parseDay("2026-13-05") === "" && svc.parseDay("x") === "");
            pass("addDays crosses a month", svc.addDays("2026-11-30", 1) === "2026-12-01" && svc.addDays("2026-03-01", -1) === "2026-02-28");
            pass("fmtDay is English", svc.fmtDay("2026-11-25", "dddd d MMMM") === "Wednesday 25 November", svc.fmtDay("2026-11-25", "dddd d MMMM"));
            pass("add refuses an empty line and a busy runner is not started twice", svc.add("   ", "") === false);
        },
        () => {
            // a failing backend: the events stay, the state says offline
            sh("touch \"$FAKE_FAIL_FILE\"");
        },
        () => { pass("sync() starts", svc.sync() === true); },
        () => { pass("a second sync() while one runs is refused", svc.syncing ? svc.sync() === false : true); },
        () => {},
        () => {
            pass("backend failure: state offline", svc.state === "offline", svc.state);
            pass("…the events on screen are the last good ones", svc.events.length === 14, svc.events.length);
            pass("…statusText says offline + last sync", /^offline · last sync \d\d:\d\d$/.test(svc.statusText), svc.statusText);
            pass("…error carried", svc.error.indexOf("Max retries exceeded") >= 0, svc.error);
            sh("rm -f \"$FAKE_FAIL_FILE\"");
        },
        () => { svc.sync(); },
        () => {},
        () => {
            pass("recovered: ok again", svc.state === "ok" && svc.error === "", svc.state);
            svc.nowMs = Date.now() + 31 * 60000;
            pass("31 minutes later: stale", svc.state === "stale" && svc.statusText.indexOf("last sync") === 0, svc.state + " / " + svc.statusText);
            svc.nowMs = Date.now();
            // another process (the CLI, the other theme) syncs different events: the watcher picks them up without any call from us
            sh("cp \"$FAKE_SWAP\" \"$FAKE_EVENTS\" && \"$HYPR_GCAL_BIN\" sync -q");
        },
        () => {},
        () => {},
        () => {
            pass("an outside sync shows up (the busy fixture has 23 events)", svc.events.length === 23, svc.events.length);
            pass("…day +2 now has 9 (8 timed + all-day + the tutorial = 10)", svc.countOn(dayAt(2)) === 10, svc.countOn(dayAt(2)));
            sh("printf '{\"events\": [' > \"$HYPR_GCAL_CACHE\"");    // a half-written file
        },
        () => {},
        () => {},
        () => {
            pass("a half-written cache keeps the events on screen", svc.events.length === 23, svc.events.length);
            sh("\"$HYPR_GCAL_BIN\" sync -q");
        },
        () => {},
        () => {},
        () => {
            pass("…and the next sync repairs it", svc.events.length === 23 && svc.state === "ok", svc.events.length + " " + svc.state);
            console.warn("RESULT " + root.passes + " passed, " + root.fails + " failed");
            Qt.quit();
        }
    ]
    Timer {
        interval: 500; repeat: true; running: true
        property int waited: 0
        onTriggered: {
            if (root.step === 0 && !svc.loaded && (waited += 500) < 8000) return;
            if (root.step >= root.steps.length) { stop(); return; }
            try { root.steps[root.step++](); } catch (e) { root.pass("step " + root.step + " threw " + e, false); }
        }
    }
}
