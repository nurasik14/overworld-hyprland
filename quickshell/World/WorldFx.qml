import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*  WorldFx — the world effects module (fx-world): day/night cycle, weather overlay, F3 debug screen. See docs/WORLD.md.
 *
 *  IPC  (qs -c overworld ipc call world <fn> [arg]):
 *    weather <clear|rain|thunder|snow|auto>   override the weather overlay; auto = the real Open-Meteo weather (/weather)
 *    daycycle <auto|day|night|off>            set config daycycle and act at once (/time set …); auto syncs to the sky now
 *    strike [hold|release]                    one lightning stroke now (thunder only)
 *    time                                     phase, sunrise / sunset, the next transition
 *    f3 <on|off|toggle>                       the debug screen (SUPER+F3, /f3)
 *    f3graph <on|off|toggle>                  the CPU chart under it (turns F3 on)
 *    status                                   one line: weather, pauses, day cycle, F3
 */
Scope {
    id: root

    WeatherLayer {}
    F3Layer { id: f3screen }
    Component.onCompleted: DayCycle.refresh()      // instantiate the day cycle (a singleton starts on first use)

    function _flag(cur, v) { return v === "on" ? true : (v === "off" ? false : !cur); }

    IpcHandler {
        target: "world"
        function weather(w: string): string {
            const ok = WeatherState.setOverride(w);
            return ok ? "weather: " + WeatherState.kind + (WeatherState.pauseReason.length ? " (paused: " + WeatherState.pauseReason + ")" : "")
                      : "usage: weather clear|rain|thunder|snow|auto";
        }
        function daycycle(m: string): string {
            return DayCycle.setSetting(m) ? "daycycle: " + m : "usage: daycycle auto|day|night|off";
        }
        function strike(mode: string): string {        // one lightning stroke now; "hold" keeps it lit (screenshots), "release" lets go
            if (mode === "release") { WeatherState.holdFlash = false; return "released"; }
            WeatherState.holdFlash = mode === "hold";
            WeatherState.strike();
            return WeatherState.kind === "thunder" ? "stroke" : "no stroke: weather is " + WeatherState.kind;
        }
        function time(): string { return DayCycle.describe(); }
        function f3(state: string): string { f3screen.shown = root._flag(f3screen.shown, state); return f3screen.shown ? "F3 on" : "F3 off"; }
        function f3graph(state: string): string {
            f3screen.graph = root._flag(f3screen.graph, state);
            if (f3screen.graph) f3screen.shown = true;
            return f3screen.graph ? "F3 graph on" : "F3 graph off";
        }
        function status(): string {
            return "weather=" + WeatherState.kind + " (" + WeatherState.source + ")"
                 + " paused=" + (WeatherState.pauseReason.length ? WeatherState.pauseReason : "no")
                 + " layers=" + WeatherState.layersWanted
                 + " daycycle=" + DayCycle.setting + " phase=" + DayCycle.phase
                 + " f3=" + f3screen.shown + " graph=" + f3screen.graph;
        }
    }
}
