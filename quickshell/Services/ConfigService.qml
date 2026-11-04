pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*  ConfigService — ~/.config/overworld/config.json (user overrides), watched live.
 *  Defaults apply when the file is missing or malformed:
 *    sounds: true · reduced_motion: false · notifications.timeout {low 4000, normal 7000} · weather {…}
 *  ConfigService.get("notifications.timeout.normal", 7000)
 */
Singleton {
    id: root
    readonly property string path: Quickshell.env("HOME") + "/.config/overworld/config.json"
    property var config: ({})
    property bool loaded: false

    readonly property bool sounds: config.sounds !== false
    readonly property bool reducedMotion: config.reduced_motion === true
    readonly property int timeoutLow: get("notifications.timeout.low", 4000)
    readonly property int timeoutNormal: get("notifications.timeout.normal", 7000)

    function get(dotted, fallback) {
        let cur = root.config;
        const parts = dotted.split(".");
        for (let i = 0; i < parts.length; i++) {
            if (cur === null || typeof cur !== "object" || !(parts[i] in cur)) return fallback;
            cur = cur[parts[i]];
        }
        return cur === undefined ? fallback : cur;
    }

    function parse(t) {
        try {
            const obj = JSON.parse(t || "{}");
            root.config = (obj && typeof obj === "object") ? obj : {};
        } catch (e) {
            console.warn("ConfigService: config.json parse error:", e);
            root.config = {};
        }
        root.loaded = true;
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
        onLoadFailed: error => { root.config = {}; root.loaded = true; poll.running = true }
    }
    Timer {   // file missing: look again every 5 s so a later `overworld` install is picked up
        id: poll
        interval: 5000; repeat: true; running: false
        onTriggered: file.reload()
    }
    Component.onCompleted: parse(file.text())
}
