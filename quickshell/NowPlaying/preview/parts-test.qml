//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtMultimedia
import Quickshell
import qs.NowPlaying

/*  MirrorStack with real part files, offscreen, steered by a fake browser clock that plays across a part boundary (no sound:
 *  the mirror has no audio output).
 *    OW_PARTS='[{"start":..,"dur":..,"file":".."},…]' OW_PARTS_FROM=<s> OW_PARTS_SECS=<s> QT_QPA_PLATFORM=offscreen \
 *      qs -p quickshell/NowPlaying/preview/parts-test.qml
 *  Every 100 ms one SAMPLE line; PASS / FAIL lines and RESULT at the end: the first part shows in sync, the next one is
 *  preloaded before the boundary, exactly one swap, the picture never drops out across the boundary, in sync afterwards.
 */
ShellRoot {
    Window {
        id: win
        width: 360; height: 202; visible: true; color: "black"
        property int fails: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); if (!ok) fails++; }
        readonly property var parts: JSON.parse(Quickshell.env("OW_PARTS") || "[]")
        readonly property real from: Number(Quickshell.env("OW_PARTS_FROM") || 50)
        readonly property real secs: Number(Quickshell.env("OW_PARTS_SECS") || 16)
        property real t0: Date.now()
        property var clock: ({ valid: true, position: win.from, ts: win.t0, paused: false, rate: 1, duration: 7200 })
        MirrorStack {
            id: m
            anchors.fill: parent
            parts: win.parts
            clock: win.clock
            fadeMs: 0
        }
        function browserAt() { return win.from + (Date.now() - win.t0) / 1000 }
        function slotPos(file) {   // the position on the video's timeline that the player holding `file` shows
            const s = m.front.file === file ? m.front : m.back.file === file ? m.back : null;
            const p = m.partOf(file);
            return s && p ? p.start + s.mediaPlayer.position / 1000 : -1;
        }
        property bool everReady: false
        property int dropouts: 0
        property real worst: 0
        property real worstAfter: 0
        property bool preloadSeen: false
        property real swapAt: -1
        Timer {
            interval: 100; repeat: true; running: true
            property int n: 0
            onTriggered: {
                if (++n % 10 === 0)   // a browser report once a second, like the userscript's
                    win.clock = { valid: true, position: win.browserAt(), ts: Date.now(), paused: false, rate: 1, duration: 7200 };
                const t = win.browserAt(), el = (Date.now() - win.t0) / 1000;
                const f = m.shownFile, drift = f.length ? win.slotPos(f) - t : NaN;
                if (m.ready) win.everReady = true;
                else if (win.everReady) win.dropouts++;
                if (el > 4 && m.ready && Math.abs(drift) > win.worst && (win.swapAt < 0 || el < win.swapAt - 0.2 || el > win.swapAt + 3)) {
                    win.worst = Math.abs(drift);
                    if (win.swapAt >= 0) win.worstAfter = Math.max(win.worstAfter, Math.abs(drift));
                }
                if (m.back.file.length && m.back.ready && m.swaps === 0) win.preloadSeen = true;
                if (m.swaps > 0 && win.swapAt < 0) win.swapAt = el;
                console.warn("SAMPLE t=" + t.toFixed(2) + " shown=" + f.replace(/^.*\//, "") + " drift=" + (isNaN(drift) ? "-" : drift.toFixed(3))
                             + " back=" + m.back.file.replace(/^.*\//, "") + " backReady=" + m.back.ready + " swaps=" + m.swaps
                             + " reason=" + (m.lastDecision ? m.lastDecision.reason : ""));
                if (el >= win.secs) {
                    win.pass("a picture came up", win.everReady);
                    win.pass("the next part was preloaded (ready, behind) before the boundary", win.preloadSeen);
                    win.pass("exactly one swap", m.swaps === 1, m.swaps);
                    win.pass("no dropout to the cover after the first frame", win.dropouts === 0, win.dropouts);
                    win.pass("in sync (|drift| < 0.35 s) outside the 3 s after the swap", win.worst < 0.35, win.worst.toFixed(3));
                    win.pass("the shown part at the end is the second one", m.shownFile === win.parts[win.parts.length - 1].file, m.shownFile);
                    console.warn("RESULT fails=" + win.fails + " worst=" + win.worst.toFixed(3) + " swapAt=" + win.swapAt.toFixed(1));
                    Qt.quit();
                }
            }
        }
    }
}
