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
 *           code, isDay, kind (clear|cloudy|fog|rain|thunder|snow), icon (pixel-icon name), condition,
 *           hours[] (24 × {hour, label, temp, prob, code, day, block}), minTemp, maxTemp.
 *  For other modules (fx-world): services/weather-fetch.py also writes ~/.cache/overworld/weather-now.json
 *  ({kind, code, is_day, temp, precip_mm, wind, city, stale, updated}) after every fetch, next to weather.json
 *  (the full Open-Meteo forecast + location).  See docs/WIDGETS.md.
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
    readonly property string kind: kindFor(code)
    readonly property string icon: iconFor(code, isDay)
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
                code: hourly.weather_code ? hourly.weather_code[i] : 0,
                day: h >= 6 && h < 18,
                block: blockFor(hourly.weather_code ? hourly.weather_code[i] : 0, h >= 6 && h < 18)
            });
        }
        return out;
    }
    readonly property real minTemp: hours.length ? Math.min.apply(null, hours.map(h => h.temp)) : 0
    readonly property real maxTemp: hours.length ? Math.max.apply(null, hours.map(h => h.temp)) : 1

    // ---- WMO weather_code → kind, pixel icon (Widgets/assets/weather/<name>.png) and the block a 24 h column is built from
    function kindFor(c) {
        if (c === 95 || c === 96 || c === 99) return "thunder";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "snow";
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return "rain";
        if (c === 45 || c === 48) return "fog";
        if (c === 2 || c === 3) return "cloudy";
        return "clear";
    }
    function iconFor(c, day) {
        if (c === 0 || c === 1) return day ? "sun" : "moon";
        if (c === 2) return day ? "partly_day" : "partly_night";
        if (c === 3) return "cloud";
        if (c === 45 || c === 48) return "fog";
        if (c === 56 || c === 57 || c === 66 || c === 67) return "sleet";
        if ((c >= 51 && c <= 65) || (c >= 80 && c <= 82)) return "rain";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "snow";
        if (c >= 95) return "thunder";
        return "cloud";
    }
    // block per condition: sunny sand, starry-night lapis, cloud wool, fog stone, rain water, snow, sleet ice, storm gold
    function blockFor(c, day) {
        if (c === 0 || c === 1) return day ? "sand" : "lapis_block";
        if (c === 2) return day ? "sandstone" : "blue_wool";
        if (c === 3) return "light_gray_wool";
        if (c === 45 || c === 48) return "smooth_stone";
        if (c === 56 || c === 57 || c === 66 || c === 67) return "packed_ice";
        if ((c >= 51 && c <= 65) || (c >= 80 && c <= 82)) return "water_still";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "snow";
        if (c >= 95) return "gold_block";
        return "stone";
    }
    // flat colour standing in for a block texture when no texture pack is present
    function blockColor(b) {
        const m = { sand: "#DBD3A0", lapis_block: "#1D47A8", sandstone: "#D8CB9B", blue_wool: "#3A4CB0", light_gray_wool: "#9D9D97",
                    smooth_stone: "#9E9E9E", packed_ice: "#8DB4EE", water_still: "#3F76E4", snow: "#F8FEFE", gold_block: "#F9D749", stone: "#7F7F7F" };
        return m[b] || "#808080";
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
        path: WidgetsConfig.cacheDir + "/weather.json"
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
        command: ["python3", WidgetsConfig.scriptDir + "/weather-fetch.py"]
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
