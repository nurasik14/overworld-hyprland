pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

/*  WorkspaceNotes — your own title + note per workspace 1–10, read from ~/.config/overworld/workspaces.json
 *  (watched live: edit the file or run `overworld ws …` and the next card shows the change).
 *
 *    { "1": { "title": "Browser", "note": "Research, mail, CityU portal" },
 *      "3": "Coding" }                      ← a bare string is a title with no note
 *
 *  WorkspaceNotes.title(id) / note(id) / has(id)        ("" when unset) · isAuto(id) = written by Claude
 *  Also runs scripts/ws-autolabel.py (Claude auto-labelling) while config.json → workspace_auto.enabled is true
 *  (`overworld ws auto on|off`); restarted 15 s after it exits, killed with the shell.
 *  Card settings live in config.json → "workspace_card": { enabled, duration, position, show_untitled }
 */
Singleton {
    id: root
    readonly property string path: Quickshell.env("HOME") + "/.config/overworld/workspaces.json"
    property var notes: ({})
    property int revision: 0

    function entry(id) {
        const e = root.notes[String(id)];
        if (e === undefined || e === null) return { title: "", note: "" };
        if (typeof e === "string") return { title: e, note: "" };
        return { title: String(e.title || ""), note: String(e.note || "") };
    }
    function title(id) { return root.revision >= 0 ? entry(id).title : ""; }
    function note(id) { return root.revision >= 0 ? entry(id).note : ""; }
    function has(id) { return title(id).length > 0 || note(id).length > 0; }
    function isAuto(id) {
        const e = root.revision >= 0 ? root.notes[String(id)] : null;
        return !!(e && typeof e === "object" && e.auto === true);
    }

    // ------------------------------------------------------------ Claude auto-labelling watcher
    readonly property bool autoWanted: ConfigService.get("workspace_auto.enabled", false) === true
    onAutoWantedChanged: autoProc.running = autoWanted
    Process {
        id: autoProc
        command: ["/usr/bin/python3", Theme.repoDir + "/scripts/ws-autolabel.py"]
        onExited: (code, status) => {
            if (root.autoWanted) { console.warn("WorkspaceNotes: ws-autolabel exited", code, "— restarting in 15 s"); autoRestart.restart(); }
        }
    }
    Timer { id: autoRestart; interval: 15000; onTriggered: if (root.autoWanted) autoProc.running = true }

    function parse(t) {
        try {
            const obj = JSON.parse(t || "{}");
            root.notes = (obj && typeof obj === "object") ? obj : {};
        } catch (e) {
            console.warn("WorkspaceNotes: workspaces.json parse error:", e);   // keep the last good copy
        }
        root.revision++;
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: { poll.running = false; root.parse(text()); }
        onFileChanged: reload()
        onLoadFailed: error => { root.notes = {}; root.revision++; poll.running = true }
    }
    Timer {   // file missing: look again every 5 s so the first `overworld ws` is picked up
        id: poll
        interval: 5000; repeat: true; running: false
        onTriggered: file.reload()
    }
    Component.onCompleted: { parse(file.text()); autoProc.running = autoWanted; }
}
