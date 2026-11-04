pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets.Services

/*  CavaService — spawns `cava -p ~/.cache/overworld/cava.conf` (raw ascii output, 24 bars, 0–100) and
 *  parses each frame into `values`.  The process only runs while the widget layer is visible (`active`);
 *  `idle` becomes true after ~1.5 s of silence so the card can rest its bars at the minimum height.
 */
Singleton {
    id: root
    readonly property int bars: 24
    property bool active: WidgetsState.visible && WidgetsState.cardOn("cava")
    property var values: new Array(bars).fill(0)
    property bool idle: true
    property bool available: true
    readonly property string confPath: WidgetsConfig.cacheDir + "/cava.conf"
    property int silentFrames: 0

    readonly property string conf:
        "[general]\nbars = " + bars + "\nframerate = 30\nautosens = 1\nsensitivity = 100\n" +
        "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\n" +
        "[smoothing]\nnoise_reduction = 70\n"

    Process {
        id: writer
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "cava-conf", root.confPath, root.conf]
        onExited: (code, status) => { root.confReady = code === 0; if (code !== 0) console.warn("CavaService: could not write", root.confPath) }
    }
    property bool confReady: false
    Component.onCompleted: writer.running = true

    Process {
        id: cava
        command: ["cava", "-p", root.confPath]
        running: root.active && root.confReady
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.parse(line)
        }
        onExited: (code, status) => {
            if (root.active && code !== 0) { root.available = false; console.warn("CavaService: cava exited with", code) }
            root.values = new Array(root.bars).fill(0); root.idle = true;
        }
        onStarted: root.available = true
    }

    function parse(line) {
        const parts = line.split(";");
        if (parts.length < bars) return;
        const out = new Array(bars);
        let sum = 0;
        for (let i = 0; i < bars; i++) { const v = parseInt(parts[i]) || 0; out[i] = v; sum += v }
        root.values = out;
        if (sum === 0) { if (++silentFrames > 45) root.idle = true }
        else { silentFrames = 0; root.idle = false }
    }
}
