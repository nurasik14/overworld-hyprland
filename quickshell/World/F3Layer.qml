import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  F3Layer — the debug screen. Layer `overworld-f3` (Overlay, click-through), IPC `world f3 on|off|toggle`, `world f3graph on|off|toggle`.
 *
 *  Looks like the game's F3: white text with the hard 1-px drop shadow, every line on a #90505050 grey strip, 9 GUI px per line,
 *  left column from the top-left, right column right-aligned. Costs nothing while hidden. While shown:
 *    scripts/world/f3-sampler.sh   cursor 4x/s, active window + backlight 1x/s (one process, killed on hide)
 *    /proc/meminfo                 once a second
 *    the lines themselves          bindings on SystemStats (2 s), HyprlandState, NetworkService, DayCycle, WeatherState
 *  Static facts (kernel, CPU model, GPU names, monitor, versions) come from scripts/world/f3-static.sh, run once on the first open.
 *  The graph (CPU load, one column per 2 s, newest on the right) is the game's frame-time chart; it only samples while it is shown.
 *
 *  Mapping (documented in docs/WORLD.md):  XYZ = cursor x · screen height − cursor y · workspace id;  Block = active window x y w×h;
 *  Facing = which way the last workspace switch went;  Biome = window class;  Client Light = backlight 0..15;
 *  Local Difficulty = CPU load × 6.75 (the game's maximum) and the uptime in days;  Targeted Block = window title.
 */
Scope {
    id: root
    property bool shown: false
    property bool graph: false

    // ------------------------------------------------------------ static facts
    property var st: ({})
    property bool staticAsked: false
    onShownChanged: if (shown && !staticAsked) { staticAsked = true; staticProc.running = true; }
    Process {
        id: staticProc
        command: [Theme.repoDir + "/scripts/world/f3-static.sh"]
        stdout: StdioCollector { onStreamFinished: { try { root.st = JSON.parse(text); } catch (e) { console.warn("F3: static facts:", e); } } }
    }

    // ------------------------------------------------------------ live samples
    property real cursorX: 0
    property real cursorY: 0
    property var win: ({})
    property int backlight: -1
    Process {
        id: sampler
        running: root.shown
        command: [Theme.repoDir + "/scripts/world/f3-sampler.sh"]
        stdout: SplitParser { onRead: line => root.feed(line) }
    }
    function feed(line) {
        const k = line.charAt(0), rest = line.slice(2);
        if (k === "C") {
            const m = rest.match(/(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/);
            if (m) { cursorX = parseFloat(m[1]); cursorY = parseFloat(m[2]); }
        } else if (k === "W") {
            try { win = JSON.parse(rest); } catch (e) { win = {}; }
        } else if (k === "B") {
            backlight = parseInt(rest);
        }
    }

    // memory, once a second while shown
    property real memTotal: 0
    property real memAvail: 0
    property real swapTotal: 0
    property real swapFree: 0
    FileView { id: meminfo; path: "/proc/meminfo"; printErrors: false; onLoaded: root.parseMem(text()) }
    function _kb(t, key) { const m = t.match(new RegExp("^" + key + ":\\s+(\\d+)", "m")); return m ? parseInt(m[1]) : 0; }
    function parseMem(t) {
        memTotal = _kb(t, "MemTotal") / 1024; memAvail = _kb(t, "MemAvailable") / 1024;
        swapTotal = _kb(t, "SwapTotal") / 1024; swapFree = _kb(t, "SwapFree") / 1024;
    }
    Timer { interval: 1000; repeat: true; running: root.shown; triggeredOnStart: true; onTriggered: meminfo.reload() }

    // which way the last workspace switch went
    property int prevWs: HyprlandState.focusedId
    property int lastWs: HyprlandState.focusedId
    property string facing: "north (Towards negative Z)"
    Connections {
        target: HyprlandState
        function onFocusedIdChanged() {
            root.prevWs = root.lastWs;
            root.lastWs = HyprlandState.focusedId;
            if (root.lastWs === root.prevWs) return;
            root.facing = root.lastWs > root.prevWs ? "east (Towards positive X)" : "west (Towards negative X)";
        }
    }

    // CPU graph: newest sample last
    readonly property int graphColumns: 120
    property var cpuHistory: []
    Timer {
        interval: 2000; repeat: true; running: root.shown && root.graph; triggeredOnStart: true
        onTriggered: { const h = root.cpuHistory.slice(-(root.graphColumns - 1)); h.push(SystemStats.cpuLoad); root.cpuHistory = h; }
    }

    // ------------------------------------------------------------ the lines
    function p2(n) { return n < 10 ? "0" + n : String(n); }
    function ns(s, n) { s = String(s || ""); return s.length > n ? s.slice(0, n - 1) + "…" : s; }
    function fixed(v, d) { return Number(v).toFixed(d); }
    readonly property var mon: st.monitor || ({ name: "", w: 0, h: 0, hz: 60 })
    readonly property int screenH: mon.h > 0 ? mon.h : 1080
    readonly property int windowTotal: {
        let n = 0; const s = HyprlandState.slots;
        for (const k in s) if (Number(k) > 0) n += s[k].count;
        return n;
    }
    readonly property string wcls: win.cls ? String(win.cls).toLowerCase().replace(/[^a-z0-9_.\-]+/g, "_") : ""
    readonly property int light: backlight >= 0 ? Math.round(backlight * 15 / 100) : 15
    readonly property string dayText: DayCycle.setting + ", " + DayCycle.phase
        + (DayCycle.info.next ? " → " + (DayCycle.info.next.kind === "sun" ? (DayCycle.info.next.mode === "light" ? "sunrise" : "sunset") : DayCycle.info.next.phase)
                                + " " + clockOf(DayCycle.info.next.t) : "")
    function clockOf(ms) { const d = new Date(ms); return p2(d.getHours()) + ":" + p2(d.getMinutes()); }
    function span(sec) { const m = Math.max(0, Math.round(sec / 60)); return m >= 60 ? Math.floor(m / 60) + "h" + p2(m % 60) + "m" : m + "m"; }

    readonly property var leftLines: {
        const L = [];
        L.push("Overworld Hyprland " + (st.version || "1.0") + " (Hyprland " + (st.hyprland || "?") + "/vanilla)");
        L.push(mon.hz + " fps T: " + mon.hz + " vsync " + (ConfigService.reducedMotion ? "fast-clouds" : "fancy-clouds"));
        L.push("E: " + HyprlandState.info(HyprlandState.focusedId).count + "/" + windowTotal);
        L.push("");
        L.push("XYZ: " + fixed(cursorX, 3) + " / " + fixed(Math.max(0, screenH - cursorY), 5) + " / " + fixed(HyprlandState.focusedId, 3));
        L.push(win.w !== undefined ? "Block: " + Math.round(win.x) + " " + Math.round(win.y) + " " + Math.round(win.w) + "x" + Math.round(win.h) : "Block: none");
        L.push("Chunk: " + Math.floor(cursorX / 16) + " " + Math.floor(Math.max(0, screenH - cursorY) / 16) + " " + HyprlandState.focusedId + " in " + (mon.name || "?"));
        L.push("Facing: " + facing + " (" + prevWs + " → " + HyprlandState.focusedId + ")");
        L.push("Client Light: " + light + " (" + light + " sky, 0 block)");
        L.push("Biome: minecraft:" + (wcls.length ? wcls : "the_void"));
        L.push("Local Difficulty: " + fixed(SystemStats.cpuLoad * 6.75, 2) + " // 0.00 (Day " + Math.floor(SystemStats.uptimeHours / 24) + ")");
        L.push("Day cycle: " + dayText);
        L.push("Weather: " + (WeatherState.pauseReason.length && WeatherState.kind !== "clear" ? WeatherState.kind + " (paused: " + WeatherState.pauseReason + ")" : WeatherState.kind) + " [" + WeatherState.source + "]");
        L.push("Game mode: " + ConfigService.gamemode + ", " + (ConfigService.difficulty === "peaceful" ? "Peaceful" : "Normal"));
        return L;
    }

    readonly property var rightLines: {
        const R = [];
        const usedMb = Math.max(0, memTotal - memAvail);
        R.push("Kernel: Linux " + (st.kernel || "?") + " 64bit");
        R.push("Mem: " + Math.round(memTotal > 0 ? usedMb * 100 / memTotal : 0) + "% " + Math.round(usedMb) + "/" + Math.round(memTotal) + "MB");
        R.push("Allocated: " + Math.round(swapTotal > 0 ? (swapTotal - swapFree) * 100 / swapTotal : 0) + "% " + Math.round(swapTotal - swapFree) + "MB swap");
        R.push("CPU: " + (st.cores || 1) + "x " + (st.cpu || "?"));
        R.push("");
        R.push("Display: " + mon.w + "x" + mon.h + " @" + mon.hz + "Hz (" + (mon.name || "?") + ")");
        const g = st.gpus || [];
        for (let i = 0; i < g.length; i++) R.push(String(g[i]));
        if (st.driver) R.push("NVIDIA driver " + st.driver);
        R.push("");
        if (win.w !== undefined) {
            R.push("Targeted Block: " + ns(win.title || "(untitled)", 48));
            R.push("minecraft:" + (wcls.length ? wcls : "window"));
        }
        if (SystemStats.batteryPresent) {
            R.push("Battery: " + SystemStats.percent + "% (" + (SystemStats.fullyCharged ? "full" : (SystemStats.charging ? "charging" : "discharging"))
                   + (!SystemStats.charging && SystemStats.timeToEmpty > 0 ? ", " + span(SystemStats.timeToEmpty) : "") + ")");
        }
        R.push("Network: " + (NetworkService.activeSsid.length ? NetworkService.activeSsid : (NetworkService.wiredConnected ? "wired" : "disconnected")));
        const up = Math.floor(SystemStats.uptimeHours * 60);
        R.push("Uptime: " + Math.floor(up / 60) + "h " + (up % 60) + "m");
        return R;
    }

    // ------------------------------------------------------------ window
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool here: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === modelData.name
            WlrLayershell.namespace: "overworld-f3"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}
            visible: root.shown && here

            Column {
                x: Theme.px(2); y: Theme.px(2)
                spacing: 0
                Repeater { model: root.leftLines; F3Row { required property string modelData; text: modelData } }
            }
            ColumnLayout {
                anchors { right: parent.right; rightMargin: Theme.px(2) }
                y: Theme.px(2)
                spacing: 0
                Repeater { model: root.rightLines; F3Row { required property string modelData; text: modelData; Layout.alignment: Qt.AlignRight } }
            }

            // ---- frame-time-style chart of the CPU load
            Item {
                id: chart
                visible: root.graph
                x: Theme.px(2)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.px(2)
                width: root.graphColumns * Theme.px(2)
                height: Theme.px(60 + 11)
                F3Row { text: "CPU " + Math.round(SystemStats.cpuLoad * 100) + "%  (" + (root.graphColumns * 2 / 60) + " min)"; y: 0 }
                Rectangle {
                    id: plot
                    y: Theme.px(11)
                    width: parent.width; height: Theme.px(60)
                    color: "#90505050"
                    Repeater {
                        model: root.graphColumns
                        Rectangle {
                            required property int index
                            readonly property real v: {
                                const h = root.cpuHistory;
                                const at = h.length - (root.graphColumns - index);
                                return at >= 0 ? h[at] : -1;
                            }
                            visible: v >= 0
                            x: index * Theme.px(2); width: Theme.px(2)
                            height: Math.max(Theme.px(1), Math.round(Math.max(0, v) * plot.height / Theme.gui) * Theme.gui)
                            anchors.bottom: parent.bottom
                            color: Qt.hsva(Math.max(0, 0.33 - v * 0.33), 0.85, 0.95, 0.9)
                        }
                    }
                    Repeater {
                        model: [{ f: 0.5, t: "50%" }, { f: 1.0, t: "100%" }]
                        Item {
                            required property var modelData
                            width: plot.width; y: plot.height - Math.round(modelData.f * plot.height)
                            Rectangle { width: parent.width; height: Theme.px(1); color: "#c0ffffff" }
                            McText { text: modelData.t; x: Theme.px(1); y: Theme.px(1); color: "#ffffff" }
                        }
                    }
                }
            }
        }
    }

    // One F3 line: grey strip behind white shadowed text
    component F3Row: Item {
        id: row
        property string text: ""
        height: Theme.px(9)
        width: label.contentWidth + Theme.px(2)
        Rectangle {
            visible: row.text.length > 0
            anchors.fill: parent
            color: "#90505050"
        }
        McText {
            id: label
            visible: row.text.length > 0
            x: Theme.px(1); y: Theme.px(1)
            text: row.text
            color: "#ffffff"
            shadowColor: Theme.guiTextShadow
        }
    }
}
