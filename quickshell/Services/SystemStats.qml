pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Common

/*  SystemStats — the numbers behind the HUD rows. Reads /proc every 2 s while anything watches, battery through UPower.
 *    batteryPresent · batteryPct 0..1 · charging · fullyCharged · timeToEmpty · timeToFull (seconds) · batteryFlash (a hurt blink is playing)
 *    memFree 0..1 (MemAvailable/MemTotal) · memTotalMb · memAvailableMb · swapUsed 0..1 · swapHeavy (> 50 % of swap in use)
 *    cpuLoad 0..1 · uptimeHours (real) · level (whole hours) · levelProgress 0..1
 *    signal levelUp(int level)   after emitting `xp.levelup` and playing its sound
 *  Emits `battery {percent, charging}` when the whole percent or the charging state changes.
 *  Listens to `battery {flash: true}` (fx-interactions, one blink at 15 %).
 *  Preview pin OW_FAKE_STATS='{"battery":18,"charging":false,"ram":0.4,"cpu":0.7,"uptime":3.5,"swap":0.6}'.
 */
Singleton {
    id: root

    readonly property var fake: {
        const s = Quickshell.env("OW_FAKE_STATS") || "";
        if (!s.length) return null;
        try { return JSON.parse(s); } catch (e) { return null; }
    }

    // ---------------------------------------------------------------- battery
    readonly property var dev: UPower.displayDevice
    readonly property bool batteryPresent: fake ? fake.battery !== undefined : !!(dev && dev.ready && dev.isLaptopBattery)
    readonly property real batteryPct: fake && fake.battery !== undefined ? fake.battery / 100 : (batteryPresent ? dev.percentage : 1)
    readonly property bool charging: fake ? !!fake.charging
        : batteryPresent && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool fullyCharged: charging && batteryPct >= 0.995
    readonly property real timeToEmpty: fake || !batteryPresent ? 0 : dev.timeToEmpty
    readonly property real timeToFull: fake || !batteryPresent ? 0 : dev.timeToFull
    readonly property int percent: Math.round(batteryPct * 100)
    property bool batteryFlash: false
    Timer { id: flashTimer; interval: 1000; onTriggered: root.batteryFlash = false }

    property bool armed: false      // the first reports at startup are not news
    Timer { interval: 2000; running: true; onTriggered: root.armed = true }
    onPercentChanged: _emitBattery()
    onChargingChanged: _emitBattery()
    function _emitBattery() {
        if (armed && batteryPresent) GameEvents.emit("battery", { percent: percent, charging: charging });
    }
    Connections {
        target: GameEvents
        function onEvent(name, data) {
            if (name === "battery" && data && data.flash) { root.batteryFlash = true; flashTimer.restart(); }
        }
    }

    // ---------------------------------------------------------------- memory, CPU, uptime
    property real memFree: fake && fake.ram !== undefined ? fake.ram : 1
    property real memTotalMb: 0
    property real memAvailableMb: 0
    property real swapUsed: fake && fake.swap !== undefined ? fake.swap : 0
    readonly property bool swapHeavy: swapUsed > 0.5
    property real cpuLoad: fake && fake.cpu !== undefined ? fake.cpu : 0
    property real uptimeHours: fake && fake.uptime !== undefined ? fake.uptime : 0
    readonly property int level: Math.floor(uptimeHours)
    readonly property real levelProgress: uptimeHours - level
    signal levelUp(int level)

    property int _knownLevel: -1
    onLevelChanged: {
        if (_knownLevel < 0) return;
        if (level > _knownLevel) {
            GameEvents.emit("xp.levelup", { level: level });
            Theme.playSound("xp.levelup");
            root.levelUp(level);
        }
        _knownLevel = level;
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.parseMem(text())
    }
    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.parseStat(text())
    }
    FileView {
        id: uptime
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.parseUptime(text())
    }
    function _kb(t, key) {
        const m = t.match(new RegExp("^" + key + ":\\s+(\\d+)", "m"));
        return m ? parseInt(m[1]) : 0;
    }
    function parseMem(t) {
        if (fake) return;
        const total = _kb(t, "MemTotal"), avail = _kb(t, "MemAvailable");
        const swapTotal = _kb(t, "SwapTotal"), swapFree = _kb(t, "SwapFree");
        if (total > 0) {
            root.memFree = avail / total;
            root.memTotalMb = total / 1024;
            root.memAvailableMb = avail / 1024;
        }
        root.swapUsed = swapTotal > 0 ? 1 - swapFree / swapTotal : 0;
    }
    property real _lastTotal: 0
    property real _lastIdle: 0
    function parseStat(t) {
        if (fake) return;
        const f = (t.split("\n")[0] || "").trim().split(/\s+/).slice(1).map(Number);
        if (f.length < 5) return;
        const total = f.reduce((a, b) => a + b, 0), idle = f[3] + f[4];
        if (_lastTotal > 0 && total > _lastTotal) root.cpuLoad = Math.max(0, Math.min(1, 1 - (idle - _lastIdle) / (total - _lastTotal)));
        _lastTotal = total;
        _lastIdle = idle;
    }
    function parseUptime(t) {
        if (fake) return;
        const s = parseFloat((t || "").split(" ")[0]);
        if (isNaN(s)) return;
        root.uptimeHours = s / 3600;
        if (_knownLevel < 0) _knownLevel = level;      // the hours already up when the shell started are not level-ups
    }
    function refresh() { meminfo.reload(); stat.reload(); uptime.reload(); }
    Timer { interval: 2000; repeat: true; running: !root.fake; triggeredOnStart: true; onTriggered: root.refresh() }
    Component.onCompleted: if (fake) _knownLevel = level
}
