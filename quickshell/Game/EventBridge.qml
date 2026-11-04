import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.Common
import qs.Services

/*  EventBridge — makes sure the events the advancements and statistics count really reach the bus, whoever draws the
 *  surface that causes them. Raw Hyprland events, uptime, battery, theme mode and Wi-Fi are watched here; when the
 *  module that owns an event (BRIEF §4.4) has already emitted it a moment earlier/later the synthetic copy is dropped,
 *  so nothing is counted twice.
 *    window.open {cls,title} · window.close {cls} (every close) · window.kill {cls} (a close with no kill event) · workspace {id}
 *    battery {percent,charging} · xp.levelup {level} · mode {mode} · net.connect {ssid}
 *  Synthetic events carry `synth: true`. Pass OW_BRIDGE=0 to disable (preview harness drives events by hand).
 */
Scope {
    id: root
    readonly property bool enabled: Quickshell.env("OW_BRIDGE") !== "0"
    property var recent: []          // [{name, t, key}] bus events seen from anybody
    property var pending: ({})       // key → timer
    readonly property int graceMs: 450

    function keyOf(name, data) {
        data = data || {};
        if (name === "window.open" || name === "window.kill" || name === "window.close") return name + ":" + String(data.cls || "").toLowerCase();
        if (name === "workspace") return name + ":" + data.id;
        if (name === "mode") return name + ":" + data.mode;
        return name;
    }
    function seenRecently(name, key, ms) {
        const now = Date.now();
        return root.recent.some(e => e.name === name && e.key === key && !e.synth && now - e.t <= ms);
    }
    // emit `name` after graceMs unless somebody else emits the same thing meanwhile
    function synth(name, data, windowMs) {
        if (!root.enabled) return;
        const key = keyOf(name, data);
        if (seenRecently(name, key, windowMs || 1500)) return;
        const t = Qt.createQmlObject('import QtQuick; Timer { interval: ' + root.graceMs + '; running: true }', root, "synthTimer");
        t.triggered.connect(() => {
            t.destroy();
            if (seenRecently(name, key, (windowMs || 1500) + root.graceMs)) return;
            GameEvents.emit(name, Object.assign({ synth: true }, data));
        });
    }

    Connections {
        target: GameEvents
        function onEvent(name, data) {
            const d = data || {};
            const now = Date.now();
            const list = root.recent.filter(e => now - e.t < 8000);
            list.push({ name, t: now, key: root.keyOf(name, d), synth: d.synth === true });
            root.recent = list;
        }
    }

    // ---------------------------------------------------------- Hyprland
    property var openWindows: ({})   // address (no 0x) → class
    Process {   // the windows that already exist when the shell starts, so their close is attributed to the right class
        running: root.enabled
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { JSON.parse(text).forEach(w => { root.openWindows[String(w.address).replace(/^0x/, "")] = w["class"] || ""; }); }
                catch (e) { }
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name, d = ev.data || "";
            if (n === "openwindow") {          // address,workspace,class,title
                const p = d.split(",");
                const cls = p[2] || "";
                root.openWindows[p[0]] = cls;
                if (cls.length && p[1] !== "special:magic") root.synth("window.open", { cls: cls, title: p.slice(3).join(",") });
            } else if (n === "closewindow") {
                const cls = root.openWindows[d] || "";
                delete root.openWindows[d];
                GameEvents.emit("window.close", { cls: cls, synth: true });
                if (cls.length) root.synthKill(cls);
            } else if (n === "workspacev2") {  // id,name
                const id = parseInt(d.split(",")[0]);
                if (id > 0) root.synth("workspace", { id: id }, 700);
            }
        }
    }
    // a close counts as mined unless the interaction layer already announced the kill (it does, a moment before the close)
    function synthKill(cls) { root.synth("window.kill", { cls: cls }, 6000); }

    // ---------------------------------------------------------- mode, Wi-Fi, battery, uptime
    property string lastMode: ""
    Connections {
        target: Theme
        function onModeChanged() {
            if (root.lastMode !== "" && root.lastMode !== Theme.mode) root.synth("mode", { mode: Theme.mode }, 3000);
            root.lastMode = Theme.mode;
        }
    }
    property string lastSsid: NetworkService.activeSsid
    Connections {
        target: NetworkService
        function onActiveSsidChanged() {
            const s = NetworkService.activeSsid;
            if (s && s !== root.lastSsid) root.synth("net.connect", { ssid: s }, 5000);
            root.lastSsid = s;
        }
    }
    readonly property var battery: UPower.displayDevice
    property int lastPercent: -1
    property bool lastCharging: false
    function batteryTick() {
        const b = root.battery;
        if (!b || !b.ready || !b.isLaptopBattery) return;
        const pct = Math.round(b.percentage * 100);
        const charging = b.state === UPowerDeviceState.Charging || b.state === UPowerDeviceState.FullyCharged;
        if (pct !== root.lastPercent || charging !== root.lastCharging) {
            root.lastPercent = pct; root.lastCharging = charging;
            root.synth("battery", { percent: pct, charging: charging }, 60000);
        }
    }
    Connections { target: root.battery; function onPercentageChanged() { root.batteryTick(); } function onStateChanged() { root.batteryTick(); } }

    property int lastLevel: -1
    Process {
        id: uptime
        command: ["sh", "-c", "cut -d. -f1 /proc/uptime"]
        stdout: SplitParser { onRead: line => root.uptimeRead(parseInt(line)) }
    }
    function uptimeRead(sec) {
        if (isNaN(sec)) return;
        const level = Math.floor(sec / 3600);
        // advancements that need a level are also fed internally (a shell restarted at 5 h of uptime still earns Level 3)
        if (level > 0) Advancements.feed("xp.levelup", { level: level, catchup: true });
        if (root.lastLevel >= 0 && level > root.lastLevel) root.synth("xp.levelup", { level: level }, 120000);
        root.lastLevel = level;
    }
    Timer { interval: 60000; running: root.enabled; repeat: true; triggeredOnStart: true; onTriggered: uptime.running = true }
}
