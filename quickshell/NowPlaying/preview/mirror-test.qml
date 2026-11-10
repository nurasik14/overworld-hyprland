//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtMultimedia
import Quickshell
import qs.NowPlaying

/*  The real mirror player, offscreen, steered by a fake browser clock (no sound: the mirror has no audio output).
 *    OW_MIRROR_FILE=<video> OW_RENDER_OUT=<png> QT_QPA_PLATFORM=offscreen qs -p quickshell/NowPlaying/preview/mirror-test.qml
 *  PASS / FAIL lines: it plays, follows a jump in the browser, pauses on the exact frame, follows the rate, and a frame is drawn.
 */
ShellRoot {
    Window {
        id: win
        width: 480; height: 270; visible: true; color: "black"
        property int fails: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); if (!ok) fails++; }
        property var clock: ({ valid: true, position: 5, ts: Date.now(), paused: false, rate: 1, duration: 19 })
        VideoMirror {
            id: m
            anchors.fill: parent
            source: Quickshell.env("OW_MIRROR_FILE")
            clock: win.clock
        }
        readonly property real pos: m.mediaPlayer.position / 1000
        function browserAt() { return win.clock.paused ? win.clock.position : win.clock.position + (Date.now() - win.clock.ts) / 1000 * win.clock.rate }
        property int step: 0
        Timer {
            interval: 500; repeat: true; running: true
            onTriggered: {
                win.step++;
                const s = win.step;
                if (s === 6) {   // 3 s in
                    win.pass("loaded and playing", m.loaded && m.mediaPlayer.playbackState === MediaPlayer.PlayingState, m.mediaPlayer.mediaStatus);
                    win.pass("no audio output", m.mediaPlayer.audioOutput === null);
                    win.pass("in sync after start (< 0.35 s)", Math.abs(win.pos - win.browserAt()) < 0.35, win.pos.toFixed(2) + " vs " + win.browserAt().toFixed(2));
                    win.pass("a frame is up (ready)", m.ready);
                    win.clock = { valid: true, position: 12, ts: Date.now(), paused: false, rate: 1, duration: 19 };   // the user seeks in the browser
                }
                if (s === 10) {
                    win.pass("followed the browser's seek", Math.abs(win.pos - win.browserAt()) < 0.35, win.pos.toFixed(2) + " vs " + win.browserAt().toFixed(2) + " " + m.lastDecision.reason);
                    win.clock = { valid: true, position: 9.5, ts: Date.now(), paused: true, rate: 1, duration: 19 };    // paused at 9.5
                }
                if (s === 15) {
                    win.pass("paused", m.mediaPlayer.playbackState !== MediaPlayer.PlayingState, m.mediaPlayer.playbackState);
                    win.pass("paused on the browser's frame", Math.abs(win.pos - 9.5) < 0.1, win.pos.toFixed(3));
                    win.clock = { valid: true, position: 2, ts: Date.now(), paused: false, rate: 1.5, duration: 19 };  // 1.5x
                }
                if (s === 22) {
                    win.pass("follows rate 1.5", Math.abs(m.mediaPlayer.playbackRate - 1.5) < 0.1, m.mediaPlayer.playbackRate);
                    win.pass("in sync at 1.5x", Math.abs(win.pos - win.browserAt()) < 0.35, win.pos.toFixed(2) + " vs " + win.browserAt().toFixed(2));
                    m.grabToImage(r => {
                        const out = Quickshell.env("OW_RENDER_OUT") || "/tmp/np-mirror.png";
                        win.pass("frame grabbed", r.saveToFile(out), out);
                        console.warn("RESULT fails=" + win.fails);
                        Qt.quit();
                    });
                }
            }
        }
    }
}
