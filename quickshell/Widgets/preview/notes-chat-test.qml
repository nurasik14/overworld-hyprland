//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Game
import qs.Widgets.Services

/*  /note chat command test (ChatService → NotesService), temp state only:
 *      T=/tmp/ow-notechat; rm -rf $T; mkdir -p $T/state $T/ev
 *      OW_STATE_DIR=$T/state HYPR_NOTES_FILE=$T/notes.json OW_EVENTS_DIR=$T/ev OW_GAME_DRYRUN=1 OW_BRIDGE=0 OW_SOUND_DRYRUN=1 \
 *          QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/notes-chat-test.qml
 */
ShellRoot {
    id: root
    property int fails: 0
    property int step: 0
    function check(name, ok, extra) { console.warn((ok ? "PASS " : "FAIL ") + name + (extra !== undefined ? "  [" + extra + "]" : "")); if (!ok) root.fails++ }
    function has(sub) { return ChatService.lines.some(l => l.text.replace(/§./g, "").indexOf(sub) >= 0) }
    function count(sub) { return ChatService.lines.filter(l => l.text.replace(/§./g, "").indexOf(sub) >= 0).length }
    function texts() { return NotesService.sheets.map(s => s.text).join(" | ") }
    function say(t) { ChatService.submit(t) }

    readonly property var steps: [
        { run: () => { say("/note list") }, test: () => { check("empty list hint", has("No notes yet"), ChatService.lines.slice(-2).map(l => l.text).join(" / ")); } },
        { run: () => { say("/note buy more coffee") }, test: () => {
            check("/note <text> pins a sheet", texts() === "buy more coffee", texts());
            check("says Note pinned.", has("Note pinned."));
            check("no editor opened", !NotesService.editorOpen);
        } },
        { run: () => { say("/note   spaces  inside  stay"); say("/note list of things to check") }, test: () => {
            check("text is taken as typed, inner spaces kept", NotesService.sheets[1].text === "spaces  inside  stay", NotesService.sheets[1] && NotesService.sheets[1].text);
            check("text that merely starts with list is a note", NotesService.sheets[2].text === "list of things to check");
            check("pinned line each time", count("Note pinned.") === 3, count("Note pinned."));
        } },
        { run: () => { say("/note list") }, test: () => {
            check("list header", has("Notes: 3"));
            check("rows numbered, current marked", has("1. buy more coffee") && has("3* list of things to check"), ChatService.lines.slice(-4).map(l => l.text).join(" / "));
        } },
        { run: () => { say("/note LIST") }, test: () => { check("LIST works too, no sheet pinned", NotesService.count === 3); } },
        { run: () => { say("/note") }, test: () => {
            check("bare /note opens the editor on the current sheet", NotesService.editorOpen && NotesService.draftText === "list of things to check", NotesService.draftText);
            NotesService.closeEditor();
        } },
        { run: () => {
            check("help knows it", ChatService.commandNames.indexOf("note") >= 0);
            check("completion: /no → /note", ChatService.completions("/no").items.indexOf("note") >= 0);
            check("completion: /note l → list", ChatService.completions("/note l").items.indexOf("list") >= 0);
            say("/help note");
        }, test: () => {
            check("/help note shows the usage", has("/note [<text>|list]"), ChatService.lines.slice(-2).map(l => l.text).join(" / "));
        } },
        { run: () => {}, test: () => {
            console.warn("notes-chat-test done: " + root.fails + " failed");
            Qt.quit();
        } }
    ]
    Timer { id: t; interval: 250; running: true; repeat: true; onTriggered: if (GameCore.t("ok.note_none").length > 0) { t.stop(); root.go() } }   // chat.json loads a moment after start
    function go() {
        if (root.step >= root.steps.length) return;
        root.steps[root.step].run();
        testTimer.restart();
    }
    Timer {
        id: testTimer; interval: 900
        onTriggered: { root.steps[root.step].test(); root.step++; root.go(); }
    }
}
