.pragma library
/*  duration.js — the brew timer's duration grammar (shared by BrewTimer, ApoConfig and the brew dialog).
 *  Same rules as `brew_parse` in scripts/overworld:
 *    25 · 2.5          bare number = minutes
 *    25m · 90s · 1h    units h/hr/hour(s), m/min/minute(s), s/sec/second(s)
 *    1h30 · 1m30       a bare number after a unit means the next smaller unit (1h30 = 1 h 30 min)
 *    1:30 · 1:05:00    m:ss · h:mm:ss
 *    0 · off · none    zero (only meaningful for the rest)
 *  parse() returns whole seconds, or NaN when the text is not a duration.
 */

function parse(v) {
    if (typeof v === "number") return isFinite(v) && v >= 0 ? Math.round(v * 60) : NaN;
    let s = String(v === undefined || v === null ? "" : v).trim().toLowerCase();
    if (s === "") return NaN;
    if (s === "off" || s === "none" || s === "no") return 0;
    let m = s.match(/^(\d+):(\d{1,2})(?::(\d{1,2}))?$/);
    if (m) {
        if (m[3] !== undefined) return parseInt(m[1]) * 3600 + parseInt(m[2]) * 60 + parseInt(m[3]);
        return parseInt(m[1]) * 60 + parseInt(m[2]);
    }
    s = s.replace(/\s+/g, "");
    const re = /(\d+(?:\.\d+)?|\.\d+)([a-z]*)/g;
    const unitOf = { h: 3600, hr: 3600, hrs: 3600, hour: 3600, hours: 3600,
                     m: 60, min: 60, mins: 60, minute: 60, minutes: 60,
                     s: 1, sec: 1, secs: 1, second: 1, seconds: 1 };
    let total = 0, pos = 0, last = 0;
    while ((m = re.exec(s)) !== null) {
        if (m.index !== pos) return NaN;
        pos = re.lastIndex;
        let unit;
        if (m[2] === "") unit = last === 0 ? 60 : (last === 3600 ? 60 : 1);
        else unit = unitOf[m[2]];
        if (!unit || (last !== 0 && unit >= last)) return NaN;   // unknown unit, or 30m1h
        total += parseFloat(m[1]) * unit;
        last = unit;
    }
    if (pos !== s.length || last === 0) return NaN;
    return Math.round(total);
}

// 1500 → "25 min" · 5400 → "1 h 30 min" · 90 → "1 min 30 s" · 0 → "0 min"
function human(sec) {
    sec = Math.max(0, Math.round(sec));
    const h = Math.floor(sec / 3600), mi = Math.floor(sec % 3600 / 60), se = sec % 60;
    const parts = [];
    if (h) parts.push(h + " h");
    if (mi) parts.push(mi + " min");
    if (se) parts.push(se + " s");
    return parts.length ? parts.join(" ") : "0 min";
}

// compact form for small labels: 1500 → "25m" · 5400 → "1h30m" · 90 → "1m30s"
function short(sec) {
    sec = Math.max(0, Math.round(sec));
    const h = Math.floor(sec / 3600), mi = Math.floor(sec % 3600 / 60), se = sec % 60;
    let out = (h ? h + "h" : "") + (mi ? mi + "m" : "") + (se ? se + "s" : "");
    return out || "0m";
}

// clock face: 1500 → "25:00" · 5400 → "1:30:00"
function clock(sec) {
    sec = Math.max(0, Math.floor(sec));
    const h = Math.floor(sec / 3600), mi = Math.floor(sec % 3600 / 60), se = sec % 60;
    const two = n => (n < 10 ? "0" : "") + n;
    return h ? h + ":" + two(mi) + ":" + two(se) : two(mi) + ":" + two(se);
}
