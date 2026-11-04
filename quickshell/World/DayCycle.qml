pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "SunCalc.js" as Sun

/*  DayCycle — the Overworld day/night cycle.
 *
 *  config.json  daycycle: "auto" (default) | "day" | "night" | "off"
 *    auto   `overworld light` at local sunrise, `overworld dark` at sunset, and the wallpaper follows the sky
 *           (dawn → day → dusk → night variants of the same scene, assets/wallpapers/index.json)
 *    day / night   pinned: the mode is applied once when chosen and never touched by the cycle again
 *    off    the cycle does nothing
 *  A manual `overworld light|dark` always wins until the next sunrise / sunset: the cycle only acts at a boundary
 *  (and once when a boundary passed while the shell was not running), never in between.
 *
 *  Sun times: SunCalc.js (NOAA formulas) at the Weather widget's location — config weather.{lat,lon}, else the location
 *  in ~/.cache/overworld/weather.json (IP geolocation, same cache as the Weather card), else Kowloon 22.3167, 114.1833.
 *  Cost: one Timer aimed at the next boundary (never more than 10 minutes ahead, to survive suspend); nothing between.
 *
 *  Exposed: setting · phase (dawn|day|dusk|night) · mode (light|dark, what the sun says) · sunrise / sunset (ms) · lat · lon · place
 *  Functions: setSetting(s), describe() (the `world time` text), refresh()
 *  Test pins: OW_WORLD_NOW=<ISO time> fakes the clock (it keeps running), OW_WORLD_DRYRUN=1 or OW_PREVIEW=1 → the apply script
 *  only prints (--dry-run) and the persisted state is not written.
 */
Singleton {
    id: root

    readonly property real fallbackLat: 22.3167
    readonly property real fallbackLon: 114.1833
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/overworld"
    readonly property bool dry: Quickshell.env("OW_WORLD_DRYRUN") === "1" || ShellState.preview

    // ------------------------------------------------------------ clock (fakeable for tests)
    property real clockOffset: {
        const pin = Quickshell.env("OW_WORLD_NOW") || "";
        const t = pin.length ? Date.parse(pin) : NaN;
        return isNaN(t) ? 0 : t - Date.now();
    }
    function nowMs() { return Date.now() + clockOffset; }

    // ------------------------------------------------------------ location
    property real lat: fallbackLat
    property real lon: fallbackLon
    property string place: "Kowloon (fallback)"
    FileView {
        id: weatherFile
        path: root.cacheDir + "/weather.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.readLocation(text())
        onFileChanged: reload()
    }
    function readLocation(text) {
        const cfg = ConfigService.get("weather", null);
        let la = NaN, lo = NaN, name = "";
        if (cfg && typeof cfg.lat === "number" && typeof cfg.lon === "number") {
            la = cfg.lat; lo = cfg.lon; name = cfg.name || "configured";
        } else {
            try {
                const loc = JSON.parse(text).location;
                if (loc && typeof loc.lat === "number" && typeof loc.lon === "number") { la = loc.lat; lo = loc.lon; name = loc.name || "geolocated"; }
            } catch (e) { /* no cache yet */ }
        }
        if (isNaN(la) || isNaN(lo)) { la = fallbackLat; lo = fallbackLon; name = "Kowloon (fallback)"; }
        const moved = Math.abs(la - lat) > 0.01 || Math.abs(lo - lon) > 0.01;
        lat = la; lon = lo; place = name;
        if (moved) evaluate();
    }

    // ------------------------------------------------------------ setting
    readonly property string configured: {
        const v = ConfigService.config.daycycle;
        return v === "day" || v === "night" || v === "off" || v === "auto" ? v : "auto";
    }
    property string setting: "auto"
    property bool _settingKnown: false
    onConfiguredChanged: syncSetting(configured)
    function syncSetting(s) {
        if (_settingKnown && s === setting) return;
        const first = !_settingKnown;
        _settingKnown = true;
        setting = s;
        if (first) { evaluate(); return; }       // startup: adopt, never act on it
        evaluate();
        if (s === "auto") applyNow(info.phase, info.mode);
        else if (s === "day") applyNow("day", "light");
        else if (s === "night") applyNow("night", "dark");
    }
    // `world daycycle <m>` and the Options screen: write config, act at once
    function setSetting(s) {
        if (["auto", "day", "night", "off"].indexOf(s) < 0) return false;
        ConfigService.set("daycycle", s);
        syncSetting(s);
        return true;
    }

    // ------------------------------------------------------------ state
    property var info: ({ phase: "day", mode: "light", next: null, polar: "", sunrise: NaN, sunset: NaN })
    readonly property string phase: info.phase
    readonly property string mode: info.mode
    readonly property real sunrise: info.sunrise
    readonly property real sunset: info.sunset
    property string _lastPhase: ""
    property string _lastMode: ""

    FileView {
        id: savedFile
        path: root.cacheDir + "/daycycle.json"
        blockLoading: true
        printErrors: false
    }
    Process {
        id: saver
        property string payload: ""
        command: ["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/daycycle.json"', "sh", root.cacheDir, payload]
    }
    function persist() {
        if (dry) return;
        saver.payload = JSON.stringify({ phase: _lastPhase, mode: _lastMode, t: Date.now() });
        saver.running = true;
    }

    // ------------------------------------------------------------ the evaluation (runs at a boundary, on a config / location change, and every <= 10 min)
    function evaluate() {
        const t = nowMs();
        const r = Sun.at(t, lat, lon);
        const firstLook = _lastPhase === "";
        info = r;
        if (setting === "auto") {
            if (firstLook) {
                // the sky moved on while the shell was down → catch up once; otherwise (or on a first ever run) leave the desktop alone
                let s = null;
                try { s = JSON.parse(savedFile.text()); } catch (e) { s = null; }
                if (s && s.phase && (s.phase !== r.phase || s.mode !== r.mode)) applyNow(r.phase, s.mode !== r.mode ? r.mode : "");
            } else if (r.phase !== _lastPhase || r.mode !== _lastMode) {
                applyNow(r.phase, r.mode !== _lastMode ? r.mode : "");
            }
        }
        if (r.phase !== _lastPhase || r.mode !== _lastMode) {
            _lastPhase = r.phase; _lastMode = r.mode;
            persist();
        }
        const wait = r.next ? Math.min(Math.max(r.next.t - t + 1500, 1000), 600000) : 600000;
        tick.interval = wait;
        tick.restart();
    }
    Timer { id: tick; interval: 600000; onTriggered: root.evaluate() }
    function refresh() { evaluate(); }

    function applyNow(phase, modeToSet) {
        const cmd = [Theme.repoDir + "/scripts/world/daycycle-apply.sh", "--time", phase];
        if (modeToSet === "light" || modeToSet === "dark") cmd.push("--mode", modeToSet);
        if (dry) {                                   // the script only prints; show what it says
            cmd.push("--dry-run", "--force");
            _dryQueue = _dryQueue.concat([cmd]);
            _nextDry();
            return;
        }
        console.log("DayCycle:", cmd.slice(1).join(" "));
        Quickshell.execDetached(cmd);
    }
    property var _dryQueue: []
    function _nextDry() {
        if (dryRunner.running || !_dryQueue.length) return;
        dryRunner.command = _dryQueue[0];
        _dryQueue = _dryQueue.slice(1);
        dryRunner.running = true;
    }
    Process {
        id: dryRunner
        stdout: StdioCollector { onStreamFinished: console.warn("DRYRUN daycycle-apply:", text.trim().replace(/\n/g, " | ")) }
        onExited: root._nextDry()
    }

    // ------------------------------------------------------------ text for `world time`
    function describe() {
        const t = nowMs();
        const r = info;
        let s = "phase: " + r.phase + " · sun says " + r.mode + " · theme " + Theme.mode + " · daycycle " + setting + "\n";
        if (r.polar !== "") s += "polar " + r.polar + " at " + place + " (no sunrise or sunset today)\n";
        else s += "sunrise " + Sun.clock(r.sunrise) + " · sunset " + Sun.clock(r.sunset) + "  (" + place + " " + lat.toFixed(2) + ", " + lon.toFixed(2) + ")\n";
        if (r.next) {
            const what = r.next.kind === "sun" ? (r.next.mode === "light" ? "sunrise (Day)" : "sunset (Night)") : r.next.phase;
            s += "next: " + what + " at " + Sun.clock(r.next.t) + " (in " + Sun.span(r.next.t - t) + ")";
        } else s += "next: none";
        return s;
    }

    Component.onCompleted: { syncSetting(configured); }
}
