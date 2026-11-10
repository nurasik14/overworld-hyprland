//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Common
import qs.NowPlaying

/*  Real pointer events on the scroll in an offscreen window (QtTest's TestEvent, delivered to this window only; nothing live is touched):
 *  hover controls + tooltip, every button, drag, double-click reset, the resize grip following the pointer, the clamp at the window edge.
 *    HOME=<temp home> QT_QPA_PLATFORM=offscreen NP_RENDER_OUT=<png of the tooltip> qs -p quickshell/NowPlaying/preview/act.qml
 *  PASS / FAIL lines, then "nowplaying act done: N failed".   (quickshell/NowPlaying/preview/render.sh act runs it with a temp HOME)
 */
ShellRoot {
    id: shell
    property var calls: []
    QtObject {
        id: mock
        property real aspect: 16 / 9
        property bool hasMedia: true
        property bool paused: false
        property string title: "Me at the zoo"
        property string artist: "jawed"
        property string site: "youtube"
        property string sourceLabel: "YouTube"
        property string artUrl: ""
        property string videoFile: ""
        property string videoStatus: "ready"
        property bool isVideo: true
        property bool live: false
        property bool ad: false
        property real duration: 19
        property var clock: ({ valid: true, position: 7, ts: Date.now(), paused: false, rate: 1, duration: 19 })
        property bool canFocus: true
        property bool canToggle: true
        property bool canNext: true
        property bool canPrevious: true
        function positionNow() { return 7 }
        function fmt(s) { s = Math.floor(s); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
        function focusSource() { shell.calls = shell.calls.concat(["focus"]) }
        function togglePlaying() { shell.calls = shell.calls.concat(["toggle"]) }
        function next() { shell.calls = shell.calls.concat(["next"]) }
        function previous() { shell.calls = shell.calls.concat(["previous"]) }
    }
    Window {
        id: win
        width: 1000; height: 640
        visible: true
        color: Theme.isDark ? "#1c1a17" : "#cfc4aa"
        Item {
            id: stage
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Theme.isDark ? "#1c1a17" : "#cfc4aa" }
            NowPlayingView {
                id: view
                np: mock
                x: 100; y: 80
                boxW: 360
                mirrorEnabled: false
                property int drags: 0
                property int resizes: 0
                property int resets: 0
                property int closes: 0
                onDragFinished: drags++
                onResizeFinished: resizes++
                onResetRequested: resets++
                onCloseRequested: closes++
            }
        }
        TestEvent { id: ev }
        property int fails: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); if (!ok) fails++; }
        function at(item, dx, dy) { return item.mapToItem(win.contentItem, dx === undefined ? item.width / 2 : dx, dy === undefined ? item.height / 2 : dy) }
        function find(item, pred) {
            if (pred(item)) return item;
            const kids = item.children || [];
            for (let i = 0; i < kids.length; i++) { const r = find(kids[i], pred); if (r) return r; }
            return null;
        }
        function chip(tip) { return find(view, o => o.tooltip === tip && o.glyph !== undefined) }
        function move(p) { ev.mouseMove(win.contentItem, p.x, p.y, -1, Qt.NoButton, Qt.NoModifier) }
        function click(p) { ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1) }
        function dragBy(p, dx, dy) {
            ev.mousePress(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
            for (let i = 1; i <= 10; i++) ev.mouseMove(win.contentItem, p.x + dx * i / 10, p.y + dy * i / 10, 15, Qt.LeftButton, Qt.NoModifier);
            ev.mouseRelease(win.contentItem, p.x + dx, p.y + dy, Qt.LeftButton, Qt.NoModifier, 15);
        }
        property int step: 0
        property real right0: 0
        Timer {
            id: tick
            interval: 700; repeat: true; running: true
            onTriggered: win.next()
        }
        function next() {
            step++;
            if (step === 1) {
                pass("not hovered at start", !view.hovered);
                move(at(chip("Close (turn the PiP off)")));
            } else if (step === 2) {
                pass("hover shows the controls", view.hovered);
                const tipBox = find(chip("Close (turn the PiP off)"), o => o.text === "Close (turn the PiP off)" && o.font !== undefined);
                if (tipBox) pass("tooltip shown after the delay", tipBox.parent.visible);
                stage.grabToImage(r => r.saveToFile(Quickshell.env("NP_RENDER_OUT") || "/tmp/np-act.png"));
                click(at(chip("Close (turn the PiP off)")));
            } else if (step === 3) {
                pass("✕ = closeRequested", view.closes === 1, view.closes);
                click(at(chip("Pause"))); click(at(chip("Next"))); click(at(chip("Previous"))); click(at(chip("Show the source window")));
            } else if (step === 4) {
                pass("⏯ ⏭ ⏮ 󰏌 reach the player", JSON.stringify(shell.calls) === '["toggle","next","previous","focus"]', JSON.stringify(shell.calls));
                pass("a chip click is not a drag", view.drags === 0 && view.x === 100, view.drags + " " + view.x);
                // drag by the strip's title
                dragBy(at(view, view.width / 2, view.height - 40), 60, -30);
            } else if (step === 5) {
                pass("drag moves it", Math.abs(view.x - 160) <= 1 && Math.abs(view.y - 50) <= 1, view.x + "," + view.y);
                pass("dragFinished once", view.drags === 1, view.drags);
                const p = at(view, view.width / 2, view.height - 40);
                ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, 10);
                ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, 120);
            } else if (step === 6) {
                pass("double-click the strip = resetRequested", view.resets === 1, view.resets);
                click(at(view, view.width / 2, view.height - 40));       // one lone click (checked next step: no reset)
                win.right0 = view.x + view.width;
                const g = find(view, o => o.objectName === "grip");
                win.gripPos = at(g);
                dragBy(win.gripPos, 100, 0);
            } else if (step === 7) {
                const grew = view.x + view.width - win.right0;
                pass("grip follows the pointer (right edge +100)", Math.abs(grew - 100) <= 3, grew.toFixed(1) + " px, boxW " + view.boxW);
                pass("resize keeps the top-left corner", Math.abs(view.x - 160) <= 1 && Math.abs(view.y - 50) <= 1, view.x + "," + view.y);
                pass("resizeFinished", view.resizes === 1, view.resizes);
                pass("a single click on the strip does not reset", view.resets === 1, view.resets);
                const g = find(view, o => o.objectName === "grip");
                dragBy(at(g), 900, 900);
            } else if (step === 8) {
                pass("clamped to the window", view.x + view.width <= win.width + 0.5 && view.y + view.height <= win.height + 0.5,
                     (view.x + view.width).toFixed(1) + "x" + (view.y + view.height).toFixed(1) + " boxW " + view.boxW);
                pass("clamp is tight (reaches an edge within 4 px)", win.width - (view.x + view.width) <= 4 || win.height - (view.y + view.height) <= 4,
                     (win.width - view.x - view.width).toFixed(1) + " / " + (win.height - view.y - view.height).toFixed(1));
                console.warn("nowplaying act done: " + fails + " failed");
                tick.running = false;
                Qt.quit();
            }
        }
        property point gripPos: Qt.point(0, 0)
    }
}
