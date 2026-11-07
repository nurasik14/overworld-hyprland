pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

/*  NotesService — the pad of sticky notes behind the Notes card (Widgets/Notes/): raw, stray thoughts, no titles, no structure.
 *    File       ~/.local/share/hypr-notes/notes.json, ONE pad shared with Apothecary and the stock desktop (`hypr-notes`); env
 *               HYPR_NOTES_FILE overrides it (tests).  {"sheets": [{"id", "text", "created": ISO, "updated": ISO, "color"?}], "current": id}
 *               Created by the first note; the user's own notes only.
 *    Reading    FileView with watchChanges, so the CLI, an editor and the other theme show up at once.
 *    Writing    every change is a read-modify-write by notes-write.sh -> scripts/hypr-notes (the rules) under flock and IN PLACE, the same
 *               code the CLI runs.  Sheets on screen are what the file says; only the flip is immediate (currentId, written 400 ms
 *               later, so spinning the wheel does not write per notch).  A write that is refused (an invalid file, a full disk) leaves its
 *               text in <file>.rescue (scripts/hypr-notes), says so with one notification, and a draft stays unsaved so the next save retries.
 *    sheets / count / current / currentIndex    file order = the numbers of `hypr-notes list` and the page counter
 *    add(text) · next() · prev() · flip(±n) · goTo(id) · remove(id) · removeCurrent() · undoRemove()
 *    undo        {preview, count, batches} for 5 s after a tear-off (removes in that window pile up); signal sheetTorn() for the crumbs
 *    relTime(iso, nowMs)   "just now", "3 min ago", "2 h ago", "yesterday", "5 days ago"; nowTick moves every 30 s for bindings
 *    Editor      The editor is a draft over one sheet: openEditor("current"|"new"), closeEditor(), typed(text) while typing
 *                (autosaved after 700 ms; a blank draft is never written), newDraft(), flipDraft(±1), signal draftLoaded(text).
 *                An empty sheet is dropped on close or on flipping away (a sheet that had text gets the 5 s Undo with its last saved text).
 *                Notes/NotesEditor.qml (namespace overworld-notes) shows while editorOpen is true.
 *    cardRects   {screenName: {x, y, w, h, shown}} where the card's paper is on each output: the editor opens right on top of it.
 *    IPC         qs -c overworld ipc call notes open | newSheet | add <text> | next | prev | remove | undo | list | status | flush
 *                (flush = write everything now, detached: `overworld` calls it before it stops the shell)
 */
Singleton {
    id: root
    readonly property string path: Quickshell.env("HYPR_NOTES_FILE")
        || ((Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/hypr-notes/notes.json")
    readonly property string script: Qt.resolvedUrl("notes-write.sh").toString().replace(/^file:\/\//, "")
    readonly property int maxChars: 4000

    property var sheets: []
    property bool loaded: false
    property string currentId: ""
    readonly property int count: sheets.length
    readonly property int currentIndex: indexOf(currentId, sheets)
    readonly property var current: currentIndex >= 0 ? sheets[currentIndex] : null
    function indexOf(id, list) { const l = list || root.sheets; for (let i = 0; i < l.length; i++) if (l[i].id === id) return i; return -1; }
    function byId(id) { const k = indexOf(id); return k >= 0 ? sheets[k] : null; }
    function isBlank(s) { return !/\S/.test(String(s || "")); }
    function capped(s) {                                     // the cap counts characters like the CLI does, not UTF-16 units
        if (s.length <= root.maxChars) return s;
        const a = [...s];                                    // spread walks code points; this engine's Array.from walks UTF-16 units
        return a.length > root.maxChars ? a.slice(0, root.maxChars).join("") : s;
    }
    function firstLine(s) { const l = String(s || "").split("\n").filter(x => /\S/.test(x)); return l.length ? l[0].trim() : ""; }

    signal sheetTorn()
    signal draftLoaded(string text)

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
    // a write in flight truncates the file first: read again a moment later instead of believing an empty / half-written file
    Timer { id: reread; interval: 60; onTriggered: { root.rereads = 0; file.reload(); } }
    Timer { id: settle; interval: 120; onTriggered: { root.rereads++; file.reload(); } }
    property int rereads: 0
    // a missing file is not watched until it exists: look again after our own writes (apply() finds it)
    Timer { id: afterWrite; interval: 250; onTriggered: file.reload() }
    // the other theme / the CLI may create the shared file while this shell runs: a missing or empty pad is polled slowly
    Timer { interval: 4000; repeat: true; running: !root.loaded || root.count === 0; onTriggered: file.reload() }

    property string lastKey: ""
    function apply(t) {
        let list = null, fileCurrent = "";
        const s = String(t || "").trim();
        if (s.length) {
            try {
                const o = JSON.parse(s);
                if (o && Array.isArray(o.sheets)) {
                    list = o.sheets.filter(x => x && typeof x === "object" && typeof x.id === "string" && typeof x.text === "string");
                    fileCurrent = typeof o.current === "string" ? o.current : "";
                }
            } catch (e) { list = null; }
            if (list === null) {                         // unreadable now: keep what is shown, try again (an external edit mid-save)
                if (root.rereads < 4) settle.restart();
                else console.warn("NotesService:", root.path, "is not a valid notes file; keeping the sheets on screen");
                return;
            }
        } else {                                         // empty or missing: a real "no notes" unless we are mid-write
            if (root.loaded && root.sheets.length > 0 && root.rereads < 1) { settle.restart(); return; }
            list = [];
        }
        root.rereads = 0;
        const key = JSON.stringify(list);
        if (key !== root.lastKey || !root.loaded) {        // same sheets (our own write coming back, the slow poll): keep the bindings still
            root.lastKey = key;
            root.sheets = list;
        }
        root.loaded = true;
        // a flip that is not written yet wins over what the file says; anything else (an add from the CLI…) moves the card
        if (!(root.flipPending && root.indexOf(root.currentId, list) >= 0))
            root.currentId = root.indexOf(fileCurrent, list) >= 0 ? fileCurrent : (list.length ? list[list.length - 1].id : "");
        if (root.queue.length === 0 && !runner.running) root.pendingText = ({});
        if (root.editorOpen) root.draftSeesFile();
    }

    // ---------------------------------------------------------------- writing (one script run at a time, in order)
    property var queue: []
    function run(args) {
        root.queue = root.queue.concat([args]);
        if (!runner.running) root.startNext();
    }
    function startNext() {
        if (root.queue.length === 0) return;
        runner.command = ["bash", root.script, root.path].concat(root.queue[0]);
        runner.running = true;
    }
    Process {
        id: runner
        stderr: StdioCollector { id: errOut }
        onExited: code => {
            const done = root.queue[0];
            if (code !== 0) root.writeFailed(done, String(errOut.text).trim() || ("notes-write.sh exited " + code));
            root.queue = root.queue.slice(1);
            if (done && done[0] === "current" && !flipTimer.running && !root.queue.some(q => q[0] === "current")) root.flipPending = false;
            afterWrite.restart();
            if (root.queue.length > 0) root.startNext();
        }
    }

    property var pendingText: ({})                   // id → text queued or written but not read back yet
    property int saveFailures: 0
    property double lastFailNotice: 0
    function writeFailed(op, why) {
        console.warn("NotesService:", why);
        if (!op) return;
        if (op[0] === "put") {
            delete root.pendingText[op[1]];
            if (op[1] === root.draftId) root.draftSaved = "\u0001unsaved";     // still dirty: the next save or the close tries again
        }
        if (op[0] !== "put" && op[0] !== "insert") return;
        root.saveFailures++;
        if (Date.now() - root.lastFailNotice > 30000 && Quickshell.env("HYPR_NOTES_QUIET") !== "1") {
            root.lastFailNotice = Date.now();
            Quickshell.execDetached(["notify-send", "-a", "Notes", "Note not saved", root.path + " cannot be written. Your text is in " + root.path + ".rescue"]);
        }
    }
    // Everything still to be written, in one detached chain: it outlives this process, which a quit kills along with `runner`.  Every op the
    // service queues is safe to repeat, so the one in flight may run twice.
    function drainDetached(extra) {
        const ops = root.queue.concat(extra);
        if (ops.length === 0) return;
        const argv = ["bash", "-c", 'f=$1; s=$2; shift 2; while (( $# )); do n=$1; shift; bash "$s" "$f" "${@:1:n}"; shift "$n"; done', "notes-drain", root.path, root.script];
        ops.forEach(o => { argv.push(String(o.length)); o.forEach(a => argv.push(String(a))); });
        Quickshell.execDetached(argv);
    }
    function flushNow() {
        saveTimer.stop();
        const extra = [];
        if (flipTimer.running) { flipTimer.stop(); root.flipPending = false; extra.push(["current", root.currentId]); }
        if (root.draftId.length && root.draftDirty && !root.isBlank(root.draftText)) {
            extra.push(["put", root.draftId, root.draftText]);
            root.pendingText[root.draftId] = root.draftText;
            root.draftSaved = root.draftText;
            root.draftInFile = true;
        }
        root.drainDetached(extra);
        root.queue = root.queue.slice(0, runner.running ? 1 : 0);
    }

    function newId() { return Date.now().toString(16) + ("000" + Math.floor(Math.random() * 65536).toString(16)).slice(-4); }
    function add(text) {
        const t = String(text || "");
        if (root.isBlank(t)) return false;
        root.flipPending = false;
        flipTimer.stop();
        root.run(["put", root.newId(), root.capped(t)]);     // put, with the id made here: safe to repeat (see drainDetached)
        return true;
    }

    // ---- flipping
    property bool flipPending: false
    Timer {
        id: flipTimer
        interval: 400
        onTriggered: root.run(["current", root.currentId])
    }
    function goTo(id) {
        if (id === root.currentId && !root.flipPending) return;
        root.currentId = id;
        root.flipPending = true;
        flipTimer.restart();
    }
    function flip(delta) {                                  // no wrap-around: the pad has a first and a last sheet, like a book
        const t = root.currentIndex + delta;
        if (t < 0 || t >= root.count) return false;
        root.goTo(root.sheets[t].id);
        return true;
    }
    function flushFlip() {                                  // the file must know which sheet is showing before a tear-off moves on from it
        if (flipTimer.running) { flipTimer.stop(); root.run(["current", root.currentId]); }
    }
    function next() { return flip(1); }
    function prev() { return flip(-1); }

    // ---- tear-off + undo
    property var undo: null
    function rememberRemoved(entries) {                      // removes within the 5 s window pile up: Undo brings back all, last first
        const batches = (root.undo ? root.undo.batches : []).concat([entries]);
        root.undo = { preview: root.firstLine(entries[0].item.text), count: batches.reduce((n, b) => n + b.length, 0), batches: batches };
        undoTimer.restart();
    }
    Timer { id: undoTimer; interval: 5000; onTriggered: root.undo = null }
    function remove(id) {
        const k = root.indexOf(id);
        if (k < 0) return false;
        if (root.undo && root.undo.batches.some(b => b.some(e => e.item.id === id))) return false;     // a double click, before the file is read back
        root.flushFlip();
        root.rememberRemoved([{ item: root.sheets[k], index: k }]);
        root.sheetTorn();
        root.run(["remove", id]);
        return true;
    }
    function removeCurrent() {
        if (!root.editorOpen) return root.current ? root.remove(root.current.id) : false;
        // tearing off the sheet being edited: what was on it goes in the Undo, the editor moves to the next sheet
        const id = root.draftId, k = root.indexOf(id);
        saveTimer.stop();
        const hadText = !root.isBlank(root.draftText);
        if (k < 0 && !root.draftInFile) {                    // never written: nothing to remove, but typed text still gets its Undo
            if (hadText) { root.rememberRemoved([{ item: root.newSheetOf(id, root.draftText), index: root.count }]); root.sheetTorn(); }
            root.draftId = "";
            root.beginDraft(root.current);
            return hadText;
        }
        root.flushFlip();
        const item = k >= 0 ? Object.assign({}, root.sheets[k]) : root.lastDraftSheet();
        if (hadText) item.text = root.draftText;
        root.rememberRemoved([{ item: item, index: k >= 0 ? k : root.count }]);
        root.sheetTorn();
        root.draftInFile = false;
        root.draftId = "";
        root.run(["remove", id]);
        const rest = root.sheets.filter(s => s.id !== id);
        root.beginDraft(rest.length ? rest[Math.min(k >= 0 ? k : rest.length - 1, rest.length - 1)] : null);
        return true;
    }
    function undoRemove() {
        const u = root.undo;
        if (!u) return false;
        root.undo = null;
        undoTimer.stop();
        root.flipPending = false;                            // each insert makes its sheet current
        flipTimer.stop();
        u.batches.slice().reverse().forEach(b => b.forEach(e => root.run(["insert", JSON.stringify(e.item), String(e.index)])));
        return true;
    }

    // ---------------------------------------------------------------- the editor's draft
    property bool editorOpen: false
    property string draftId: ""
    property string draftText: ""
    property string draftSaved: ""                   // what the file has (or will have once the queue has run) for this sheet
    property bool draftInFile: false
    property var draftOriginal: null                 // the sheet as it was when the draft began: a blanked one can be undone
    readonly property bool draftDirty: draftText !== draftSaved
    // the page counter of the editor: a sheet that is not written yet counts as the next one
    readonly property int draftPages: count + (indexOf(draftId, sheets) < 0 ? 1 : 0)
    readonly property int draftPage: { const k = indexOf(draftId, sheets); return k >= 0 ? k + 1 : count + 1; }

    Timer { id: saveTimer; interval: 700; onTriggered: root.saveDraft() }

    function beginDraft(sheet) {
        saveTimer.stop();
        root.draftId = sheet ? sheet.id : root.newId();
        // a save that has not come back from the file yet is newer than what `sheets` says
        const pending = sheet ? root.pendingText[sheet.id] : undefined;
        root.draftText = sheet ? (pending !== undefined ? pending : sheet.text) : "";
        root.draftSaved = root.draftText;
        root.draftInFile = !!sheet;
        root.draftOriginal = sheet ? Object.assign({}, sheet) : null;
        if (sheet) root.goTo(sheet.id);
        root.draftLoaded(root.draftText);
    }
    function typed(text) {
        const t = root.capped(String(text));
        if (t === root.draftText) return;
        root.draftText = t;
        saveTimer.restart();
    }
    function saveDraft() {
        saveTimer.stop();
        if (!root.draftId.length || root.isBlank(root.draftText) || root.draftText === root.draftSaved) return;
        root.flipPending = false;
        flipTimer.stop();
        root.run(["put", root.draftId, root.draftText]);
        root.pendingText[root.draftId] = root.draftText;
        root.draftSaved = root.draftText;
        root.draftInFile = true;
    }
    function newSheetOf(id, text) {
        const now = new Date().toISOString().replace(/\.\d+Z$/, "Z");
        return { id: id, text: text, created: now, updated: now };
    }
    function lastDraftSheet() {                       // the draft's sheet with its last saved text: what an Undo should bring back
        const saved = root.isBlank(root.draftSaved) || root.draftSaved === "\u0001unsaved" ? null : root.draftSaved;
        if (!root.draftOriginal) return root.newSheetOf(root.draftId, saved === null ? "" : saved);
        return saved === null ? Object.assign({}, root.draftOriginal) : Object.assign({}, root.draftOriginal, { text: saved });
    }
    function endDraft() {                             // save, or drop the sheet when it is empty
        saveTimer.stop();
        if (!root.draftId.length) return;
        if (root.isBlank(root.draftText)) {
            if (root.draftInFile) {
                const k = root.indexOf(root.draftId);
                const item = root.lastDraftSheet();
                if (!root.isBlank(item.text)) { root.rememberRemoved([{ item: item, index: k >= 0 ? k : root.count }]); root.sheetTorn(); }
                root.flushFlip();
                root.run(["remove", root.draftId]);
            }
        } else root.saveDraft();
        root.draftId = "";
        root.draftText = "";
        root.draftSaved = "";
        root.draftInFile = false;
        root.draftOriginal = null;
    }
    function newDraft() {
        if (root.draftId.length && !root.draftInFile && root.isBlank(root.draftText)) return;       // already on a blank sheet
        root.endDraft();
        root.beginDraft(null);
    }
    function flipDraft(delta) {
        const k = root.indexOf(root.draftId);
        const t = (k >= 0 ? k : root.count) + delta;
        if (t < 0 || t >= root.count) return false;
        const target = root.sheets[t];
        if (target.id === root.draftId) return false;
        root.endDraft();
        root.beginDraft(target);
        return true;
    }
    function draftSeesFile() {                        // the file moved while the editor is open (the CLI, an editor, the other theme)
        if (!root.draftId.length || root.draftDirty || root.queue.length > 0 || runner.running) return;
        const s = root.byId(root.draftId);
        if (s && s.text !== root.draftSaved) {        // nothing typed since the last save: show the new text
            root.draftText = s.text;
            root.draftSaved = s.text;
            root.draftLoaded(s.text);
        } else if (!s && root.draftInFile) {          // torn off elsewhere: do not bring it back, move on
            root.draftInFile = false;
            root.draftId = "";
            root.beginDraft(root.current);
        }
    }

    function openEditor(mode) {
        if (root.editorOpen) { if (mode === "new") root.newDraft(); return; }
        if (ShellState.anyOpen) ShellState.closeAll();      // one modal screen at a time
        ProjectsService.closeDialog();
        root.editorOpen = true;
        root.beginDraft(mode === "new" ? null : root.current);
    }
    function closeEditor() {
        if (!root.editorOpen) return;
        root.endDraft();
        root.editorOpen = false;
    }
    Connections {
        target: ShellState
        function onAnyOpenChanged() { if (ShellState.anyOpen) root.closeEditor(); }
    }
    Connections {
        target: ProjectsService
        function onDialogOpenChanged() { if (ProjectsService.dialogOpen) root.closeEditor(); }
    }
    // A shell reload or quit must not eat the last 700 ms of typing, nor what is queued: NotesEditor calls flushNow() as it is destroyed (a singleton's
    // own onDestruction does not fire), and `overworld` stops the shell with a signal, which destroys nothing, so it calls IPC flush first.

    // ---------------------------------------------------------------- where the card is (the editor opens over it)
    property var cardRects: ({})
    function setCardRect(screenName, rect) {
        const n = Object.assign({}, root.cardRects);
        n[screenName] = rect;
        root.cardRects = n;
    }

    // ---------------------------------------------------------------- relative time
    property double nowTick: Date.now()
    Timer { interval: 30000; repeat: true; running: root.count > 0; onTriggered: root.nowTick = Date.now() }
    function relTime(iso, nowMs) {
        const t = Date.parse(iso || "");
        if (isNaN(t)) return "";
        const min = Math.floor(((nowMs === undefined ? Date.now() : nowMs) - t) / 60000);
        if (min < 1) return "just now";
        if (min < 60) return min + " min ago";
        if (min < 1440) return Math.floor(min / 60) + " h ago";
        if (min < 2880) return "yesterday";
        return Math.floor(min / 1440) + " days ago";
    }

    // ---------------------------------------------------------------- IPC
    function lineOf(s, k) { return (k + 1) + (s.id === root.currentId ? "* " : "  ") + root.firstLine(s.text); }
    IpcHandler {
        target: "notes"
        function open(): void { root.openEditor("current") }
        function newSheet(): void { root.openEditor("new") }      // `new` is a reserved word: QML will not take it as a function name
        function add(text: string): string { return root.add(text) ? "pinned" : "nothing to pin" }
        function next(): string { return root.next() ? (root.currentIndex + 1) + "/" + root.count : "last sheet" }
        function prev(): string { return root.prev() ? (root.currentIndex + 1) + "/" + root.count : "first sheet" }
        function remove(): string { return root.removeCurrent() ? "torn off" : "no sheet" }
        function undo(): string { return root.undoRemove() ? "restored" : "nothing to undo" }
        function list(): string { return root.count ? root.sheets.map(root.lineOf).join("\n") : "no notes yet" }
        function flush(): void { root.flushNow() }
        function status(): string { return root.count ? root.count + (root.count === 1 ? " sheet" : " sheets") + ", on " + (root.currentIndex + 1) + "/" + root.count : "no notes yet" }
    }
}
