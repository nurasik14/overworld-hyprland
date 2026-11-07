pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Common
import qs.Services

/*  WeatherState — which weather the overlay draws, and whether it may draw at all.
 *
 *  Source:    ~/.cache/overworld/weather-now.json (the Weather widget's summary, rewritten after each Open-Meteo fetch).
 *             When it is older than 40 minutes (the widget is not running, e.g. a preview) it is refreshed every 15 minutes by running the
 *             widget's own fetch script, so the shared cache stays the single source.
 *  Override:  `world weather clear|rain|thunder|snow` (/weather) wins over it; `auto` goes back to the real weather. Not persisted, like the game.
 *  kind:      "clear" | "rain" | "thunder" | "snow"   (cloudy and fog draw nothing: clear = layer hidden)
 *  Pauses (pauseReason, "" = may draw):
 *             config weather_effects false · game mode adventure / spectator · a fullscreen window on the focused workspace ·
 *             battery below 20 % and not charging · reduced motion / animations off
 *  Density:   config particles "all" → up to 3 layers, "decreased" → 2, "minimal" → 1; heavier real rain (precip_mm) uses more of them.
 *  frame:     the shared 20 TPS clock; runs only while the overlay is shown.  flash: the lightning white-out 0..1 (thunder only).
 */
Singleton {
    id: root

    // ------------------------------------------------------------ what the sky is doing
    property string override: ""                 // "" = auto
    property string realKind: "clear"
    property real precipMm: 0
    property real updated: 0
    readonly property string kind: override.length ? override : realKind
    readonly property string source: override.length ? "override (" + override + ")" : "open-meteo (" + realKind + ")"

    readonly property int layersWanted: {
        let n = precipMm >= 2.5 ? 3 : (precipMm >= 0.3 ? 2 : 1);
        if (override === "thunder") n = 3; else if (override.length) n = 2;
        else if (realKind === "thunder") n = Math.max(n, 2);
        const cap = ConfigService.particles === "minimal" ? 1 : (ConfigService.particles === "decreased" ? 2 : 3);
        return Math.min(n, cap);
    }

    function setOverride(w) {
        if (["clear", "rain", "thunder", "snow"].indexOf(w) >= 0) { override = w; return true; }
        if (w === "auto") { override = ""; return true; }
        return false;
    }

    // ------------------------------------------------------------ pauses
    property bool fullscreen: false
    readonly property bool onBattery: SystemStats.discharging
    readonly property string pauseReason: {
        if (!ConfigService.weatherEffects) return "weather_effects is off";
        if (ConfigService.gamemode === "adventure" || ConfigService.gamemode === "spectator") return "game mode " + ConfigService.gamemode;
        if (Theme.reducedMotion) return "reduced motion";
        if (fullscreen || Quickshell.env("OW_WORLD_FAKE_FS") === "1") return "fullscreen window";
        if (onBattery && SystemStats.batteryPct < 0.2) return "battery below 20 %";
        return "";
    }
    readonly property bool wanted: kind !== "clear" && pauseReason === ""
    readonly property bool animating: wanted        // the layer windows may keep a longer fade-out; they run the clock only through this

    // ------------------------------------------------------------ the clock (20 TPS) and the lightning
    property int frame: 0
    property real flash: 0
    property int _stage: 0                           // 0 idle · 1 first stroke fading · 2 gap · 3 second stroke fading
    property int _gap: 0
    property bool fadingOut: false                   // the layer sets this while its fade-out still draws
    Timer {
        interval: 50; repeat: true
        running: root.animating || root._stage !== 0 || root.fadingOut
        onTriggered: { root.frame = (root.frame + 1) % 1000000; root._flashTick(); }
    }
    property bool holdFlash: false                   // `world strike hold` (screenshots): keep the first stroke on screen
    function _flashTick() {                          // two quick strokes, like the game's double flash
        if (holdFlash) return;
        if (_stage === 1) { flash = Math.max(0, flash - 0.085); if (flash === 0) { _stage = 2; _gap = 2; } }
        else if (_stage === 2) { if (--_gap <= 0) { flash = 0.22; _stage = 3; } }
        else if (_stage === 3) { flash = Math.max(0, flash - 0.045); if (flash === 0) _stage = 0; }
    }
    function strike() {
        if (kind !== "thunder" || !wanted) return;
        flash = 0.34;
        _stage = 1;
        if (ConfigService.get("weather_thunder_sound", false) === true) Theme.playSound("lightning");
    }
    Timer {                                          // a stroke every 6-20 s while it storms
        id: stormClock
        interval: 8000
        running: root.wanted && root.kind === "thunder"
        repeat: true
        onTriggered: { root.strike(); interval = 6000 + Math.random() * 14000; }
    }

    // ------------------------------------------------------------ source file
    FileView {
        id: nowFile
        path: Quickshell.env("HOME") + "/.cache/overworld/weather-now.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.read(text())
        onFileChanged: reload()
    }
    function read(text) {
        try {
            const d = JSON.parse(text);
            const k = String(d.kind || "clear");
            realKind = (k === "rain" || k === "thunder" || k === "snow") ? k : "clear";
            precipMm = Number(d.precip_mm) || 0;
            updated = Number(d.updated) || 0;
        } catch (e) { realKind = "clear"; }
    }
    readonly property string fetchScript: Theme.repoDir + "/quickshell/Widgets/Services/weather-fetch.py"
    Process { id: fetcher; command: ["python3", root.fetchScript]; stdout: StdioCollector {} }
    Timer {
        interval: 15 * 60 * 1000; repeat: true; running: !ShellState.preview
        onTriggered: if (!fetcher.running && Date.now() / 1000 - root.updated > 40 * 60) fetcher.running = true
    }

    // ------------------------------------------------------------ fullscreen on the focused workspace
    Process {
        id: wsQuery
        command: ["hyprctl", "-j", "activeworkspace"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.fullscreen = JSON.parse(text).hasfullscreen === true; } catch (e) { /* keep */ } }
        }
    }
    Timer { id: wsSoon; interval: 250; onTriggered: if (!wsQuery.running) wsQuery.running = true }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "fullscreen") root.fullscreen = String(event.data).trim() === "1";
            else if (n === "workspace" || n === "workspacev2" || n === "focusedmon" || n === "closewindow" || n === "movewindow" || n === "movewindowv2") wsSoon.restart();
        }
    }
    Component.onCompleted: if (!ShellState.preview || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) wsSoon.restart()
}
