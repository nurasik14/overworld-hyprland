pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "duration.js" as Dur

/*  WidgetsConfig — read-only view of ~/.config/overworld/config.json for the widget layer.
 *    sounds (bool, default true) · reduced_motion (bool) · weather{lat,lon,name}
 *    brew{work,break}: a number = minutes (25, 2.5) or a duration string ("90s", "1h30m", "1:30"); see duration.js.
 *    break may be 0 (no rest).  Written by `overworld brew set|work|rest`.
 *  Paths: stateDir (~/.config/overworld), cacheDir (~/.cache/overworld), scriptDir (this directory).
 */
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.config/overworld"
    readonly property string cacheDir: home + "/.cache/overworld"
    readonly property string scriptDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

    property var config: ({})
    FileView {
        id: file
        path: root.stateDir + "/config.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }
    function parse(t) {
        try { root.config = JSON.parse(t || "{}") || ({}) } catch (e) { console.warn("WidgetsConfig: config.json parse error:", e); root.config = ({}) }
    }
    function get(path, fallback) {
        let cur = root.config;
        for (const k of path.split(".")) {
            if (cur === null || typeof cur !== "object" || !(k in cur)) return fallback;
            cur = cur[k];
        }
        return cur === undefined || cur === null ? fallback : cur;
    }

    readonly property bool sounds: config.sounds !== false
    readonly property bool reducedMotion: config.reduced_motion === true
    readonly property int brewWorkSeconds: {
        const s = Dur.parse(get("brew.work", 25));
        return s >= 1 ? Math.min(s, 86400) : 1500;
    }
    readonly property int brewBreakSeconds: {
        const s = Dur.parse(get("brew.break", 5));
        return s >= 0 ? Math.min(s, 86400) : 300;
    }
    readonly property int brewWorkMinutes: Math.round(brewWorkSeconds / 60)     // legacy (whole minutes)
    readonly property int brewBreakMinutes: Math.round(brewBreakSeconds / 60)

    // one-shot helpers used by the services
    Process { id: mkdirs; command: ["mkdir", "-p", root.stateDir, root.cacheDir]; running: true }
}
