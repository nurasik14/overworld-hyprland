pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets.Services

/*  WeatherService — location + Open-Meteo forecast for the Weather card.
 *
 *  Data flow:  Services/weather-fetch.py  →  JSON on stdout  →  `data`
 *    location: ~/.config/overworld/config.json weather.{lat,lon,name}  →  IP geolocation
 *              (ipapi.co, ip-api.com; rejected when its time-zone differs from the machine's)  →  Kowloon.
 *    cache:    ~/.cache/overworld/weather.json — read synchronously at startup (instant paint),
 *              served by the script with stale=true when the network is down.
 *    refresh:  every 30 min, on `refresh()` (retry button) and once at startup.
 *
 *  Exposed: ok, loading, error, stale, city, localTime, temp, apparent, humidity, wind, precipProb,
 *           code, isDay, glyph, condition, hours[] (24 × {hour, label, temp, prob, code}), minTemp, maxTemp.
 */
Singleton {
    id: root

    property var data: null
    property bool loading: false
    property string error: ""
    property string lastFetched: ""

    readonly property bool ok: data !== null && data.forecast !== undefined && data.forecast !== null
    readonly property bool stale: ok && data.stale === true
    readonly property var forecast: ok ? data.forecast : null
    readonly property var current: forecast ? forecast.current : null
    readonly property var hourly: forecast ? forecast.hourly : null
    readonly property string city: data && data.location && data.location.name ? data.location.name : "—"
    readonly property string locationSource: data && data.location ? (data.location.source || "") : ""
    readonly property int utcOffset: forecast && forecast.utc_offset_seconds !== undefined ? forecast.utc_offset_seconds : 0
    readonly property string timezone: forecast ? (forecast.timezone || "") : ""
    readonly property string tempUnit: forecast && forecast.current_units ? (forecast.current_units.temperature_2m || "°C") : "°C"

    readonly property real temp: current ? current.temperature_2m : NaN
    readonly property real apparent: current ? current.apparent_temperature : NaN
    readonly property int humidity: current ? Math.round(current.relative_humidity_2m) : 0
    readonly property real wind: current ? current.wind_speed_10m : 0
    readonly property real precipitation: current ? current.precipitation : 0
    readonly property int code: current ? current.weather_code : -1
    readonly property bool isDay: current ? current.is_day !== 0 : true
    readonly property string glyph: glyphFor(code, isDay)
    readonly property string condition: wordFor(code)

    // ---- clock at the location (ticks every 30 s)
    property date now: new Date()
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    readonly property string localTime: {
        const d = new Date(now.getTime() + utcOffset * 1000);
        const hh = ("0" + d.getUTCHours()).slice(-2), mm = ("0" + d.getUTCMinutes()).slice(-2);
        return hh + ":" + mm;
    }
    // index of the current hour inside the hourly arrays (times are in the location's zone)
    readonly property int hourIndex: {
        if (!hourly || !hourly.time) return 0;
        const d = new Date(now.getTime() + utcOffset * 1000);
        const key = d.toISOString().slice(0, 13);         // "2026-10-29T14"
        for (let i = 0; i < hourly.time.length; i++) if (hourly.time[i].slice(0, 13) === key) return i;
        return 0;
    }
    readonly property int precipProb: hourly && hourly.precipitation_probability ? (hourly.precipitation_probability[hourIndex] || 0) : 0
    readonly property var hours: {
        if (!hourly || !hourly.time) return [];
        const out = [];
        for (let i = hourIndex; i < Math.min(hourIndex + 24, hourly.time.length); i++) {
            const h = parseInt(hourly.time[i].slice(11, 13));
            out.push({
                hour: h,
                label: hourly.time[i].slice(11, 16),
                temp: hourly.temperature_2m[i],
                prob: hourly.precipitation_probability ? hourly.precipitation_probability[i] : 0,
                code: hourly.weather_code ? hourly.weather_code[i] : 0
            });
        }
        return out;
    }
    readonly property real minTemp: hours.length ? Math.min.apply(null, hours.map(h => h.temp)) : 0
    readonly property real maxTemp: hours.length ? Math.max.apply(null, hours.map(h => h.temp)) : 1

    // ---- WMO weather_code → Nerd Font (nf-md-weather_*) glyph + English word
    function nf(cp) { return String.fromCodePoint(cp); }
    function glyphFor(c, day) {
        if (c === 0) return day ? nf(0xF0599) : nf(0xF0594);                   // sunny / night
        if (c === 1 || c === 2) return day ? nf(0xF0595) : nf(0xF0F31);        // partly cloudy
        if (c === 3) return nf(0xF0590);                                        // cloudy
        if (c === 45 || c === 48) return nf(0xF0591);                           // fog
        if (c >= 51 && c <= 57) return nf(0xF0597);                             // drizzle → rainy
        if (c >= 61 && c <= 65) return c === 65 ? nf(0xF0596) : nf(0xF0597);   // rain / pouring
        if (c === 66 || c === 67) return nf(0xF067F);                           // freezing rain (snowy-rainy)
        if (c >= 71 && c <= 77) return nf(0xF0598);                             // snow
        if (c >= 80 && c <= 82) return c === 82 ? nf(0xF0596) : nf(0xF0597);   // showers
        if (c === 85 || c === 86) return nf(0xF0598);                           // snow showers
        if (c === 95) return nf(0xF067E);                                       // thunderstorm
        if (c === 96 || c === 99) return nf(0xF0592);                           // thunderstorm + hail
        return nf(0xF059D);                                                     // unknown → windy
    }
    function wordFor(c) {
        const t = {
            0: "Clear", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
            45: "Fog", 48: "Rime fog",
            51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle", 56: "Freezing drizzle", 57: "Freezing drizzle",
            61: "Light rain", 63: "Rain", 65: "Heavy rain", 66: "Freezing rain", 67: "Freezing rain",
            71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
            80: "Light showers", 81: "Showers", 82: "Violent showers", 85: "Snow showers", 86: "Snow showers",
            95: "Thunderstorm", 96: "Thunderstorm, hail", 99: "Thunderstorm, hail"
        };
        return t[c] || (c < 0 ? "—" : "Unknown");
    }

    // ---- cache first (synchronous), then the network
    FileView {
        id: cache
        path: ApoConfig.cacheDir + "/weather.json"
        blockLoading: true
        printErrors: false
        onLoaded: root.applyText(text(), true)
    }
    function applyText(t, fromCache) {
        if (!t || !t.length) return;
        try {
            const d = JSON.parse(t);
            if (d && d.forecast) {
                if (fromCache) d.stale = true;
                root.data = d;
                root.error = d.error || "";
                if (!fromCache) root.lastFetched = new Date().toLocaleTimeString(Qt.locale(), "HH:mm");
            } else {
                root.error = (d && d.error) ? d.error : "no data";
                if (d && d.location && !root.data) root.data = d;
            }
        } catch (e) {
            root.error = "parse error: " + e;
        }
    }

    Process {
        id: fetcher
        command: ["python3", ApoConfig.scriptDir + "/weather-fetch.py"]
        stdout: StdioCollector { onStreamFinished: root.applyText(text, false) }
        onRunningChanged: root.loading = running
        onExited: (code, status) => { if (code !== 0 && !root.ok) root.error = root.error || ("fetch failed (" + code + ")") }
    }
    function refresh() { if (!fetcher.running) fetcher.running = true }

    Timer { interval: 30 * 60 * 1000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: {
        applyText(cache.text(), true);
        refresh();
    }
}
