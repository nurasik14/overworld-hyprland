pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  CalendarService — the user's Google Calendar events behind the Clock & Calendar card (Widgets/Calendar/).
 *    Data      ~/.cache/hypr-gcal/events.json (env HYPR_GCAL_CACHE), written by scripts/hypr-gcal (`sync`), the CLI shared with Apothecary and
 *              the terminal.  Event titles are read from Google (read only) and kept in that cache, nowhere else.  Only `add` ever writes to Google.
 *              {"updated", "ok", "error", "lastError", "range", "events": [{id,title,tag,start,end,allDay,day,lastDay,location,description,link}]}
 *    Reading   FileView with watchChanges: the CLI, a sync from another shell or the other theme show up at once.  A write is in place, so a
 *              half-written file is retried a few times and the events on screen stay.
 *    Syncing   `hypr-gcal sync -q` at start, every 10 min, after a resume (a gap of > 5 min between two 20 s ticks), after an add, on IPC `sync`;
 *              after a failure again every 2 min (a VPN coming up).  Failures are quiet: state "offline", the cached events stay.
 *    state     "loading" | "ok" | "stale" (last good sync > 30 min ago) | "offline" | "not-configured"        lastSyncText "14:02"
 *    events    [{…cache fields, startMs, endMs, startHM, endHM}] sorted like the CLI; byDay {"YYYY-MM-DD": [event…]} (multi-day events on each day)
 *    eventsOn(day) · countOn(day) · upcoming(n) · timeLabel(e, day) (with the end) · startLabel(e, day) (without) · nextInfo {event, text, soon, now, left} · tagCode(tag)
 *    View      year, month (0-based), selectedDay ("" = none; a day selected = the agenda view), expanded: shiftMonth(n) · goToday() · selectDay(key) ·
 *              deselect() · shiftSelected(days) · openAgenda() · closeAgenda()    (state lives here so IPC and every screen's card agree)
 *    Add       add(line, dayKey): `hypr-gcal add --parse <line> --date <day>` → adding, addError, signal added(text); parse(line, day) → preview
 *              (previewText / previewError, the same parser as the CLI).  The quick-add layer (Calendar/CalendarEditor.qml) shows while addOpen.
 *    IPC       qs -c overworld ipc call calendar sync | day <D> | today | next | prev | add <text> | status | list | upcoming | open | close | newEvent | openEvent <id>
 *              (next / prev = the month)
 *    Env       OW_NO_NOTIFY=1 (tests): no "Added" notification.  HYPR_GCAL_BIN: another hypr-gcal (tests).
 */
Singleton {
    id: root
    readonly property string path: Quickshell.env("HYPR_GCAL_CACHE")
        || ((Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/hypr-gcal/events.json")
    readonly property string script: Quickshell.env("HYPR_GCAL_BIN") || (Theme.repoDir + "/scripts/hypr-gcal")

    property var events: []
    property var byDay: ({})
    property bool loaded: false
    property bool okFlag: false
    property string error: ""
    property string updatedIso: ""
    property string lastErrorIso: ""
    property bool syncing: false
    property bool syncTried: false
    property double nowMs: Date.now()
    readonly property int staleMs: 30 * 60000

    // ---------------------------------------------------------------- day keys
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function dayKey(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
    function keyDate(k) { const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(k)); return m ? new Date(+m[1], +m[2] - 1, +m[3]) : null; }
    function fmtDay(k, fmt) { const d = keyDate(k); return d ? d.toLocaleDateString(Qt.locale("en_GB"), fmt) : ""; }   // always English, whatever the system locale
    function addDays(k, n) { const d = keyDate(k); if (!d) return k; d.setDate(d.getDate() + n); return dayKey(d); }
    readonly property string todayKey: dayKey(new Date(nowMs))
    function parseDay(s) {                                 // "YYYY-MM-DD", "today", "tomorrow", "+N" / "-N"
        const w = String(s || "").trim().toLowerCase();
        if (w === "today") return root.todayKey;
        if (w === "tomorrow") return root.addDays(root.todayKey, 1);
        if (w === "yesterday") return root.addDays(root.todayKey, -1);
        if (/^[+-]\d{1,4}$/.test(w)) return root.addDays(root.todayKey, parseInt(w));
        const d = root.keyDate(w);
        return d && root.dayKey(d) === w ? w : "";
    }

    // ---------------------------------------------------------------- reading
    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.apply(text())
        onLoadFailed: root.apply("")
        onFileChanged: reread.restart()
    }
    // a write in place truncates first: look again a moment later instead of believing an empty / half-written file
    Timer { id: reread; interval: 60; onTriggered: { root.rereads = 0; file.reload(); } }
    Timer { id: settle; interval: 120; onTriggered: { root.rereads++; file.reload(); } }
    property int rereads: 0
    property string lastKey: ""

    function normalize(raw) {
        if (!raw || typeof raw !== "object" || typeof raw.id !== "string" || typeof raw.day !== "string" || typeof raw.lastDay !== "string") return null;
        const e = {
            id: raw.id, title: String(raw.title || "").replace(/§/g, "?"), tag: String(raw.tag || ""), allDay: raw.allDay === true,
            start: String(raw.start || ""), end: String(raw.end || ""), day: raw.day, lastDay: raw.lastDay,
            location: String(raw.location || "").replace(/§/g, "?"), description: String(raw.description || "").replace(/§/g, "?"), link: String(raw.link || "")
        };
        if (e.allDay) {
            const a = root.keyDate(e.day), b = root.keyDate(root.addDays(e.lastDay, 1));
            if (!a || !b) return null;
            e.startMs = a.getTime(); e.endMs = b.getTime(); e.startHM = ""; e.endHM = "";
        } else {
            e.startMs = Date.parse(e.start); e.endMs = Date.parse(e.end);
            if (isNaN(e.startMs)) return null;
            if (isNaN(e.endMs)) e.endMs = e.startMs;
            const s = new Date(e.startMs), n = new Date(e.endMs);
            e.startHM = root.pad(s.getHours()) + ":" + root.pad(s.getMinutes());
            e.endHM = root.pad(n.getHours()) + ":" + root.pad(n.getMinutes());
        }
        return e;
    }
    function apply(t) {
        const s = String(t || "").trim();
        let o = null;
        if (s.length) {
            try { o = JSON.parse(s); } catch (e) { o = null; }
            if (!o || typeof o !== "object" || !Array.isArray(o.events)) {
                if (root.rereads < 4) settle.restart();               // an unreadable file mid-write: keep what is shown
                else console.warn("CalendarService:", root.path, "is not a valid events file; keeping the events on screen");
                return;
            }
        } else {
            if (root.loaded && root.events.length > 0 && root.rereads < 1) { settle.restart(); return; }
            root.rereads = 0;
            root.loaded = false;
            return;
        }
        root.rereads = 0;
        root.okFlag = o.ok === true;
        root.error = typeof o.error === "string" ? o.error : "";
        root.updatedIso = typeof o.updated === "string" ? o.updated : "";
        root.lastErrorIso = typeof o.lastError === "string" ? o.lastError : "";
        const key = JSON.stringify(o.events);
        if (key !== root.lastKey || !root.loaded) {                  // same events (a failed sync, our own write coming back): keep the bindings still
            root.lastKey = key;
            const list = [], map = {};
            for (let i = 0; i < o.events.length; i++) {
                const e = root.normalize(o.events[i]);
                if (!e) continue;
                list.push(e);
                let k = e.day;
                for (let n = 0; n < 62 && k <= e.lastDay; n++) {
                    (map[k] = map[k] || []).push(e);
                    k = root.addDays(k, 1);
                }
            }
            root.events = list;
            root.byDay = map;
        }
        root.loaded = true;
    }

    // ---------------------------------------------------------------- state
    readonly property string state: {
        if (error === "not-configured") return "not-configured";
        if (!loaded) return syncTried && !syncing ? "offline" : "loading";
        if (!okFlag) return "offline";
        const u = Date.parse(updatedIso);
        return !isNaN(u) && nowMs - u > staleMs ? "stale" : "ok";
    }
    readonly property string lastSyncText: {
        const u = new Date(Date.parse(updatedIso));
        if (isNaN(u.getTime())) return "";
        const hm = pad(u.getHours()) + ":" + pad(u.getMinutes());
        return dayKey(u) === todayKey ? hm : u.toLocaleDateString(Qt.locale("en_GB"), "d MMM") + " " + hm;
    }
    readonly property string statusText: {
        switch (state) {
        case "not-configured": return "Not connected";
        case "loading": return "syncing…";
        case "offline": return "offline" + (lastSyncText ? " · last sync " + lastSyncText : "");
        case "stale": return "last sync " + lastSyncText;
        default: return syncing ? "syncing…" : "synced " + lastSyncText;
        }
    }

    // ---------------------------------------------------------------- queries
    function eventsOn(day) { return root.byDay[day] || []; }
    function countOn(day) { return (root.byDay[day] || []).length; }
    function timeLabel(e, day) {                                     // 'all day', '09:30–11:00', '14:00→', '…–18:00', '…'
        if (e.allDay) return "all day";
        if (e.day === e.lastDay) return e.startHM + (e.endMs === e.startMs ? "" : "-" + e.endHM);
        if (day === e.day) return e.startHM + "→";
        if (day === e.lastDay) return "…-" + e.endHM;
        return "…";
    }
    function startLabel(e, day) {                                    // just the start: 'all day', '09:30', '14:00→', '…-18:00', '…'
        if (e.allDay) return "all day";
        if (e.day === e.lastDay) return e.startHM;
        if (day === e.day) return e.startHM + "→";
        return day === e.lastDay ? "…-" + e.endHM : "…";
    }
    // the same order as `hypr-gcal next`: timed events not over first, an all-day event after the timed ones of its day
    function upcoming(n) {
        const t = root.nowMs, today = root.todayKey, out = [];
        for (let i = 0; i < root.events.length; i++) {
            const e = root.events[i];
            let key;
            if (e.allDay) { if (e.lastDay < today) continue; key = (e.day > today ? e.day : today) + "1"; }
            else { if (e.endMs <= t) continue; key = (e.startMs >= t ? e.day : today) + "0" + e.start; }
            out.push({ key: key, e: e });
        }
        out.sort((a, b) => a.key < b.key ? -1 : a.key > b.key ? 1 : 0);
        return out.slice(0, n).map(x => x.e);
    }
    function leftToday() {                                           // timed events today that are not over
        let n = 0;
        const l = root.eventsOn(root.todayKey);
        for (let i = 0; i < l.length; i++) if (!l[i].allDay && l[i].endMs > root.nowMs) n++;
        return n;
    }
    function rel(minutes) { return minutes < 60 ? minutes + " min" : Math.floor(minutes / 60) + " h" + (minutes % 60 ? " " + (minutes % 60) + " min" : ""); }
    // what the strip under the clock says
    readonly property var nextInfo: {
        const dummy = root.nowMs;                                    // re-evaluate on every tick
        const u = root.upcoming(1);
        const left = root.leftToday();
        if (u.length === 0) return { event: null, text: "", soon: false, now: false, left: left };
        const e = u[0], t = root.nowMs, today = root.todayKey;
        let text, soon = false, now = false;
        const dl = e.day === root.addDays(today, 1) ? "Tom " : root.fmtDay(e.day, "ddd d") + " ";
        if (e.allDay) {
            text = e.day <= today ? "Today: " + e.title : "Next: " + dl + e.title;
        } else if (e.startMs <= t) {
            now = true;
            text = "Now: " + e.title;
        } else {
            const min = Math.ceil((e.startMs - t) / 60000);
            soon = min <= 15;
            if (e.day === today) text = (min <= 90 ? "In " + root.rel(min) + ": " : "Next: " + e.startHM + " ") + e.title;
            else text = "Next: " + dl + e.startHM + " " + e.title;
        }
        return { event: e, text: text, soon: soon, now: now, left: left };
    }
    // the colour a tag gets: a §-code of the game's palette (the card turns it into a chip)
    function tagCode(tag) {
        return ({ class: "a", lecture: "a", tutorial: "a", lab: "a", opp: "6", email: "b", mail: "b", exam: "c", test: "c", quiz: "c", deadline: "c", meeting: "d", todo: "e", club: "9" })[String(tag || "").toLowerCase()] || "7";
    }

    // ---------------------------------------------------------------- syncing
    Process {
        id: syncer
        command: [root.script, "sync", "-q"]
        onExited: code => {
            root.syncing = false;
            root.syncTried = true;
            file.reload();
            afterSync.restart();
        }
    }
    Timer { id: afterSync; interval: 400; onTriggered: file.reload() }
    function sync() {
        if (syncer.running || root.syncing) return false;
        root.syncing = true;
        syncer.running = true;
        return true;
    }
    Timer { interval: 600000; repeat: true; running: true; onTriggered: root.sync() }
    Timer {                                  // while offline (a VPN coming up…) try again sooner; not for a missing backend
        interval: 120000; repeat: true
        running: root.state === "offline"
        onTriggered: root.sync()
    }
    property double lastTick: Date.now()
    Timer {                                  // the clock for "in 12 min"; a gap in it = the laptop slept
        interval: 20000; repeat: true; running: true
        onTriggered: {
            const t = Date.now();
            const gap = t - root.lastTick;
            root.lastTick = t;
            root.nowMs = t;
            if (gap > 300000) resumeSync.restart();
        }
    }
    Timer { id: resumeSync; interval: 4000; onTriggered: root.sync() }          // the network needs a moment after a resume
    Component.onCompleted: Qt.callLater(root.sync)

    // ---------------------------------------------------------------- view state: the month shown, the selected day (= the agenda view)
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    property string selectedDay: ""
    readonly property bool expanded: selectedDay !== ""
    function shiftMonth(n) {
        let m = root.month + n, y = root.year;
        while (m < 0) { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        root.month = m; root.year = y;
    }
    function showMonthOf(key) {
        const d = root.keyDate(key);
        if (d) { root.year = d.getFullYear(); root.month = d.getMonth(); }
    }
    function selectDay(key) {
        if (!root.keyDate(key)) return;
        root.selectedDay = key;
        root.showMonthOf(key);
    }
    function deselect() { root.selectedDay = ""; }
    function goToday() {
        root.year = new Date(root.nowMs).getFullYear();
        root.month = new Date(root.nowMs).getMonth();
        if (root.expanded) root.selectedDay = root.todayKey;
    }
    function shiftSelected(days) {
        if (!root.expanded) return;
        root.selectDay(root.addDays(root.selectedDay, days));
    }
    function openAgenda() { if (!root.expanded) root.selectDay(root.todayKey); }
    function closeAgenda() { root.deselect(); }

    // ---------------------------------------------------------------- where the card is (the quick-add layer opens over it)
    property var cardRects: ({})
    function setCardRect(screenName, rect) {
        const n = Object.assign({}, root.cardRects);
        n[screenName] = rect;
        root.cardRects = n;
    }

    // ---------------------------------------------------------------- adding (the CLI parses the line and creates the event)
    property bool addOpen: false
    property string addDay: ""
    property bool adding: false
    property string addError: ""
    property string lastAdded: ""
    signal added(string text)
    function cap(s) { return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s; }
    function firstError(text) {
        const l = String(text || "").split("\n").map(x => x.trim()).filter(x => x.length);
        return (l.length ? l[0] : "").replace(/^hypr-gcal: /, "");
    }
    Process {
        id: adder
        stdout: StdioCollector { id: addOut }
        stderr: StdioCollector { id: addErr }
        onExited: code => {
            root.adding = false;
            if (code === 0) {
                root.addError = "";
                root.lastAdded = String(addOut.text).trim().split("\n")[0].replace(/^added: /, "");
                if (Quickshell.env("OW_NO_NOTIFY") !== "1")
                    Quickshell.execDetached(["notify-send", "-a", "Calendar", "Event added", root.lastAdded]);
                file.reload();
                afterSync.restart();
                root.added(root.lastAdded);
            } else {
                const m = root.firstError(addErr.text);
                root.addError = code === 2 && m === "not-configured" ? "Google Calendar is not connected (overworld help calendar)" : (m || "could not add the event");
            }
        }
    }
    function add(line, day) {
        const l = String(line || "").trim();
        if (!l.length || adder.running) return false;
        root.adding = true;
        root.addError = "";
        adder.command = [root.script, "add", "--parse", l, "--date", day && root.keyDate(day) ? day : (root.selectedDay || root.todayKey)];
        adder.running = true;
        return true;
    }
    property string previewText: ""
    property string previewError: ""
    Process {
        id: parser
        stdout: StdioCollector { id: parseOut }
        stderr: StdioCollector { id: parseErr }
        onExited: code => {
            if (code === 0) {
                try {
                    const o = JSON.parse(String(parseOut.text));
                    const s = new Date(Date.parse(o.start)), e = new Date(Date.parse(o.end));
                    const when = o.allDay ? "all day" : root.pad(s.getHours()) + ":" + root.pad(s.getMinutes()) + "-" + root.pad(e.getHours()) + ":" + root.pad(e.getMinutes());
                    root.previewText = when + " · " + o.title + (o.location ? " @" + o.location : "");
                    root.previewError = "";
                } catch (x) { root.previewText = ""; root.previewError = ""; }
            } else {
                root.previewText = "";
                root.previewError = root.firstError(parseErr.text);
            }
            if (root.previewQueued) { root.previewQueued = false; root.runPreview(); }
        }
    }
    property bool previewQueued: false
    property string previewLine: ""
    property string previewForDay: ""
    function runPreview() {
        parser.command = [root.script, "parse", root.previewLine, "--date", root.previewForDay];
        parser.running = true;
    }
    function parse(line, day) {
        const l = String(line || "").trim();
        root.previewLine = l;
        root.previewForDay = day && root.keyDate(day) ? day : (root.selectedDay || root.todayKey);
        if (!l.length) { root.previewText = ""; root.previewError = ""; return; }
        if (parser.running) root.previewQueued = true;
        else root.runPreview();
    }

    function openAdd(day) {
        if (root.addOpen) return;
        if (ShellState.anyOpen) ShellState.closeAll();           // one modal screen at a time (GameUi closes its screens on addOpenChanged)
        NotesService.closeEditor();
        ProjectsService.closeDialog();
        root.addDay = day && root.keyDate(day) ? day : (root.selectedDay || root.todayKey);
        root.addError = "";
        root.previewText = ""; root.previewError = "";
        root.addOpen = true;
    }
    function closeAdd() { root.addOpen = false; }
    Connections {
        target: ShellState
        function onAnyOpenChanged() { if (ShellState.anyOpen) root.closeAdd(); }
    }
    Connections {
        target: NotesService
        function onEditorOpenChanged() { if (NotesService.editorOpen) root.closeAdd(); }
    }
    Connections {
        target: ProjectsService
        function onDialogOpenChanged() { if (ProjectsService.dialogOpen) root.closeAdd(); }
    }

    // ---------------------------------------------------------------- opening an event in the browser
    function openEvent(id) {
        if (!id) return false;
        Quickshell.execDetached([root.script, "open", id]);
        return true;
    }

    // ---------------------------------------------------------------- IPC
    function lineOf(e, day) { return root.timeLabel(e, day) + "  " + (e.tag ? "[" + e.tag + "] " : "") + e.title + (e.location ? "  @" + e.location : ""); }
    function listOf(day) {
        const l = root.eventsOn(day);
        return l.length ? day + "\n" + l.map(e => "  " + root.lineOf(e, day)).join("\n") : day + ": no events";
    }
    IpcHandler {
        target: "calendar"
        function sync(): string { return root.sync() ? "syncing" : "already syncing" }
        function day(d: string): string {
            const k = root.parseDay(d);
            if (!k) return "not a day: " + d;
            root.selectDay(k);
            return root.listOf(k);
        }
        function today(): string { root.selectDay(root.todayKey); return root.listOf(root.todayKey); }
        function next(): string { root.shiftMonth(1); return new Date(root.year, root.month, 1).toLocaleDateString(Qt.locale("en_GB"), "MMMM yyyy"); }
        function prev(): string { root.shiftMonth(-1); return new Date(root.year, root.month, 1).toLocaleDateString(Qt.locale("en_GB"), "MMMM yyyy"); }
        function add(text: string): string {
            if (!text.trim().length) return "nothing to add";
            return root.add(text, root.selectedDay || root.todayKey) ? "adding to " + (root.selectedDay || root.todayKey) : "busy";
        }
        function status(): string { return root.state + " · " + root.events.length + " events · " + root.statusText + (root.expanded ? " · day " + root.selectedDay : ""); }
        function list(): string { return root.listOf(root.selectedDay || root.todayKey); }
        function upcoming(): string { return root.nextInfo.event ? root.nextInfo.text : "nothing upcoming"; }
        function open(): string { root.openAgenda(); return "agenda " + root.selectedDay; }
        function close(): string { root.closeAgenda(); return "month view"; }
        function newEvent(): string { root.openAdd(root.selectedDay || root.todayKey); return "adding to " + root.addDay; }
        function openEvent(id: string): string { return root.openEvent(id) ? "opening" : "no id"; }
    }
}
