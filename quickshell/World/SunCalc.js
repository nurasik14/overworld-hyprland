.pragma library

/*  SunCalc.js — sunrise / sunset and the Overworld day phases, computed locally (no network).
 *
 *  Sun position: NOAA "General Solar Position Calculations" (Meeus-based; accurate to about a minute).
 *      zenith 90.833° (the sun's upper limb at the horizon, refraction included)
 *  Phases (the picture that matches the sky; `overworld light|dark` flips at sunrise / sunset, not at these):
 *      dawn   sunrise − 30 min … sunrise + 45 min
 *      day    … sunset − 60 min
 *      dusk   … sunset + 30 min
 *      night  … next dawn
 *  Polar day / polar night (no sunrise or sunset that date) give one constant phase and no boundaries.
 *
 *  All times are epoch milliseconds (UTC); callers format them in local time.
 */

var RAD = Math.PI / 180;
var MIN = 60000;
var DAY = 86400000;

var DAWN_BEFORE = 30 * MIN, DAWN_AFTER = 45 * MIN, DUSK_BEFORE = 60 * MIN, DUSK_AFTER = 30 * MIN;

function _julianCentury(ms) { return (ms / DAY + 2440587.5 - 2451545.0) / 36525.0; }

// Declination (radians) and equation of time (minutes) at instant ms
function _sun(ms) {
    var t = _julianCentury(ms);
    var L0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
    var M = 357.52911 + t * (35999.05029 - 0.0001537 * t);
    var e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    var Mr = M * RAD;
    var C = Math.sin(Mr) * (1.914602 - t * (0.004817 + 0.000014 * t))
          + Math.sin(2 * Mr) * (0.019993 - 0.000101 * t) + Math.sin(3 * Mr) * 0.000289;
    var trueLong = L0 + C;
    var omega = 125.04 - 1934.136 * t;
    var lambda = trueLong - 0.00569 - 0.00478 * Math.sin(omega * RAD);
    var eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    var eps = eps0 + 0.00256 * Math.cos(omega * RAD);
    var decl = Math.asin(Math.sin(eps * RAD) * Math.sin(lambda * RAD));
    var y = Math.tan(eps * RAD / 2); y = y * y;
    var L0r = L0 * RAD;
    var eq = 4 / RAD * (y * Math.sin(2 * L0r) - 2 * e * Math.sin(Mr) + 4 * e * y * Math.sin(Mr) * Math.cos(2 * L0r)
           - 0.5 * y * y * Math.sin(4 * L0r) - 1.25 * e * e * Math.sin(2 * Mr));
    return { decl: decl, eq: eq };
}

// The solar day whose noon is nearest to `ms` shifted by `dayOffset` days: { sunrise, sunset, noon, polar }
// polar: "" | "day" | "night"
function solarDay(ms, lat, lon, dayOffset) {
    var local = Math.floor((ms + lon * 4 * MIN) / DAY) + (dayOffset || 0);   // mean solar date number
    var midnightUtc = local * DAY - lon * 4 * MIN;                              // 00:00 mean solar time of that date, as UTC ms
    var noonGuess = midnightUtc + 12 * 60 * MIN;
    var s = _sun(noonGuess);
    var noon = noonGuess - s.eq * MIN;
    s = _sun(noon);                                                             // second pass at the real solar noon
    noon = midnightUtc + 12 * 60 * MIN - s.eq * MIN;
    var latr = lat * RAD;
    var arg = Math.cos(90.833 * RAD) / (Math.cos(latr) * Math.cos(s.decl)) - Math.tan(latr) * Math.tan(s.decl);
    if (arg > 1) return { sunrise: NaN, sunset: NaN, noon: noon, polar: "night" };
    if (arg < -1) return { sunrise: NaN, sunset: NaN, noon: noon, polar: "day" };
    var ha = Math.acos(arg) / RAD;                                              // degrees
    return { sunrise: noon - ha * 4 * MIN, sunset: noon + ha * 4 * MIN, noon: noon, polar: "" };
}

// Every boundary around `ms` (3 solar days), sorted: { t, kind: "phase"|"sun", phase, mode? }
//   phase boundaries start a phase; sun boundaries are the sunrise (mode light) and the sunset (mode dark)
function boundaries(ms, lat, lon) {
    var out = [];
    for (var d = -1; d <= 1; d++) {
        var s = solarDay(ms, lat, lon, d);
        if (isNaN(s.sunrise)) continue;
        out.push({ t: s.sunrise - DAWN_BEFORE, kind: "phase", phase: "dawn" });
        out.push({ t: s.sunrise, kind: "sun", mode: "light" });
        out.push({ t: s.sunrise + DAWN_AFTER, kind: "phase", phase: "day" });
        out.push({ t: s.sunset - DUSK_BEFORE, kind: "phase", phase: "dusk" });
        out.push({ t: s.sunset, kind: "sun", mode: "dark" });
        out.push({ t: s.sunset + DUSK_AFTER, kind: "phase", phase: "night" });
    }
    out.sort(function (a, b) { return a.t - b.t; });
    return out;
}

// { phase, mode, next: {t, kind, phase|mode} | null, polar, sunrise, sunset }  at instant ms
//   sunrise / sunset: the ones of the current solar day (for display)
function at(ms, lat, lon) {
    var today = solarDay(ms, lat, lon, 0);
    if (today.polar !== "") {
        return { phase: today.polar, mode: today.polar === "day" ? "light" : "dark", next: null, polar: today.polar,
                 sunrise: NaN, sunset: NaN };
    }
    var list = boundaries(ms, lat, lon);
    var phase = "night", mode = "dark", next = null;
    for (var i = 0; i < list.length; i++) {
        var b = list[i];
        if (b.t <= ms) {
            if (b.kind === "phase") phase = b.phase; else mode = b.mode;
        } else if (next === null) {
            next = b;
        }
    }
    return { phase: phase, mode: mode, next: next, polar: "", sunrise: today.sunrise, sunset: today.sunset };
}

function pad(n) { return (n < 10 ? "0" : "") + n; }
function clock(ms) { if (isNaN(ms)) return "--:--"; var d = new Date(ms); return pad(d.getHours()) + ":" + pad(d.getMinutes()); }
function span(ms) {
    var m = Math.max(0, Math.round(ms / MIN));
    return m >= 60 ? Math.floor(m / 60) + "h" + pad(m % 60) + "m" : m + "m";
}
