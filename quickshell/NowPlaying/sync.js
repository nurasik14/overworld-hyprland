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
