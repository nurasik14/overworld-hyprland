.pragma library
// sync.js — the mirror player's sync rules, pure (unit-tested by NowPlaying/preview/sync-test.qml).
//
// The browser is the clock. Once a second (and on every play / pause / seek / rate report) the mirror compares its own
// position with where the browser is now and decides one of: nothing, nudge the rate a little, or seek.
//   target(s, nowMs)  where the browser is at nowMs: the reported position + the time since the report × rate (while it plays)
//   decide(s)         { play: bool, rate: real, seekTo: seconds | -1, reason: string }
// s = { mirrorPos, mirrorDuration, loaded, buffering, target, playing, rate, nowMs, lastSeekMs, failedSeeks, fresh }
//   fresh: the browser's numbers are recent enough to steer by (else the mirror just runs free, no seeks)
// Rules: seek when |drift| > SEEK (0.35 s) and no seek in the last COOLDOWN ms (doubling after seeks that did not hold, max 8 s),
// never while buffering; paused = pause and seek to the exact frame; 0.12–0.35 s drift = ±rate nudge (no seek, no stutter);
// past the end of the mirror file = hold the last frame.

// Long videos come in PARTS (the daemon's videos[key].parts: {start, dur, file} on the video's timeline, overlapping by a few s):
//   partClock(c, part, nowMs)   the browser clock seen from inside a part (position - start; before the part starts: paused at 0)
//   pickPart(parts, t, cur)     the part to show at timeline t (-1 = none covers t): keep the current one until SWAP s before
//                               its end, then the covering part that reaches furthest
//   nextPart(parts, cur)        the part that follows cur (starts before cur ends, ends later): preloaded in the second player
// A whole file is one part {start: 0, dur: 0 (= unknown, runs to the file's end)}.

var SEEK = 0.35;
var NUDGE = 0.12;
var COOLDOWN = 2000;
var LEAD = 0.08;        // seeks land a little ahead: decoding the target frame takes about that long

function target(s, nowMs) {
    if (!s || !s.valid) return -1;
    var p = s.position;
    if (!s.paused) {
        var since = Math.max(0, (nowMs - Math.min(s.ts, nowMs)) / 1000);
        p += since * (s.rate > 0 ? s.rate : 1);
    }
    if (s.duration > 0) p = Math.min(p, s.duration);
    return Math.max(0, p);
}

function cooldown(failed) {
    return Math.min(8000, COOLDOWN * Math.pow(2, Math.max(0, failed | 0)));
}

function decide(s) {
    var out = { play: false, rate: 1, seekTo: -1, reason: "" };
    if (!s.loaded) { out.reason = "not loaded"; return out; }
    var rate = s.rate > 0 ? s.rate : 1;
    out.rate = rate;
    if (s.target < 0) { out.play = s.playing; out.reason = "no clock"; return out; }
    var end = s.mirrorDuration > 0 ? s.mirrorDuration - 0.05 : Infinity;
    var t = Math.min(s.target, end);
    var drift = t - s.mirrorPos;           // > 0: the mirror is behind
    var canSeek = s.fresh && !s.buffering && (s.nowMs - s.lastSeekMs) >= cooldown(s.failedSeeks);
    if (!s.playing) {
        out.play = false;
        if (Math.abs(drift) > 0.05 && canSeek) { out.seekTo = t; out.reason = "paused: exact frame"; }
        else out.reason = "paused";
        return out;
    }
    if (s.target >= end && s.mirrorDuration > 0) {   // the browser is past the mirror's end: hold the last frame
        out.play = false;
        if (s.mirrorPos < end - SEEK && canSeek) out.seekTo = end;
        out.reason = "past the end";
        return out;
    }
    out.play = true;
    if (!s.fresh) { out.reason = "free run (stale clock)"; return out; }
    if (Math.abs(drift) > SEEK) {
        if (canSeek) { out.seekTo = Math.min(end, t + LEAD * rate); out.reason = "seek, drift " + drift.toFixed(2); }
        else out.reason = s.buffering ? "buffering" : "cooling down";
        return out;
    }
    if (Math.abs(drift) > NUDGE) {
        out.rate = rate * (drift > 0 ? 1.05 : 0.95);
        out.reason = "nudge " + drift.toFixed(2);
        return out;
    }
    out.reason = "in sync";
    return out;
}

var SWAP = 1.0;         // s before a part's end the next (preloaded, already running in sync) part takes over
var EDGE = 0.05;

function partEnd(p) { return p.dur > 0 ? p.start + p.dur : Infinity; }

function covers(p, t) { return !!p && p.start <= t + EDGE && t < partEnd(p) - EDGE; }

function partClock(c, p, nowMs) {
    if (!c || !c.valid || !p) return { valid: false };
    var dur = p.dur > 0 ? p.dur : (c.duration > 0 ? Math.max(0, c.duration - p.start) : 0);
    var local = target(c, nowMs) - p.start;
    if (local < 0) return { valid: true, position: 0, ts: nowMs, paused: true, rate: c.rate, duration: dur };   // not there yet: frame 0
    return { valid: true, position: c.position - p.start, ts: c.ts, paused: c.paused, rate: c.rate, duration: dur };
}

function pickPart(parts, t, cur) {
    if (!parts || !parts.length || !(t >= 0)) return -1;
    var c = cur >= 0 && cur < parts.length ? parts[cur] : null;
    if (c && covers(c, t) && t < partEnd(c) - SWAP) return cur;
    var best = -1;
    for (var i = 0; i < parts.length; i++) {
        if (i === cur || !covers(parts[i], t)) continue;
        if (best < 0 || partEnd(parts[i]) > partEnd(parts[best])) best = i;
    }
    if (best < 0 && c && covers(c, t)) return cur;   // nothing takes over yet: keep it to its very end
    return best;
}

function nextPart(parts, cur) {
    if (!parts || cur < 0 || cur >= parts.length) return -1;
    var end = partEnd(parts[cur]), best = -1;
    if (end === Infinity) return -1;
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i];
        if (i === cur || p.start > end - SWAP - EDGE || partEnd(p) <= end) continue;
        if (best < 0 || partEnd(p) > partEnd(parts[best])) best = i;
    }
    return best;
}
