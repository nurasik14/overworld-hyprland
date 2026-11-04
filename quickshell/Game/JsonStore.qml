import QtQuick
import Quickshell
import Quickshell.Io

/*  JsonStore — one JSON state file: loaded synchronously at creation, saved debounced (atomic temp + rename by FileView).
 *    path: string        absolute file path (the directory must exist)
 *    data: var           the parsed object; mutate a copy and assign (or call changed()) so bindings re-evaluate
 *    watch: bool         reload when another process rewrites the file (gamemode flag, config.json)
 *    save()              schedule a write after saveDelay ms;  saveNow() writes immediately
 *    signal loadedFile() after every (re)load
 *  A missing or malformed file leaves data = {} (it is never overwritten until something calls save()).
 */
Scope {
    id: root
    property string path: ""
    property var data: ({})
    property bool watch: false
    property bool loaded: false
    property int saveDelay: 600
    signal loadedFile()

    function parse(t) {
        try { const o = JSON.parse(t || "{}"); root.data = (o && typeof o === "object" && !Array.isArray(o)) ? o : ({}); }
        catch (e) { console.warn("JsonStore:", root.path, "parse error:", e); root.data = ({}); }
        root.loaded = true;
        root.loadedFile();
    }
    function parseAny(t, fallback) {   // arrays too (chat history)
        try { const o = JSON.parse(t || "null"); root.data = (o === null || o === undefined) ? fallback : o; }
        catch (e) { root.data = fallback; }
        root.loaded = true;
        root.loadedFile();
    }
    property bool array: false
    function save() { saveTimer.restart(); }
    function saveNow() {
        saveTimer.stop();
        if (!root.path) return;
        file.setText(JSON.stringify(root.data, null, 1) + "\n");
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: root.watch
        printErrors: false
        onLoaded: root.array ? root.parseAny(text(), []) : root.parse(text())
        onLoadFailed: error => { root.data = root.array ? [] : ({}); root.loaded = true; root.loadedFile(); }
        onFileChanged: reload()
    }
    Timer { id: saveTimer; interval: root.saveDelay; onTriggered: root.saveNow() }
    Component.onDestruction: if (saveTimer.running) root.saveNow()
}
