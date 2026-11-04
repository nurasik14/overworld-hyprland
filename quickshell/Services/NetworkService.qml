pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*  NetworkService — NetworkManager via nmcli (argument arrays only; user input is never shell-interpolated).
 *
 *  State:   wifiEnabled · airplane · wifiIface · wiredIface · wiredState · activeSsid · activeSignal
 *           networks  [{ ssid, signal, security, secured, enterprise, active, bssid, freq, known }]  (deduped, strongest first)
 *           vpns      [{ name, type, active, device }]
 *           saved     [connection names]   known(ssid)
 *           busy · lastMessage · lastError · scanning
 *  Actions: refresh() · rescan() · setWifi(bool) · setAirplane(bool)
 *           connect(ssid, password) · disconnect() · forget(ssid) · vpnUp(name) · vpnDown(name)
 *  Polling: `polling` true (panel open) → every 20 s; otherwise a light refresh every 45 s for the bar chip.
 */
Singleton {
    id: root

    property bool wifiEnabled: true
    property bool airplane: false
    property string wifiIface: ""
    property string wiredIface: ""
    property string wiredState: ""        // connected | unavailable | disconnected | ""
    readonly property bool wiredConnected: wiredState.indexOf("connected") === 0
    property string activeSsid: ""
    property int activeSignal: 0
    property var networks: []
    property var vpns: []
    property var saved: []
    property bool busy: false
    property bool scanning: false
    property string lastMessage: ""
    property bool lastError: false
    property bool polling: false
    property int refreshes: 0
    readonly property bool connected: activeSsid.length > 0

    function known(ssid) { return root.saved.indexOf(ssid) >= 0; }
    function signalGlyph(sig) {
        if (sig >= 88) return "󰤨";
        if (sig >= 63) return "󰤥";
        if (sig >= 38) return "󰤢";
        if (sig >= 13) return "󰤟";
        return "󰤯";
    }
    readonly property string glyph: !wifiEnabled ? "󰤮" : (connected ? signalGlyph(activeSignal) : "󰤯")

    // nmcli -t escapes ':' as '\:' and '\' as '\\'
    function splitNm(line) {
        const out = []; let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; continue; }
            if (ch === ":") { out.push(cur); cur = ""; continue; }
            cur += ch;
        }
        out.push(cur);
        return out;
    }
    function lines(text) { return (text || "").split("\n").map(l => l.trim()).filter(l => l.length > 0); }

    // ---------------------------------------------------------------- readers
    Process {
        id: wifiList
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY,BSSID,FREQ", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector { onStreamFinished: root.parseWifi(text) }
    }
    function parseWifi(text) {
        const bySsid = {}; const order = [];
        let act = "", actSig = 0;
        const ls = lines(text);
        for (let i = 0; i < ls.length; i++) {
            const f = splitNm(ls[i]);
            if (f.length < 6) continue;
            const ssid = f[1];
            if (!ssid.length) continue;                      // hidden networks are skipped
            const sig = parseInt(f[2]) || 0;
            const sec = f[3] || "";
            const active = f[0] === "yes";
            const freq = parseInt(f[5]) || 0;
            const entry = { ssid: ssid, signal: sig, security: sec, secured: sec.length > 0 && sec !== "--",
                            enterprise: sec.indexOf("802.1X") >= 0, active: active, bssid: f[4], freq: freq,
                            known: root.known(ssid) };
            if (active) { act = ssid; actSig = sig; }
            const prev = bySsid[ssid];
            if (!prev) { bySsid[ssid] = entry; order.push(ssid); }
            else if (active || (!prev.active && sig > prev.signal)) {
                entry.active = prev.active || active;
                bySsid[ssid] = entry;
            }
        }
        const list = order.map(s => bySsid[s]);
        list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal) || a.ssid.localeCompare(b.ssid));
        root.networks = list;
        root.activeSsid = act;
        root.activeSignal = actSig;
    }

    Process {
        id: devList
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"]
        stdout: StdioCollector { onStreamFinished: root.parseDevices(text) }
    }
    function parseDevices(text) {
        let wifi = "", wired = "", wiredSt = "";
        const ls = lines(text);
        for (let i = 0; i < ls.length; i++) {
            const f = splitNm(ls[i]);
            if (f.length < 3) continue;
            if (f[1] === "wifi" && !wifi) wifi = f[0];
            if (f[1] === "ethernet" && !wired) { wired = f[0]; wiredSt = f[2]; }
        }
        root.wifiIface = wifi; root.wiredIface = wired; root.wiredState = wiredSt;
    }

    Process {
        id: radioState
        command: ["nmcli", "-t", "-f", "WIFI,WWAN", "radio"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = root.splitNm((text || "").trim().split("\n")[0] || "");
                if (f.length >= 1) root.wifiEnabled = f[0] === "enabled";
                root.airplane = f.length >= 1 && f.every(v => v === "disabled");
            }
        }
    }

    Process {
        id: conList
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE,DEVICE", "con", "show"]
        stdout: StdioCollector { onStreamFinished: root.parseConnections(text) }
    }
    function parseConnections(text) {
        const names = []; const v = [];
        const ls = lines(text);
        for (let i = 0; i < ls.length; i++) {
            const f = splitNm(ls[i]);
            if (f.length < 3) continue;
            const type = f[1];
            if (type === "802-11-wireless") names.push(f[0]);
            if (type === "vpn" || type === "wireguard") v.push({ name: f[0], type: type, active: f[2] === "yes", device: f[3] || "" });
        }
        root.saved = names;
        root.vpns = v;
        // refresh `known` flags without waiting for the next wifi list
        root.networks = root.networks.map(n => Object.assign({}, n, { known: names.indexOf(n.ssid) >= 0 }));
    }

    function refresh() {
        root.refreshes++;
        radioState.running = true;
        devList.running = true;
        conList.running = true;
        wifiList.running = true;
    }
    Timer { interval: 20000; repeat: true; running: root.polling; onTriggered: root.refresh() }
    Timer { interval: 45000; repeat: true; running: !root.polling; onTriggered: { radioState.running = true; wifiList.running = true; devList.running = true } }
    Component.onCompleted: refresh()

    // ---------------------------------------------------------------- actions (one at a time)
    property var queue: []
    property var onDone: null          // function(ok, message) for the current command
    Process {
        id: action
        property string outText: ""
        property string errText: ""
        stdout: StdioCollector { onStreamFinished: action.outText = text }
        stderr: StdioCollector { onStreamFinished: action.errText = text }
        onExited: (code, status) => {
            const ok = code === 0;
            const msg = (action.errText.trim() || action.outText.trim()).split("\n").filter(l => l.length).pop() || (ok ? "Done" : "nmcli failed (" + code + ")");
            root.lastMessage = msg.replace(/^Error:\s*/, "nmcli: ");
            root.lastError = !ok;
            root.busy = false;
            root.scanning = false;
            const cb = root.onDone; root.onDone = null;
            if (cb) cb(ok, msg);
            root.refresh();
            root.runNext();
        }
    }
    function run(cmd, cb) {
        root.queue = root.queue.concat([{ cmd: cmd, cb: cb || null }]);
        runNext();
    }
    function runNext() {
        if (root.busy || root.queue.length === 0) return;
        const job = root.queue[0];
        root.queue = root.queue.slice(1);
        root.busy = true;
        root.lastError = false;
        root.lastMessage = "";
        root.onDone = job.cb;
        action.outText = ""; action.errText = "";
        action.command = job.cmd;
        action.running = true;
    }

    function rescan() {
        root.scanning = true;
        run(["nmcli", "dev", "wifi", "rescan"], function(ok, msg) { if (ok) root.lastMessage = "Scan complete"; });
    }
    function setWifi(on) { run(["nmcli", "radio", "wifi", on ? "on" : "off"]); }
    function setAirplane(on) { run(["nmcli", "radio", "all", on ? "off" : "on"]); }
    function disconnect() {
        if (!root.wifiIface.length) { root.lastMessage = "No Wi-Fi interface"; root.lastError = true; return; }
        run(["nmcli", "dev", "disconnect", root.wifiIface]);
    }
    function forget(ssid) { run(["nmcli", "con", "delete", "id", ssid]); }
    function vpnUp(name) { run(["nmcli", "con", "up", "id", name]); }
    function vpnDown(name) { run(["nmcli", "con", "down", "id", name]); }

    // Saved profile first (`con up id`), then a fresh `dev wifi connect [password …]`.
    function connect(ssid, password, cb) {
        const direct = function(cb2) {
            let cmd = ["nmcli", "dev", "wifi", "connect", ssid];
            if (password && password.length) cmd = cmd.concat(["password", password]);
            run(cmd, cb2);
        };
        if (known(ssid) && !(password && password.length)) {
            run(["nmcli", "con", "up", "id", ssid], function(ok, msg) {
                if (ok) { if (cb) cb(true, msg); } else direct(cb);
            });
        } else {
            direct(cb);
        }
    }
}
