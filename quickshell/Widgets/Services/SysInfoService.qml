pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets.Services

/*  SysInfoService — fastfetch-style facts for the SysInfo card (Services/sysinfo.py).
 *    static  (os, kernel, shell, wm, terminal, packages, host, user): at startup, then every 10 min
 *            (packages are additionally cached in ~/.cache/overworld/packages for 10 min by the script)
 *    dynamic (cpu %, ram %, ramUsed/ramTotal GiB, disk %, diskMount, uptime): every 5 s while the layer is
 *            visible (uptime only changes per minute; the same call serves both).
 */
Singleton {
    id: root
    property var info: ({})
    property var stats: ({})
    readonly property bool ready: info.os !== undefined
    property bool active: WidgetsState.visible

    readonly property string os: info.os || "—"
    readonly property string kernel: info.kernel || "—"
    readonly property string shell: info.shell || "—"
    readonly property string wm: info.wm || "Hyprland"
    readonly property string terminal: info.terminal || "kitty"
    readonly property string packages: info.packages || "—"
    readonly property string host: info.host || ""
    readonly property string user: info.user || ""
    readonly property real cpu: stats.cpu || 0
    readonly property real ram: stats.ram || 0
    readonly property real disk: stats.disk || 0
    readonly property string ramText: stats.ramUsed !== undefined ? (stats.ramUsed + " / " + stats.ramTotal + " GiB") : ""
    readonly property string diskText: stats.diskUsed !== undefined ? (stats.diskUsed + " / " + stats.diskTotal + " GiB · " + stats.diskMount) : ""
    readonly property string uptime: stats.uptime || "—"

    Process {
        id: staticProc
        command: ["python3", ApoConfig.scriptDir + "/sysinfo.py", "static"]
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text) } catch (e) { console.warn("SysInfoService static:", e) } } }
    }
    Process {
        id: dynamicProc
        command: ["python3", ApoConfig.scriptDir + "/sysinfo.py", "dynamic"]
        stdout: StdioCollector { onStreamFinished: { try { root.stats = JSON.parse(text) } catch (e) { console.warn("SysInfoService dynamic:", e) } } }
    }
    Timer { interval: 5000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: if (!dynamicProc.running) dynamicProc.running = true }
    Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!staticProc.running) staticProc.running = true }
}
