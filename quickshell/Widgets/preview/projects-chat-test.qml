//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Game
import qs.Widgets.Services

/*  /project chat command test (ChatService → ProjectsService), temp state only:
 *      T=/tmp/ow-projchat; rm -rf $T; mkdir -p $T/state $T/ev
 *      OW_STATE_DIR=$T/state OW_PROJECTS=$T/projects.json OW_EVENTS_DIR=$T/ev OW_GAME_DRYRUN=1 OW_BRIDGE=0 OW_SOUND_DRYRUN=1 \
 *          QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/projects-chat-test.qml
 */
ShellRoot {
    id: root
    property int fails: 0
    property int step: 0
    function check(name, ok, extra) { console.warn((ok ? "PASS " : "FAIL ") + name + (extra !== undefined ? "  [" + extra + "]" : "")); if (!ok) root.fails++ }
    function has(sub) { return ChatService.lines.some(l => l.text.replace(/§./g, "").indexOf(sub) >= 0) }
    function titles() { return ProjectsService.items.map(i => i.title).join(" | ") }
    function say(t) { ChatService.submit(t) }

    readonly property var steps: [
        { run: () => { say("/project list") }, test: () => { check("empty list hint", has("No projects yet"), ChatService.lines.slice(-3).map(l => l.text).join(" / ")); } },
        { run: () => { say("/project add Alpha one"); say("/project add Beta  two"); say("/project add") }, test: () => {
            check("/project add → both in the file", titles() === "Alpha one | Beta two", titles());
            check("confirmation line", has("Added project [Alpha one]"));
            check("bare add → usage error", ChatService.lines.some(l => l.color === "#ff5555"));
        } },
        { run: () => { say("/project done alpha") }, test: () => {
            check("/project done <prefix> builds it", ProjectsService.byId(ProjectsService.find("alpha").item.id).status === "built");
            check("chat line: Nurasik built [Alpha one]!", has("Nurasik built [Alpha one]!"), ChatService.lines.slice(-3).map(l => l.text).join(" / "));
        } },
        { run: () => { say("/project done 1") }, test: () => {
            check("number 1 is Beta two (in progress first)", ProjectsService.find("beta").item.status === "built");
            check("…and says so", has("Nurasik built [Beta two]!"));
        } },
        { run: () => { say("/project done alpha") }, test: () => { check("already built → info, no second built line", ChatService.lines.filter(l => l.text.replace(/§./g, "").indexOf("built [Alpha one]") >= 0).length === 1 && has("already built")); } },
        { run: () => { say("/project undone alpha") }, test: () => { check("undone", ProjectsService.find("alpha").item.status === "progress" && has("[Alpha one] is back in progress")); } },
        { run: () => { say("/project done zzz"); say("/project done") }, test: () => { check("no match → error line", has("no project matches 'zzz'")); check("no argument → error", has("no project given")); } },
        { run: () => { say("/project list") }, test: () => {
            check("list header", has("Projects: 1 in progress, 1 built"));
            check("list rows numbered", has("1. [ ] Alpha one") && has("2. [x] Beta two"));
        } },
        { run: () => { say("/project remove 2") }, test: () => {
            check("remove by number", titles() === "Alpha one", titles());
            check("remove line mentions undo", has("Removed project [Beta two]") && has("/project undo"));
        } },
        { run: () => { say("/project undo") }, test: () => { check("/project undo restores", titles() === "Alpha one | Beta two", titles()); } },
        { run: () => { say("/project undo") }, test: () => { check("second undo: nothing to undo", has("Nothing to undo")); } },
        { run: () => {}, test: () => {
            const c1 = ChatService.completions("/project ");
            check("completes the actions", c1.items.indexOf("add") >= 0 && c1.items.indexOf("done") >= 0 && c1.items.indexOf("undo") >= 0, c1.items.join(","));
            const c2 = ChatService.completions("/project done al");
            check("completes in-progress titles", c2.items.length === 1 && c2.items[0] === "Alpha one" && c2.prefix === "al", JSON.stringify(c2));
            check("done does not offer built titles", ChatService.completions("/project done be").items.length === 0 && ChatService.completions("/project undone be").items.length === 1 && ChatService.completions("/project undone al").items.length === 0);
            check("tab completes a whole title", ChatService.tab("/project done al", false) === "/project done Alpha one ", ChatService.tab("/project done al", false));
            check("/project is in /help", ChatService.commandNames.indexOf("project") >= 0);
        } },
        { run: () => { say("/project") }, test: () => { check("bare /project opens the add dialog", ProjectsService.dialogOpen && ProjectsService.editId === ""); ProjectsService.closeDialog(); } },
        { run: () => { say("/project edit alpha") }, test: () => { check("/project edit opens the dialog on it", ProjectsService.dialogOpen && ProjectsService.editId === ProjectsService.find("alpha").item.id); ProjectsService.closeDialog(); } },
        { run: () => { say("/project bogus") }, test: () => { check("unknown verb → usage", ChatService.lines.slice(-2).some(l => l.text.indexOf("/project") >= 0)); console.warn("projects-chat-test done: " + root.fails + " failed"); Qt.quit(); } }
    ]
    Timer { id: t; interval: 250; running: true; repeat: true; onTriggered: if (GameCore.t("ok.project_none").length > 0) { t.stop(); root.go() } }   // chat.json loads a moment after start
    function go() { steps[step].run(); settle.restart() }
    Timer { id: settle; interval: 1000; onTriggered: { root.steps[root.step].test(); root.step++; if (root.step < root.steps.length) root.go() } }
}
