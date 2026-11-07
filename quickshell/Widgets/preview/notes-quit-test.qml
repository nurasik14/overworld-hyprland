//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets.Services

/*  What a quit does to unsaved typing (driven by the shell script tests/notes-quit.test.sh, temp file only).
 *    OW_NOTES_QUIT=clean   type, then Qt.quit() before the autosave fires
 *    OW_NOTES_QUIT=reload  type, then Quickshell.reload(): what a save in the config dir and /reload do (the new generation stays up)
 *    OW_NOTES_QUIT=wait    type, then wait: the script calls IPC flush and sends SIGTERM (what `overworld reload|off|repair` do)
 */
ShellRoot {
    readonly property string how: Quickshell.env("OW_NOTES_QUIT")
    QtObject { Component.onDestruction: NotesService.flushNow() }     // what NotesEditor does (it needs a real PanelWindow backend, this runs offscreen)
    // after a reload the new generation starts over: this file says the typing has been done
    FileView { id: flag; path: Quickshell.env("HYPR_NOTES_FILE") + ".flag"; printErrors: false; blockLoading: true; property bool exists: false; onLoaded: exists = true }
    Timer {
        interval: 600; running: !flag.exists
        onTriggered: {
            NotesService.openEditor("new");
            NotesService.typed("typed " + how);
            NotesService.add("queued too");
            console.warn("typed");
            if (how === "reload") { flag.setText("done"); }
            if (how === "clean") Qt.quit();
            if (how === "reload") Quickshell.reload(false);
        }
    }
}
