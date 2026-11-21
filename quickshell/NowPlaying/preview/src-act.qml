//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Common
import qs.NowPlaying

/*  The source chip + list under real pointer events in an offscreen window (QtTest events into this window only): the chip shows
 *  with 2+ sources, a click opens the list inside the PiP (not a drag), a row click chooses that source (np.choose) and closes the
 *  list, the wheel over the chip calls np.pick("next" / "prev"), leaving the PiP closes the list, one source = no chip.
 *    QT_QPA_PLATFORM=offscreen OW_MODE=light qs -p quickshell/NowPlaying/preview/src-act.qml   -> PASS / FAIL lines, "src act done: N failed"
 */
ShellRoot {
    id: shell
    property var calls: []
    QtObject {
        id: mock
        property real aspect: 16 / 9
        property bool hasMedia: true
        property bool paused: false
        property string title: "pov: you finally beat the ender dragon"
        property string artist: "blocky.builds"
        property string site: "youtube"
        property string sourceLabel: "YouTube"
        property string artUrl: ""
        property string videoFile: ""
        property string videoStatus: "ready"
        property bool isVideo: true
        property bool live: false
        property bool ad: false
        property real duration: 34
        property var clock: ({ valid: true, position: 7, ts: Date.now(), paused: false, rate: 1, duration: 34 })
        property bool canFocus: true
        property bool canToggle: true
        property bool canNext: true
        property bool canPrevious: true
        property bool canLike: false
        property var liked: false
        property var saved: true
        property var reposted: null
        property string busy: ""
        property string actionError: ""
        property string actionErrorFor: ""
        property bool actionErrorFresh: false
        property string tiktokCollection: "Edits"
        property var sources: [
            { id: "tab:a", kind: "bridge", site: "youtube", label: "YouTube", title: "Me at the zoo", artist: "jawed", paused: false },
            { id: "tab:b", kind: "bridge", site: "tiktok", label: "TikTok", title: "pov: dragon", artist: "blocky.builds", paused: true },
            { id: "mpris:spotify", kind: "mpris", site: "spotify", label: "Spotify", title: "Pigstep", artist: "Lena Raine", paused: true }]
        property int sourceCount: sources.length
        property string pinnedId: ""
        property bool auto: pinnedId === ""
        property string shownId: "tab:a"
        property int shownIndex: 1
        property string route: "mpris"
        property string controlsNote: ""
        function choose(id) { shell.calls = shell.calls.concat(["choose " + id]); pinnedId = id; return true }
        function pick(w) { shell.calls = shell.calls.concat(["pick " + w]); return "" }
        function positionNow() { return 7 }
        function fmt(s) { s = Math.floor(s); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
        function act(what) { shell.calls = shell.calls.concat([what]); return true }
        function focusSource() {} function togglePlaying() {} function next() {} function previous() {}
    }
    Window {
        id: win
        width: 700; height: 640
        visible: true
        color: "#4E6B45"
        NowPlayingView { id: view; np: mock; x: 100; y: 40; boxW: 360; mirrorEnabled: false; forceHover: true }
        TestEvent { id: ev }
        property int fails: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); if (!ok) fails++; }
        function find(item, pred) {
            if (pred(item)) return item;
            const kids = item.children || [];
            for (let i = 0; i < kids.length; i++) { const r = find(kids[i], pred); if (r) return r; }
            return null;
        }
        function chip() { return find(view, o => o.objectName === "sourceChip") }
        function list() { return find(view, o => o.objectName === "sourceList") }
        function rows() { return find(list(), o => o.itemAtIndex !== undefined) }
        function at(item) { return item.mapToItem(win.contentItem, item.width / 2, item.height / 2) }
        function clickOn(item) {
            const p = at(item);
            ev.mouseMove(win.contentItem, p.x, p.y, -1, Qt.NoButton, Qt.NoModifier);
            ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
        }
        function wheelOn(item, dy) { const p = at(item); ev.mouseMove(win.contentItem, p.x, p.y, -1, Qt.NoButton, Qt.NoModifier); ev.mouseWheel(win.contentItem, p.x, p.y, Qt.NoButton, Qt.NoModifier, 0, dy, -1); }
        property int step: 0
        Timer { id: tick; interval: 500; repeat: true; running: true; onTriggered: win.next() }
        function next() {
            step++;
            if (step === 1) {
                pass("3 sources: the chip shows the shown source and its number", chip().visible && chip().text === "YouTube 1/3", chip().text);
                pass("the list starts closed", !list().visible);
                clickOn(chip());
            } else if (step === 2) {
                pass("a chip click opens the list inside the PiP", list().visible && view.listShown);
                const l = list().mapToItem(view, 0, 0);
                pass("the list fits inside the PiP", l.x >= 0 && l.y >= 0 && l.x + list().width <= view.width && l.y + list().height <= view.height, l.x + "," + l.y + " " + list().width + "x" + list().height);
                pass("Auto + one row per source", rows().count === 4, rows().count);
                pass("a chip click is not a drag", view.x === 100 && view.y === 40, view.x + "," + view.y);
                clickOn(rows().itemAtIndex(2));
            } else if (step === 3) {
                pass("a row click chooses that source", shell.calls.slice(-1)[0] === "choose tab:b", JSON.stringify(shell.calls));
                pass("... and closes the list", !list().visible);
                pass("pinned: the chip shows the pin glyph", chip().glyph === "󰐃", chip().glyph);
                clickOn(chip());
            } else if (step === 4) {
                clickOn(rows().itemAtIndex(0));
            } else if (step === 5) {
                pass("the Auto row = choose(\"\")", shell.calls.slice(-1)[0] === "choose " && mock.auto === true, JSON.stringify(shell.calls));
                wheelOn(chip(), -120);
            } else if (step === 6) {
                pass("wheel down over the chip = pick next", shell.calls.slice(-1)[0] === "pick next", JSON.stringify(shell.calls));
                wheelOn(chip(), 120);
            } else if (step === 7) {
                pass("wheel up = pick prev", shell.calls.slice(-1)[0] === "pick prev", JSON.stringify(shell.calls));
                pass("the wheel does not move the PiP", view.x === 100 && view.y === 40);
                clickOn(chip());
            } else if (step === 8) {
                pass("(open again)", list().visible);
                view.forceHover = false;
                ev.mouseMove(win.contentItem, 650, 600, -1, Qt.NoButton, Qt.NoModifier);
            } else if (step === 9) {
                pass("the pointer leaves the PiP -> the list closes", !list().visible && !view.listOpen);
                view.forceHover = true;
                mock.sources = [mock.sources[0]];
            } else if (step === 10) {
                pass("one source (Auto) -> no chip", !chip().visible);
                view.boxW = 200; mock.aspect = 9 / 16; mock.sources = mock.sources.concat([{ id: "tab:b", kind: "bridge", site: "tiktok", label: "TikTok", title: "pov", artist: "", paused: true }]);
                mock.sourceLabel = "TikTok";
            } else if (step === 11) {
                const c = chip().mapToItem(view, 0, 0), b = find(view, o => o.glyph === "󰏌").mapToItem(view, 0, 0);
                pass("smallest portrait: the chip is short and does not reach the focus button", chip().visible && chip().text === "1/2" && c.x + chip().width <= b.x, chip().text + " " + (c.x + chip().width) + "<=" + b.x);
                console.warn("src act done: " + fails + " failed");
                tick.running = false;
                Qt.quit();
            }
        }
    }
}
