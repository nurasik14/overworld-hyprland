//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  Logic self-test, no display needed (run it with a throw-away HOME so nothing real is written):
 *      mkdir -p /tmp/ow-home/.config/overworld; echo '{"sounds":false}' > /tmp/ow-home/.config/overworld/config.json
 *      HOME=/tmp/ow-home XDG_RUNTIME_DIR=/tmp/ow-run PATH=/tmp/ow-shim:$PATH OW_SOUND_DRYRUN=1 QT_QPA_PLATFORM=offscreen \
 *          qs -p quickshell/Widgets/preview/selftest.qml
 *  (/tmp/ow-shim/notify-send logs instead of notifying.)  Prints PASS / FAIL lines.
 */
ShellRoot {
    id: root
    property int step: 0
    property int fails: 0
    function check(name, ok, extra) { console.warn((ok ? "PASS " : "FAIL ") + name + (extra !== undefined ? "  [" + extra + "]" : "")); if (!ok) root.fails++ }

    // ---- 1. WidgetsState: positions, per-card switches, layout reset, persisted files
    function stateTests() {
        WidgetsState.setPos("weather", 100.4, 200.6);
        check("setPos rounds + posX/posY", WidgetsState.posX("weather", 1) === 100 && WidgetsState.posY("weather", 1) === 201);
        check("unknown card falls back to default", WidgetsState.posX("nope", 7) === 7);
        WidgetsState.resetPos("weather");
        check("resetPos", WidgetsState.posX("weather", 5) === 5);
        WidgetsState.setCard("cava", false);
        check("setCard off", !WidgetsState.cardOn("cava"));
        WidgetsState.setCard("cava", true);
        check("setCard on", WidgetsState.cardOn("cava"));
        check("cardList has 8 cards", WidgetsState.cardList.length === 8);
        check("opacity from config/theme", Math.abs(WidgetsState.cardOpacity - Theme.widgetOpacity) < 1e-6, WidgetsState.cardOpacity);
    }
    // ---- 2. BrewTimer: lengths, finish → events + sounds + notification, rest 0, sessions
    function brewTests() {
        check("parse 1h30", BrewTimer.parse("1h30") === 5400);
        check("parse 90s", BrewTimer.parse("90s") === 90);
        check("parse 1:30", BrewTimer.parse("1:30") === 90);
        check("rest 0 valid", BrewTimer.validRest(0));
        BrewTimer.startWith("2s", "1s");
        check("startWith → working", BrewTimer.state === "working" && BrewTimer.total === 2, BrewTimer.state);
    }
    Timer {
        id: seq
        interval: 500; repeat: true; running: false
        onTriggered: {
            root.step++;
            if (root.step === 1) { root.stateTests(); root.brewTests(); BrewTimer.nudge("work", 60); }
            if (root.step === 2) {
                root.check("nudge shows pending value at once", BrewTimer.pendingWork >= 60, BrewTimer.pendingWork);
                BrewTimer.pause(); root.check("pause", BrewTimer.state === "paused");
                BrewTimer.resume(); root.check("resume", BrewTimer.state === "working");
            }
            if (root.step === 7) { root.check("brew finished → breaking + 1 session", BrewTimer.state === "breaking" && BrewTimer.sessions === 1, BrewTimer.state + " " + BrewTimer.sessions); }
            if (root.step === 10) {
                root.check("rest finished → idle", BrewTimer.state === "idle", BrewTimer.state);
                BrewTimer.startWith("1s", "0");
            }
            if (root.step === 14) { root.check("rest 0: brew → idle directly", BrewTimer.state === "idle" && BrewTimer.sessions === 2, BrewTimer.state + " " + BrewTimer.sessions); }
            if (root.step === 18) { console.warn("RESULT " + (root.fails === 0 ? "ALL PASS" : root.fails + " FAILED")); Qt.quit() }
        }
    }
    Component.onCompleted: seq.start()
}
