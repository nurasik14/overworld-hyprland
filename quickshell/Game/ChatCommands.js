.pragma library

// Pure helpers for the chat console (no QML types): durations, tokenising, completion matching.

// "25m" "1h30m" "90s" "1h 30" "45" (bare number = minutes) → seconds, or -1
function parseDuration(s) {
    s = String(s || "").trim().toLowerCase().replace(/\s+/g, "");
    if (!s.length) return -1;
    if (/^\d+(\.\d+)?$/.test(s)) return Math.round(parseFloat(s) * 60);
    const re = /(\d+(?:\.\d+)?)(h|m|s)/g;
    let m, total = 0, used = 0;
    while ((m = re.exec(s)) !== null) {
        total += parseFloat(m[1]) * (m[2] === "h" ? 3600 : m[2] === "m" ? 60 : 1);
        used += m[0].length;
    }
    // "1h30" → trailing bare number counts as minutes
    const tail = s.slice(used);
    if (/^\d+$/.test(tail) && used > 0 && /h$/.test(s.slice(0, used))) { total += parseInt(tail) * 60; used += tail.length; }
    return used === s.length && used > 0 ? Math.round(total) : -1;
}

function durationLabel(sec) {
    const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
    const out = [];
    if (h) out.push(h + (h === 1 ? " hour" : " hours"));
    if (m) out.push(m + (m === 1 ? " minute" : " minutes"));
    if (s && !h) out.push(s + (s === 1 ? " second" : " seconds"));
    return out.length ? out.join(" ") : "0 seconds";
}

// split "/tp 3" style input into words; `rest(i)` of the raw string after word i keeps original spacing
function words(line) { return String(line).trim().length ? String(line).trim().split(/\s+/) : []; }
function restAfter(line, n) {
    let s = String(line).replace(/^\s+/, "");
    for (let i = 0; i < n; i++) s = s.replace(/^\S+\s*/, "");
    return s.trim();
}

function commonPrefix(list) {
    if (!list.length) return "";
    let p = list[0];
    for (let i = 1; i < list.length; i++) {
        let j = 0;
        while (j < p.length && j < list[i].length && p[j].toLowerCase() === list[i][j].toLowerCase()) j++;
        p = p.slice(0, j);
    }
    return p;
}

// candidates that start with the prefix; only when none does, the ones that contain it (≥ 2 chars); case-insensitive, deduplicated
function filterCandidates(items, prefix) {
    const p = String(prefix || "").toLowerCase();
    const seen = {}, starts = [], contains = [];
    items.forEach(it => {
        const l = String(it).toLowerCase();
        if (seen[l]) return;
        seen[l] = true;
        if (l.startsWith(p)) starts.push(it); else if (p.length >= 2 && l.indexOf(p) >= 0) contains.push(it);
    });
    return starts.length ? starts : contains;
}

function slug(s) { return String(s || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }
function flat(s) { return String(s || "").toLowerCase().replace(/[^a-z0-9]+/g, ""); }

// does an app entry/window match the user's word? exact id/class/name → 3, prefix → 2, contains → 1, else 0
function matchScore(query, fields) {
    const q = flat(query);
    if (!q.length) return 0;
    let best = 0;
    fields.forEach(f => {
        const v = flat(f);
        if (!v.length) return;
        if (v === q) best = Math.max(best, 3);
        else if (v.startsWith(q)) best = Math.max(best, 2);
        else if (v.indexOf(q) >= 0) best = Math.max(best, 1);
    });
    return best;
}
