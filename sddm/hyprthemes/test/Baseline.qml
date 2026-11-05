// The user's Silent theme with nothing of ours around it, for comparing the Waguri look against what the login screen shows today.
import QtQuick
import QtQuick.Window
import QtTest

Item {
    id: harness
    width: 1920
    height: 1080
    readonly property string outDir: Qt.application.arguments.length ? String(baselineOut) : ""
    readonly property string baselineOut: "@OUT@"
    Loader { id: look; anchors.fill: parent; focus: true; source: "Main.qml" }
    TestEvent { id: ev }
    function shot(name) { look.grabToImage(r => { r.saveToFile(baselineOut + "/" + name + ".png"); console.warn("TEST SHOT " + name); }); }
    Timer { interval: 1500; running: true; onTriggered: harness.Window.window.requestActivate() }
    Timer { interval: 4500; running: true; onTriggered: harness.shot("baseline-lock") }
    Timer { interval: 5000; running: true; onTriggered: ev.keyClick(Qt.Key_Space, Qt.NoModifier, 10) }
    Timer { interval: 7000; running: true; onTriggered: harness.shot("baseline-login") }
    Timer { interval: 7500; running: true; onTriggered: console.warn("TEST DONE") }
}
