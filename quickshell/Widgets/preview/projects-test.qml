//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  ProjectsService logic test, no display, nothing real is touched (temp file + private event bus):
 *      T=/tmp/ow-proj; rm -rf $T; mkdir -p $T/home/.config/overworld $T/ev
 *      HOME=$T/home OW_PROJECTS=$T/projects.json OW_EVENTS_DIR=$T/ev OW_STATE_DIR=$T/home/.config/overworld OW_SOUND_DRYRUN=1 \
 *          QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/projects-test.qml
 *  Prints PASS / FAIL lines, then "projects-test done: N failed" and quits.
 */
ShellRoot {
    id: root
    readonly property string file: Quickshell.env("OW_PROJECTS")
    readonly property string script: ProjectsService.script
    property int fails: 0
    property var events: []
    function check(name, ok, extra) { console.warn((ok ? "PASS " : "FAIL ") + name + (extra !== undefined ? "  [" + extra + "]" : "")); if (!ok) root.fails++ }
    function titles(list) { return list.map(i => i.title).join(" | ") }
    function evCount(name, title) { return root.events.filter(e => e.name === name && (title === undefined || e.data.title === title)).length }
    function sh(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
    function cli(args) { return "bash '" + root.script + "' '" + root.file + "' " + args }

    Connections {
        target: GameEvents
        function onEvent(name, data) { if (name.indexOf("project.") === 0) root.events = root.events.concat([{ name: name, data: data }]); }
    }

    property int step: 0
    readonly property var steps: [
        { wait: 700, run: () => {}, test: () => {
            check("missing file → empty list, loaded", ProjectsService.loaded && ProjectsService.items.length === 0);
            check("missing file was not created", !fileExists.exists);
            check("no events on the first load", root.events.length === 0);
        } },
        { wait: 1000, run: () => {
            ProjectsService.add("Alpha  project", "", false);
            ProjectsService.add("Beta", "second one", false);
            ProjectsService.add("Gamma", "", true);
            ProjectsService.add("   ", "", false);
        }, test: () => {
            check("3 added (blank title refused), whitespace collapsed", ProjectsService.items.length === 3 && ProjectsService.items[0].title === "Alpha project", root.titles(ProjectsService.items));
            check("inProgress / built split", ProjectsService.inProgress.length === 2 && ProjectsService.built.length === 1);
            check("note stored", ProjectsService.items[1].note === "second one");
            check("already-built item has built_at", !!ProjectsService.items[2].built_at && !!ProjectsService.items[2].created);
            check("created file exists", fileExists.exists);
            check("project.add ×3", root.evCount("project.add") === 3, root.evCount("project.add"));
            check("project.built ×1 (Gamma added as built)", root.evCount("project.built") === 1 && root.evCount("project.built", "Gamma") === 1);
            check("ordered = in progress then built", root.titles(ProjectsService.ordered) === "Alpha project | Beta | Gamma", root.titles(ProjectsService.ordered));
        } },
        { wait: 900, run: () => { ProjectsService.toggle(ProjectsService.find("beta").item.id); }, test: () => {
            check("toggle → built", ProjectsService.byId(ProjectsService.find("beta").item.id).status === "built");
            check("project.built Beta announced once", root.evCount("project.built", "Beta") === 1);
            check("newest built first", root.titles(ProjectsService.ordered) === "Alpha project | Beta | Gamma", root.titles(ProjectsService.ordered));
        } },
        { wait: 900, run: () => { ProjectsService.toggle(ProjectsService.find("2").item.id); }, test: () => {
            check("toggle again → back in progress (no second built event)", ProjectsService.find("beta").item.status === "progress" && root.evCount("project.built", "Beta") === 1);
            check("built_at removed", ProjectsService.find("beta").item.built_at === undefined);
        } },
        { wait: 900, run: () => { ProjectsService.rename(ProjectsService.find("alpha").item.id, "Alpha 2", "with note"); }, test: () => {
            const a = ProjectsService.find("alpha 2").item;
            check("rename + note", !!a && a.note === "with note", a && a.title);
            check("rename keeps id / status / created", !!a && a.status === "progress" && !!a.created);
        } },
        { wait: 900, run: () => { ProjectsService.move(ProjectsService.find("beta").item.id, -1); }, test: () => {
            check("move up swaps within the section", root.titles(ProjectsService.items) === "Beta | Alpha 2 | Gamma", root.titles(ProjectsService.items));
        } },
        { wait: 900, run: () => { ProjectsService.move(ProjectsService.find("beta").item.id, -1); ProjectsService.move(ProjectsService.find("gamma").item.id, 1); }, test: () => {
            check("move past the ends is a no-op, never across sections", root.titles(ProjectsService.items) === "Beta | Alpha 2 | Gamma", root.titles(ProjectsService.items));
        } },
        { wait: 900, run: () => { ProjectsService.remove(ProjectsService.find("alpha 2").item.id); }, test: () => {
            check("remove", root.titles(ProjectsService.items) === "Beta | Gamma", root.titles(ProjectsService.items));
            check("project.remove announced", root.evCount("project.remove", "Alpha 2") === 1);
            check("undo available (5 s)", !!ProjectsService.undo && ProjectsService.undo.title === "Alpha 2");
        } },
        { wait: 1000, run: () => { ProjectsService.undoRemove(); }, test: () => {
            check("undo puts it back at its place", root.titles(ProjectsService.items) === "Beta | Alpha 2 | Gamma", root.titles(ProjectsService.items));
            check("undo is consumed", ProjectsService.undo === null);
        } },
        { wait: 1200, run: () => { root.sh("jq '.items += [{id:\"ext1\",title:\"Edited by hand\",status:\"progress\",created:\"2026-01-01T00:00:00Z\"}]' '" + root.file + "' > " + root.file + ".x && cat " + root.file + ".x > '" + root.file + "'"); }, test: () => {
            check("external edit picked up by the watcher", !!ProjectsService.byId("ext1"), root.titles(ProjectsService.items));
            check("…and announced as project.add", root.evCount("project.add", "Edited by hand") === 1);
        } },
        { wait: 2500, run: () => {
            // six writers at once: four CLI processes and two from the service
            for (let i = 1; i <= 4; i++) root.sh(root.cli("add 'cli " + i + "' '' progress"));
            ProjectsService.add("svc 1", "", false);
            ProjectsService.add("svc 2", "", false);
        }, test: () => {
            const t = ProjectsService.items.map(i => i.title);
            check("concurrent CLI + service writes: nothing lost", ["cli 1", "cli 2", "cli 3", "cli 4", "svc 1", "svc 2"].every(x => t.indexOf(x) >= 0) && t.length === 10, t.length + ": " + t.join(","));
            const ids = ProjectsService.items.map(i => i.id);
            check("ids unique", new Set(ids).size === ids.length);
        } },
        { wait: 900, run: () => { root.sh("printf '{\"items\": [ {bad' > '" + root.file + "'"); }, test: () => {
            check("a half-written / invalid file keeps the list on screen", ProjectsService.items.length === 10, ProjectsService.items.length);
        } },
        { wait: 1500, run: () => { root.sh("printf '{\"items\":[{\"id\":\"a\",\"title\":\"Fixed A\",\"status\":\"progress\"},{\"id\":\"b\",\"title\":\"Fixed B\",\"status\":\"built\",\"built_at\":\"2026-02-02T00:00:00Z\"},{\"id\":\"c\",\"title\":\"Fixed C\",\"status\":\"built\",\"built_at\":\"2026-03-03T00:00:00Z\"}]}' > '" + root.file + "'"); }, test: () => {
            check("valid again → reloaded", root.titles(ProjectsService.items) === "Fixed A | Fixed B | Fixed C", root.titles(ProjectsService.items));
            check("built newest first", root.titles(ProjectsService.built) === "Fixed C | Fixed B", root.titles(ProjectsService.built));
            check("find by number", ProjectsService.find("3").item.title === "Fixed B");
            check("find by prefix", ProjectsService.find("fixed a").item.id === "a");
            check("find ambiguous", !!ProjectsService.find("fixed").error, ProjectsService.find("fixed").error);
            check("find none", !!ProjectsService.find("zzz").error);
            check("numberOf", ProjectsService.numberOf(ProjectsService.byId("c")) === 2);
        } },
        { wait: 900, run: () => { ProjectsService.clearBuilt(); }, test: () => {
            check("clearBuilt removes only the built ones", root.titles(ProjectsService.items) === "Fixed A", root.titles(ProjectsService.items));
            check("clearBuilt undo holds both", !!ProjectsService.undo && ProjectsService.undo.count === 2);
        } },
        { wait: 1100, run: () => { ProjectsService.undoRemove(); }, test: () => {
            check("undo of clearBuilt restores them", root.titles(ProjectsService.items) === "Fixed A | Fixed B | Fixed C", root.titles(ProjectsService.items));
        } },
        { wait: 600, run: () => {
            check("IPC-style act(): done on a built one", ProjectsService.act("fixed b", "done") === "already built: Fixed B");
            check("IPC-style act(): ambiguous", ProjectsService.act("fixed", "done").indexOf("matches 3") > 0, ProjectsService.act("fixed", "done"));
            check("lineOf", ProjectsService.lineOf(ProjectsService.byId("a")) === "1. [ ] Fixed A", ProjectsService.lineOf(ProjectsService.byId("a")));
            vcheck.running = true;
        }, test: () => {} },
        { wait: 700, run: () => {}, test: () => {
            check("file on disk is valid JSON with unique ids (jq)", vcheck.out.trim() === "ok", vcheck.out.trim());
            console.warn("projects-test done: " + root.fails + " failed");
            Qt.quit();
        } }
    ]
    Process {
        id: vcheck
        command: ["jq", "-er", "(.items | map(.id) | length) == (.items | map(.id) | unique | length) and (.items | all(.title | length > 0)) | if . then \"ok\" else \"bad\" end", root.file]
        property string out: ""
        stdout: StdioCollector { onStreamFinished: vcheck.out = text }
    }
    FileView { id: fileExists; path: root.file; printErrors: false; blockLoading: true; property bool exists: false; onLoaded: exists = true; onLoadFailed: exists = false }

    Timer {
        id: tick
        interval: 100; running: true; repeat: false
        onTriggered: root.go()
    }
    function go() {
        if (root.step >= root.steps.length) return;
        const s = root.steps[root.step];
        s.run();
        waitTimer.interval = s.wait;
        waitTimer.restart();
        preTimer.interval = Math.max(10, s.wait - 150);
        preTimer.restart();
    }
    Timer { id: preTimer; onTriggered: fileExists.reload() }
    Timer {
        id: waitTimer
        onTriggered: {
            const s = root.steps[root.step];
            s.test();
            root.step++;
            root.go();
        }
    }
    Component.onCompleted: console.warn("projects-test: file=" + root.file + " script=" + root.script)
}
