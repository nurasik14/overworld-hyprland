//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Common
import qs.NowPlaying

/*  The TikTok like / repost / save row under real pointer events in an offscreen window (QtTest events into this window only):
 *  shown only when the model says canLike, each button calls np.act(<name>), busy disables all three (clicks do nothing), the
 *  glyphs follow the state, and a YouTube source has no row.
 *    QT_QPA_PLATFORM=offscreen OW_MODE=light qs -p quickshell/NowPlaying/preview/tt-act.qml   -> PASS / FAIL lines, "tt act done: N failed"
 */
ShellRoot {
    id: shell
    property var calls: []
    QtObject {
        id: mock
        property real aspect: 9 / 16
        property bool hasMedia: true
        property bool paused: false
        property string title: "pov: you finally beat the ender dragon"
        property string artist: "blocky.builds"
        property string site: "tiktok"
        property string sourceLabel: "TikTok"
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
        property bool canLike: true
        property var liked: false
        property var saved: true
        property var reposted: null
        property string busy: ""
        property string actionError: ""
        property string actionErrorFor: ""
        property bool actionErrorFresh: false
        property string tiktokCollection: "Edits"
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
        function row() { return find(view, o => o.objectName === "tiktokRow") }
        function btn(i) { return row().children[i] }
        function clickOn(item) {
            const p = item.mapToItem(win.contentItem, item.width / 2, item.height / 2);
            ev.mouseMove(win.contentItem, p.x, p.y, -1, Qt.NoButton, Qt.NoModifier);
            ev.mouseClick(win.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
        }
        property int step: 0
        Timer { id: tick; interval: 500; repeat: true; running: true; onTriggered: win.next() }
        function next() {
            step++;
            if (step === 1) {
                pass("TikTok + canLike: the row is shown", row() && row().visible);
                pass("like off = outline heart, save on = filled bookmark, repost unknown = plain", btn(0).glyph === "󰋕" && btn(2).glyph === "󰃀" && btn(1).glyph === "󰕇",
                     btn(0).glyph + btn(1).glyph + btn(2).glyph);
                pass("tooltips name the toggle", btn(0).tooltip === "Like" && btn(2).tooltip === "Un-save" && btn(1).tooltip === "Repost", btn(0).tooltip + "|" + btn(2).tooltip);
                clickOn(btn(0)); clickOn(btn(1)); clickOn(btn(2));
            } else if (step === 2) {
                pass("each button calls act(<name>)", JSON.stringify(shell.calls) === '["like","repost","save"]', JSON.stringify(shell.calls));
                pass("a button click is not a drag", view.x === 100 && view.y === 40, view.x + "," + view.y);
                mock.busy = "repost"; mock.liked = true;
            } else if (step === 3) {
                pass("busy: all three disabled, the running one shows the hourglass", !btn(0).enabled && !btn(1).enabled && !btn(2).enabled && btn(1).glyph === "󰔟");
                clickOn(btn(0)); clickOn(btn(2));
            } else if (step === 4) {
                pass("busy: clicks do nothing", shell.calls.length === 3, JSON.stringify(shell.calls));
                mock.busy = ""; mock.actionError = "TikTok did not toggle the like (logged out?)"; mock.actionErrorFor = "like"; mock.actionErrorFresh = true;
            } else if (step === 5) {
                pass("liked = filled heart, enabled again", btn(0).glyph === "󰋑" && btn(0).enabled && btn(0).tooltip === "Unlike");
                pass("the error is in that button's tooltip", btn(0).tooltipDescription.indexOf("did not toggle") >= 0 && btn(1).tooltipDescription.indexOf("did not toggle") < 0,
                     btn(0).tooltipDescription);
                const line = find(view, o => o.codes !== undefined && String(o.codes).indexOf("did not toggle") >= 0);
                pass("... and on the picture for a few seconds", !!line && line.visible);
                mock.site = "youtube"; mock.canLike = false; mock.aspect = 16 / 9;
            } else if (step === 6) {
                pass("YouTube (canLike false): no row", !row().visible);
                console.warn("tt act done: " + fails + " failed");
                tick.running = false;
                Qt.quit();
            }
        }
    }
}
