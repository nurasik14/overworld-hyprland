//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  NotesService logic test, no display, nothing real is touched (temp file):
 *      T=/tmp/ow-notes; rm -rf $T; mkdir -p $T/home/.config/overworld $T/ev; echo '{"sounds":false}' > $T/home/.config/overworld/config.json
 *      HOME=$T/home HYPR_NOTES_FILE=$T/notes.json OW_EVENTS_DIR=$T/ev OW_STATE_DIR=$T/home/.config/overworld OW_SOUND_DRYRUN=1 \
 *          QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/notes-test.qml
 *  Prints PASS / FAIL lines, then "notes-test done: N failed" and quits.
 */
ShellRoot {
    id: root
    readonly property string file: Quickshell.env("HYPR_NOTES_FILE")
    readonly property var svc: NotesService
    property int fails: 0
    property int writes: 0
    property var loaded: []
    function check(name, ok, extra) { console.warn((ok ? "PASS " : "FAIL ") + name + (extra !== undefined ? "  [" + extra + "]" : "")); if (!ok) root.fails++ }
    function texts() { return svc.sheets.map(s => s.text).join(" | ") }
    function sh(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
    function cli(args) { return "bash '" + svc.script + "' '" + root.file + "' " + args }
    Connections { target: NotesService; function onDraftLoaded(text) { root.loaded = root.loaded.concat([text]); } }
    property int torn: 0
    Connections { target: NotesService; function onSheetTorn() { root.torn++; } }

    property int step: 0
    readonly property var steps: [
        { wait: 700, run: () => {}, test: () => {
            check("missing file → empty, loaded", svc.loaded && svc.count === 0 && svc.current === null);
            check("missing file was not created", !fileExists.exists);
        } },
        { wait: 900, run: () => { svc.add("first  thought"); svc.add("second\nwith two lines"); svc.add("   \n "); svc.add("third"); }, test: () => {
            check("3 added, blank refused, text kept as typed", svc.count === 3 && svc.sheets[0].text === "first  thought", texts());
            check("multi-line stored", svc.sheets[1].text === "second\nwith two lines");
            check("the newest is current", svc.current.text === "third" && svc.currentIndex === 2, svc.currentIndex);
            check("file created", textOf.read().indexOf("sheets") >= 0);
            check("firstLine", svc.firstLine("\n \n  hello \nworld") === "hello");
            check("status", ipcStatus() === "3 sheets, on 3/3", ipcStatus());
        } },
        // ---- flipping
        { wait: 150, run: () => {
            check("prev flips at once", svc.prev() && svc.current.text.indexOf("second") === 0, svc.currentIndex);
            check("prev again", svc.prev() && svc.currentIndex === 0);
            check("no wrap at the first sheet", !svc.prev() && svc.currentIndex === 0);
        }, test: () => {
            check("the flip is not written yet (debounced)", curInFile.read() !== svc.currentId, curInFile.read());
        } },
        { wait: 800, run: () => {}, test: () => {
            check("…then written once", curInFile.read() === svc.currentId && svc.currentIndex === 0, curInFile.read());
            check("flip pending cleared", !svc.flipPending);
        } },
        { wait: 700, run: () => { svc.next(); svc.next(); check("no wrap at the last", !svc.next() && svc.currentIndex === 2); svc.prev(); }, test: () => {
            check("spinning settles on the last flip", curInFile.read() === svc.currentId && svc.currentIndex === 1, svc.currentIndex);
        } },
        // ---- external edit, an add from the CLI moves the card
        { wait: 700, run: () => { sh(cli("add 'from the cli'")); }, test: () => {
            check("CLI add shows up live and becomes current", svc.count === 4 && svc.current.text === "from the cli", texts());
        } },
        { wait: 700, run: () => { sh("jq '.sheets[0].text = \"edited by hand\"' '" + file + "' > " + file + ".x && cat " + file + ".x > '" + file + "'"); }, test: () => {
            check("external edit picked up by the watcher", svc.sheets[0].text === "edited by hand", texts());
        } },
        // ---- remove + undo
        { wait: 700, run: () => { svc.goTo(svc.sheets[1].id); svc.removeCurrent(); }, test: () => {
            check("tear off the current one", svc.count === 3 && svc.sheets.every(s => s.text.indexOf("second") !== 0), texts());
            check("the next sheet is current", svc.current.text === "third", svc.current && svc.current.text);
            check("undo offered with a preview", !!svc.undo && svc.undo.preview === "second" && svc.undo.count === 1, svc.undo && svc.undo.preview);
            check("sheetTorn fired once", root.torn === 1, root.torn);
        } },
        { wait: 700, run: () => { svc.undoRemove(); }, test: () => {
            check("undo puts it back at its place", svc.sheets[1].text.indexOf("second") === 0 && svc.count === 4, texts());
            check("…as current", svc.currentIndex === 1);
            check("undo consumed", svc.undo === null && !svc.undoRemove());
        } },
        { wait: 600, run: () => { svc.remove(svc.sheets[0].id); }, test: () => {} },
        { wait: 800, run: () => { svc.remove(svc.sheets[0].id); }, test: () => {
            check("two tear-offs pile into one undo", svc.count === 2 && svc.undo.count === 2, svc.undo && svc.undo.count);
        } },
        { wait: 900, run: () => { svc.undoRemove(); }, test: () => {
            check("undo restores both, in place", texts().indexOf("edited by hand | second") === 0 && svc.count === 4, texts());
        } },
        // ---- the editor: autosave debounce
        { wait: 300, run: () => { svc.openEditor("current"); root.loaded = []; svc.closeEditor(); root.writes = 0; svc.goTo(svc.sheets[0].id); svc.openEditor("current"); }, test: () => {
            check("editor opens on the current sheet", svc.editorOpen && svc.draftId === svc.sheets[0].id && svc.draftText === "edited by hand");
            check("draftLoaded told the form", root.loaded[root.loaded.length - 1] === "edited by hand");
            svc.typed("edited by hand!");
            check("typing marks the draft dirty", svc.draftDirty);
        } },
        { wait: 350, run: () => { svc.typed("edited by hand!!"); }, test: () => {
            check("nothing written before 700 ms of quiet", textInFile.read(0) === "edited by hand", textInFile.read(0));
            svc.typed("edited by hand!!!");                                 // restarts the debounce again
        } },
        { wait: 450, run: () => {}, test: () => {
            check("typing keeps pushing the save back", textInFile.read(0) === "edited by hand", textInFile.read(0));
        } },
        { wait: 700, run: () => {}, test: () => {
            check("written after the pause", textInFile.read(0) === "edited by hand!!!" && !svc.draftDirty, textInFile.read(0));
            check("the sheet on screen follows", svc.sheets[0].text === "edited by hand!!!");
            check("updated bumped", Date.parse(svc.sheets[0].updated) > Date.parse("2026-01-01"));
        } },
        { wait: 700, run: () => { svc.typed("quick save on close"); svc.closeEditor(); }, test: () => {
            check("close saves at once and closes", !svc.editorOpen && svc.sheets[0].text === "quick save on close", texts());
        } },
        // ---- empty sheets
        { wait: 700, run: () => { root.torn = 0; svc.openEditor("new"); }, test: () => {
            check("new draft is blank and not in the file yet", svc.draftText === "" && !svc.draftInFile && svc.count === 4);
            check("page counter counts the unwritten sheet", svc.draftPage === 5 && svc.draftPages === 5, svc.draftPage + "/" + svc.draftPages);
            svc.typed("  \n ");
        } },
        { wait: 1000, run: () => {}, test: () => {
            check("a blank draft is never autosaved", svc.count === 4, svc.count);
            svc.closeEditor();
        } },
        { wait: 700, run: () => {}, test: () => {
            check("an empty new sheet is dropped on close", svc.count === 4 && !svc.editorOpen, texts());
            check("…with no undo and no crumbs", svc.undo === null && root.torn === 0);
            svc.openEditor("new"); svc.typed("a new thought");
        } },
        { wait: 1100, run: () => {}, test: () => {
            check("first autosave creates the sheet", svc.count === 5 && svc.sheets[4].text === "a new thought", texts());
            check("…and it is current", svc.currentIndex === 4);
            check("…counter now counts it once", svc.draftPage === 5 && svc.draftPages === 5);
            svc.typed("");
        } },
        { wait: 1000, run: () => {}, test: () => {
            check("clearing a written sheet does not autosave a blank", svc.sheets[4].text === "a new thought");
            svc.closeEditor();
        } },
        { wait: 700, run: () => {}, test: () => {
            check("emptied sheet dropped on close", svc.count === 4, texts());
            check("…with an undo holding its last text", !!svc.undo && svc.undo.preview === "a new thought");
        } },
        { wait: 700, run: () => { svc.undoRemove(); }, test: () => {
            check("undo brings it back", svc.count === 5 && svc.sheets[4].text === "a new thought", texts());
        } },
        { wait: 700, run: () => { svc.goTo(svc.sheets[0].id); svc.openEditor("current"); svc.typed(""); svc.closeEditor(); }, test: () => {
            check("an existing sheet cleared and closed is dropped", svc.count === 4, texts());
            check("…undo has the text it had when opened", !!svc.undo && svc.undo.batches[0][0].item.text === "quick save on close", svc.undo && svc.undo.preview);
        } },
        { wait: 700, run: () => { svc.undoRemove(); }, test: () => {
            check("…and it returns at its place", svc.sheets[0].text === "quick save on close" && svc.count === 5, texts());
        } },
        // ---- Ctrl+N, Ctrl+PgUp/PgDn in the editor
        { wait: 700, run: () => { svc.goTo(svc.sheets[1].id); svc.openEditor("current"); svc.typed("second, typed then flipped"); check("flipDraft moves", svc.flipDraft(1) && svc.draftId === svc.sheets[2].id); }, test: () => {
            check("flipping saved the sheet it left", svc.sheets[1].text === "second, typed then flipped", texts());
            check("…and loaded the next", svc.draftText === svc.sheets[2].text);
            check("current follows", svc.currentIndex === 2);
        } },
        { wait: 600, run: () => { svc.typed("carry on"); svc.newDraft(); }, test: () => {
            check("Ctrl+N saves and gives a blank sheet", svc.sheets[2].text === "carry on" && svc.draftText === "" && !svc.draftInFile, texts());
            const id = svc.draftId; svc.newDraft();
            check("Ctrl+N on a blank sheet stays there", svc.draftId === id);
            check("flip forward off the end refused", !svc.flipDraft(1));
            check("flip back from a new sheet goes to the last", svc.flipDraft(-1) && svc.draftId === svc.sheets[svc.count - 1].id);
            check("the blank one vanished", svc.count === 5);
        } },
        { wait: 700, run: () => { svc.openEditor("new"); check("`new` while open = Ctrl+N", svc.editorOpen && svc.draftText === "" && !svc.draftInFile); svc.closeEditor(); }, test: () => {
            check("closed, still five", svc.count === 5 && !svc.editorOpen);
        } },
        // ---- a sheet changes under the editor
        { wait: 700, run: () => { svc.goTo(svc.sheets[3].id); svc.openEditor("current"); root.loaded = []; sh(cli("put '" + svc.draftId + "' 'changed from outside'")); }, test: () => {
            check("clean draft shows the external change", svc.draftText === "changed from outside" && root.loaded[0] === "changed from outside", svc.draftText);
            svc.typed("I am typing");
        } },
        { wait: 200, run: () => { sh(cli("put '" + svc.draftId + "' 'outside again'")); }, test: () => {} },
        { wait: 1200, run: () => {}, test: () => {
            check("a draft with typing wins over an outside write", svc.draftText === "I am typing" && svc.sheets[3].text === "I am typing", svc.sheets[3].text);
        } },
        { wait: 700, run: () => { sh(cli("remove '" + svc.draftId + "'")); }, test: () => {
            check("sheet torn off elsewhere: the editor moves on, does not bring it back", svc.count === 4 && svc.draftId !== "" && svc.sheets.every(s => s.text !== "I am typing"), texts());
            svc.closeEditor();
        } },
        // ---- removeCurrent while editing
        { wait: 700, run: () => { svc.goTo(svc.sheets[1].id); svc.openEditor("current"); svc.typed("edit then tear"); root.torn = 0; const next = svc.sheets[2].id; check("IPC remove in the editor", svc.removeCurrent()); check("…moves to the next sheet", svc.draftId === next); }, test: () => {
            check("…it is gone", svc.count === 3 && svc.sheets.every(s => s.text !== "edit then tear"), texts());
            check("…undo holds what was on it", !!svc.undo && svc.undo.preview === "edit then tear");
            check("…crumbs once", root.torn === 1);
            svc.closeEditor();
        } },
        { wait: 700, run: () => { svc.undoRemove(); }, test: () => {
            check("…and returns with the typed text", svc.sheets[1].text === "edit then tear" && svc.count === 4, texts());
        } },
        // ---- review findings: undo text, stale flip-back, pending flips, unsaved drafts, double clicks, refused writes
        { wait: 1000, run: () => { svc.goTo(svc.sheets[0].id); svc.openEditor("current"); root.origFirst = svc.draftText; svc.typed("three new paragraphs"); }, test: () => {
            check("autosaved over the original", svc.sheets[0].text === "three new paragraphs", svc.sheets[0].text);
            svc.typed("");
            svc.closeEditor();
        } },
        { wait: 700, run: () => {}, test: () => {
            check("undo of a blanked sheet holds its last saved text, not the text it was opened with", !!svc.undo && svc.undo.batches[0][0].item.text === "three new paragraphs", svc.undo && svc.undo.batches[0][0].item.text);
        } },
        { wait: 700, run: () => { svc.undoRemove(); }, test: () => {} },
        { wait: 700, run: () => {
            svc.goTo(svc.sheets[0].id); svc.openEditor("current");
            svc.typed("typed then flipped away and back at once");
            svc.flipDraft(1); svc.flipDraft(-1);
            check("flipping straight back shows the save, not the stale sheet", svc.draftText === "typed then flipped away and back at once", svc.draftText);
            svc.closeEditor();
        }, test: () => {
            check("…and the file has it", svc.sheets[0].text === "typed then flipped away and back at once", svc.sheets[0].text);
            root.neighbour = svc.sheets[2].id;
        } },
        { wait: 700, run: () => {           // flip to B, blank it, close, all inside the 400 ms flip debounce
            svc.goTo(svc.sheets[0].id);
        }, test: () => {
            svc.openEditor("current"); svc.flipDraft(1); svc.typed(""); svc.closeEditor();
        } },
        { wait: 700, run: () => {}, test: () => {
            check("blanking a just-flipped-to sheet: current moves to its neighbour", svc.current && svc.current.id === root.neighbour, svc.currentIndex + ": " + texts());
        } },
        { wait: 700, run: () => { svc.undoRemove(); }, test: () => {
            svc.goTo(svc.sheets[2].id); svc.removeCurrent(); root.tornId = svc.undo.batches[0][0].item.id;
        } },
        { wait: 300, run: () => { svc.flip(-1); svc.undoRemove(); }, test: () => {} },
        { wait: 900, run: () => {}, test: () => {
            check("tear off, flip, undo inside the debounce: the restored sheet is current", svc.current && svc.current.id === root.tornId, svc.current && svc.current.text);
        } },
        { wait: 600, run: () => {
            root.torn = 0;
            svc.openEditor("new"); svc.typed("typed, not saved yet");
            check("IPC remove on an unsaved new draft answers true", svc.removeCurrent());
            check("…offers an undo with the text", !!svc.undo && svc.undo.preview === "typed, not saved yet", svc.undo && svc.undo.preview);
            check("…crumbs", root.torn === 1);
            svc.closeEditor();
            root.bak = svc.count;
            svc.undoRemove();
        }, test: () => {
            check("…and undo makes it a real sheet", svc.count === root.bak + 1 && svc.current.text === "typed, not saved yet", texts());
        } },
        { wait: 700, run: () => {
            const id = svc.current.id; root.bak = svc.count;
            check("first click tears off", svc.remove(id));
            check("double click: the second does nothing", !svc.remove(id));
            check("…undo counts one", svc.undo.count === 1, svc.undo.count);
            svc.undoRemove();
        }, test: () => { check("…and it comes back", svc.count === root.bak); } },
        { wait: 200, run: () => {
            svc.openEditor("current");
            ProjectsService.openDialog("");
            check("the Projects dialog closes the editor", !svc.editorOpen);
            svc.openEditor("current");
            check("…and the editor closes the Projects dialog", !ProjectsService.dialogOpen && svc.editorOpen);
            svc.closeEditor();
            check("capped counts characters, not UTF-16 units", svc.capped("🦊".repeat(4000)).length === 8000 && [...svc.capped("🦊".repeat(4100))].length === 4000);
        }, test: () => {} },
        { wait: 1000, run: () => {           // a refused save: nothing typed is lost
            svc.goTo(svc.sheets[0].id); svc.openEditor("current");
            root.rescuePath = file + ".rescue";
            root.failsBefore = svc.saveFailures;
            sh("cp '" + file + "' '" + file + ".good2'; printf '{bad' > '" + file + "'");
        }, test: () => {
            svc.typed("typed while the file is broken");
        } },
        { wait: 1300, run: () => {}, test: () => {
            check("a refused autosave is counted", svc.saveFailures > root.failsBefore, svc.saveFailures);
            check("the draft stays dirty", svc.draftDirty);
            check("the editor keeps the text", svc.draftText === "typed while the file is broken");
            sh("grep -q 'typed while the file is broken' '" + root.rescuePath + "' && touch '" + file + ".rescued'; cat '" + file + ".good2' > '" + file + "'");
        } },
        { wait: 900, run: () => {}, test: () => {
            check("file fixed: the editor is not reverted to the file's text", svc.draftText === "typed while the file is broken", svc.draftText);
            svc.closeEditor();
        } },
        { wait: 800, run: () => {}, test: () => {
            check("close retries and saves it", svc.sheets[0].text === "typed while the file is broken", svc.sheets[0].text);
            flagFile.reload();
        } },
        { wait: 200, run: () => {}, test: () => { check("…and the refused text was in .rescue", flagFile.exists); } },
        { wait: 1000, run: () => {          // flush: draft + queue written detached, the queue emptied
            svc.openEditor("new"); svc.typed("flushed before a kill");
            svc.goTo(svc.sheets[0].id);
            svc.flushNow();
            check("flush leaves nothing queued here", svc.queue.length <= 1, svc.queue.length);
            check("…draft no longer dirty", !svc.draftDirty);
        }, test: () => {
            check("flush wrote the draft", svc.sheets.some(s => s.text === "flushed before a kill"), texts());
            svc.closeEditor();
        } },
        // ---- other screens close it, reopen from nothing
        { wait: 600, run: () => { svc.openEditor("current"); svc.typed("closed by a modal"); ShellState.open("brew"); }, test: () => {
            check("another modal closes the editor and saves", !svc.editorOpen && svc.current.text === "closed by a modal", svc.current && svc.current.text);
            ShellState.closeAll();
            check("relTime just now", svc.relTime("2026-11-06T10:00:30Z", Date.parse("2026-11-06T10:01:00Z")) === "just now");
            check("relTime minutes", svc.relTime("2026-11-06T10:00:00Z", Date.parse("2026-11-06T10:03:30Z")) === "3 min ago");
            check("relTime hours", svc.relTime("2026-11-06T10:00:00Z", Date.parse("2026-11-06T12:30:00Z")) === "2 h ago");
            check("relTime yesterday", svc.relTime("2026-11-05T10:00:00Z", Date.parse("2026-11-06T12:00:00Z")) === "yesterday");
            check("relTime days", svc.relTime("2026-11-01T10:00:00Z", Date.parse("2026-11-06T12:00:00Z")) === "5 days ago");
            check("relTime garbage", svc.relTime("nope") === "" && svc.relTime(undefined) === "");
        } },
        // ---- cap, invalid file, concurrency
        { wait: 800, run: () => { svc.openEditor("new"); svc.typed("x".repeat(5000)); check("typed() caps the draft", svc.draftText.length === 4000); svc.closeEditor(); }, test: () => {
            check("capped on disk", svc.sheets[svc.count - 1].text.length === 4000, svc.sheets[svc.count - 1].text.length);
        } },
        { wait: 700, run: () => { root.bak = svc.count; sh("cp '" + file + "' '" + file + ".good'; printf '{\"sheets\": [ {bad' > '" + file + "'"); }, test: () => {
            check("an invalid file keeps the sheets on screen", svc.count === root.bak, svc.count);
            svc.add("refused write");
        } },
        { wait: 700, run: () => {}, test: () => {
            check("…and a write does not overwrite it", textOf.read() === '{"sheets": [ {bad', textOf.read());
        } },
        { wait: 900, run: () => { sh("cat '" + file + ".good' > '" + file + "'"); }, test: () => {
            check("valid again → reloaded", svc.count === root.bak, svc.count);
        } },
        { wait: 2500, run: () => {
            for (let i = 1; i <= 4; i++) sh(cli("add 'cli " + i + "'"));
            svc.add("svc 1"); svc.add("svc 2");
        }, test: () => {
            const t = svc.sheets.map(s => s.text);
            check("concurrent CLI + service writes: nothing lost", ["cli 1", "cli 2", "cli 3", "cli 4", "svc 1", "svc 2"].every(x => t.indexOf(x) >= 0) && svc.count === root.bak + 6, svc.count);
            check("ids unique", new Set(svc.sheets.map(s => s.id)).size === svc.count);
            check("list() numbers from 1 and marks current", svc.lineOf(svc.sheets[0], 0).indexOf("1") === 0);
        } },
        // ---- the pad emptied from the CLI
        { wait: 900, run: () => { sh(cli("clear")); }, test: () => {
            check("cleared from the CLI", svc.count === 0 && svc.current === null && svc.currentId === "");
            check("status when empty", ipcStatus() === "no notes yet");
            svc.openEditor("current");
            check("opening on an empty pad gives a blank sheet", svc.editorOpen && svc.draftText === "" && !svc.draftInFile);
            svc.closeEditor();
            console.warn("notes-test done: " + root.fails + " failed");
            Qt.quit();
        } }
    ]
    property int bak: 0
    property string neighbour: ""
    property string tornId: ""
    property string origFirst: ""
    property string rescuePath: ""
    property int failsBefore: 0
    FileView { id: flagFile; path: root.file + ".rescued"; printErrors: false; blockLoading: true; property bool exists: false; onLoaded: exists = true }
    function ipcStatus() { return svc.count ? svc.count + (svc.count === 1 ? " sheet" : " sheets") + ", on " + (svc.currentIndex + 1) + "/" + svc.count : "no notes yet" }

    // read the file directly, not through the service under test
    QtObject { id: curInFile; function read() { try { return JSON.parse(fileExists.text()).current || ""; } catch (e) { return "?"; } } }
    QtObject { id: textInFile; function read(k) { try { return JSON.parse(fileExists.text()).sheets[k].text; } catch (e) { return "?"; } } }
    QtObject { id: textOf; function read() { return fileExists.text(); } }
    FileView { id: fileExists; path: root.file; printErrors: false; blockLoading: true; property bool exists: false; onLoaded: exists = true; onLoadFailed: exists = false }

    Timer { interval: 100; running: true; onTriggered: root.go() }
    function go() {
        if (root.step >= root.steps.length) return;
        const s = root.steps[root.step];
        s.run();
        waitTimer.interval = s.wait;
        waitTimer.restart();
        preTimer.interval = Math.max(10, s.wait - 100);
        preTimer.restart();
    }
    Timer { id: preTimer; onTriggered: fileExists.reload() }       // reload() is not synchronous: read the file a moment before the test
    Timer {
        id: waitTimer
        onTriggered: {
            root.steps[root.step].test();
            root.step++;
            root.go();
        }
    }
    Component.onCompleted: console.warn("notes-test: file=" + root.file + " script=" + svc.script)
}
