// node tests/nowplaying-sync.test.js — the mirror's sync rules (quickshell/NowPlaying/sync.js), pure.
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../quickshell/NowPlaying/sync.js"), "utf8").replace(/^\.pragma library.*$/m, "");
const S = new Function(src + "; return { target, decide, cooldown, SEEK, NUDGE, COOLDOWN, LEAD, partClock, pickPart, nextPart, SWAP };")();
let pass = 0, fail = 0;
const ok = (n, c, x) => { if (c) { pass++; console.log("PASS " + n); } else { fail++; console.log("FAIL " + n + (x !== undefined ? "  [" + JSON.stringify(x) + "]" : "")); } };
const base = o => Object.assign({ loaded: true, target: 10, mirrorPos: 10, mirrorDuration: 100, buffering: false, playing: true, rate: 1,
                                  nowMs: 100000, lastSeekMs: 0, failedSeeks: 0, fresh: true }, o);
// target()
ok("target: playing extrapolates", Math.abs(S.target({ valid: true, position: 5, ts: 1000, paused: false, rate: 1, duration: 0 }, 3000) - 7) < 1e-9);
ok("target: rate 2", Math.abs(S.target({ valid: true, position: 5, ts: 1000, paused: false, rate: 2, duration: 0 }, 3000) - 9) < 1e-9);
ok("target: paused holds", S.target({ valid: true, position: 5, ts: 1000, paused: true, rate: 1, duration: 0 }, 9000) === 5);
ok("target: a future ts does not run backwards", S.target({ valid: true, position: 5, ts: 9000, paused: false, rate: 1, duration: 0 }, 3000) === 5);
ok("target: clamped to the duration", S.target({ valid: true, position: 99, ts: 0, paused: false, rate: 1, duration: 100 }, 5000) === 100);
ok("target: invalid = -1", S.target({ valid: false }, 0) === -1);
// decide()
let d;
d = S.decide(base({ loaded: false })); ok("not loaded: nothing", !d.play && d.seekTo === -1);
d = S.decide(base({})); ok("in sync: play, no seek, rate 1", d.play && d.seekTo === -1 && d.rate === 1, d);
d = S.decide(base({ target: 10.2 })); ok("behind 0.2 s: nudge faster, no seek", d.play && d.seekTo === -1 && d.rate > 1, d);
d = S.decide(base({ target: 9.8 })); ok("ahead 0.2 s: nudge slower", d.rate < 1 && d.seekTo === -1, d);
d = S.decide(base({ target: 10.1 })); ok("0.1 s: inside the dead band", d.rate === 1 && d.seekTo === -1, d);
d = S.decide(base({ target: 11 })); ok("behind 1 s: seek ahead by the lead", Math.abs(d.seekTo - (11 + S.LEAD)) < 1e-9, d);
d = S.decide(base({ target: 11, rate: 2 })); ok("seek lead scales with rate", Math.abs(d.seekTo - (11 + 2 * S.LEAD)) < 1e-9 && d.rate === 2, d);
d = S.decide(base({ target: 11, lastSeekMs: 99000 })); ok("cooldown: no seek 1 s after a seek", d.seekTo === -1 && d.play, d);
d = S.decide(base({ target: 11, lastSeekMs: 97000, failedSeeks: 1 })); ok("seeks that did not hold double the cooldown", d.seekTo === -1, d);
d = S.decide(base({ target: 11, lastSeekMs: 95000, failedSeeks: 1 })); ok("…and seek again after it", d.seekTo > 0, d);
ok("cooldown capped at 8 s", S.cooldown(10) === 8000);
d = S.decide(base({ target: 11, buffering: true })); ok("never seek while buffering", d.seekTo === -1 && d.play, d);
d = S.decide(base({ target: 30, fresh: false })); ok("stale clock: free run, no seek", d.play && d.seekTo === -1 && d.rate === 1, d);
d = S.decide(base({ playing: false, target: 12.5 })); ok("paused: pause and seek to the exact frame", !d.play && d.seekTo === 12.5, d);
d = S.decide(base({ playing: false, target: 10.03 })); ok("paused, already there: no seek", !d.play && d.seekTo === -1, d);
d = S.decide(base({ target: 150, mirrorPos: 50 })); ok("browser past the mirror's end: hold the last frame", !d.play && Math.abs(d.seekTo - 99.95) < 1e-9, d);
d = S.decide(base({ target: -1 })); ok("no clock: just play", d.play && d.seekTo === -1);
// a simulated minute: the mirror drifts 3 % slow and stalls once; seeks stay rare
let mirror = 0, browser = 0, now = 0, lastSeek = -1e9, seeks = 0, maxDrift = 0;
for (let t = 1; t <= 60; t++) {
    now = t * 1000; browser = t;
    const stall = t === 20 ? 1.5 : 0;
    if (t > 3 && t !== 21) maxDrift = Math.max(maxDrift, Math.abs(browser - mirror));   // at each decision; t 21 = right after the stall
    const dd = S.decide(base({ target: browser, mirrorPos: mirror, nowMs: now, lastSeekMs: lastSeek }));
    if (dd.seekTo >= 0) { mirror = dd.seekTo; lastSeek = now; seeks++; }
    mirror += 0.97 * (dd.rate) - stall;
}
ok("simulated minute: few seeks (" + seeks + ")", seeks <= 4, seeks);
ok("simulated minute: drift at decisions stays under 0.45 s (" + maxDrift.toFixed(2) + " s)", maxDrift < 0.45, maxDrift);
// ---- long videos in parts. Starts as the daemon records them: the asked start minus the keyframe pre-roll (measured live:
// a cut asked at 50:00 began 3.737 s earlier), parts overlapping by the 8 s the daemon asks for plus that pre-roll
const P = [{ start: 3000 - 3.737, dur: 63.86, file: "p1" }, { start: 3051 - 2.1, dur: 181, file: "p2" }, { start: 5000 - 1.2, dur: 61, file: "p3" }];
const clk = (pos, o) => Object.assign({ valid: true, position: pos, ts: 50000, paused: false, rate: 1, duration: 6377.9 }, o);
let pc = S.partClock(clk(3000), P[0], 50000);
ok("partClock: position inside the part = timeline - true start (the pre-roll counted)", Math.abs(pc.position - 3.737) < 1e-9 && !pc.paused && pc.duration === 63.86, pc);
pc = S.partClock(clk(3000), P[0], 52000);
ok("partClock: still extrapolates with the browser clock", Math.abs(S.target(pc, 52000) - 5.737) < 1e-9, pc);
pc = S.partClock(clk(3040), P[1], 50000);
ok("partClock: before the part starts -> paused at frame 0 (the preload waits)", pc.paused && pc.position === 0, pc);
pc = S.partClock(clk(3060, { paused: true }), P[1], 50000);
ok("partClock: paused stays paused", pc.paused && Math.abs(pc.position - 11.1) < 1e-9, pc);
pc = S.partClock(clk(30), { start: 0, dur: 0, file: "whole" }, 50000);
ok("partClock: a whole file (start 0, dur 0) = the browser clock", pc.position === 30 && pc.duration === 6377.9 && !pc.paused, pc);
ok("partClock: no clock -> invalid", S.partClock({ valid: false }, P[0], 0).valid === false);
ok("pickPart: the part covering the position", S.pickPart(P, 3000, -1) === 0);
ok("pickPart: the measured start offset counts (2997 is in part 1, before the asked 3000)", S.pickPart(P, 2997, -1) === 0);
ok("pickPart: in the overlap the current part stays", S.pickPart(P, 3055, 0) === 0);
ok("pickPart: SWAP s before its end the next part takes over", S.pickPart(P, 3000 - 3.737 + 63.86 - S.SWAP + 0.01, 0) === 1);
ok("pickPart: no current -> the covering part that reaches furthest", S.pickPart(P, 3055, -1) === 1);
ok("pickPart: a gap (nothing covers) -> -1 (the cover shows)", S.pickPart(P, 4000, -1) === -1 && S.pickPart(P, 100, -1) === -1);
ok("pickPart: nothing to take over -> keep the current one to its end", S.pickPart([P[0]], 3059.8, 0) === 0);
ok("pickPart: a seek far away drops the current part", S.pickPart(P, 5010, 1) === 2);
ok("pickPart: a whole file covers everything", S.pickPart([{ start: 0, dur: 0, file: "w" }], 9999, -1) === 0);
ok("nextPart: the overlapping follower is preloaded", S.nextPart(P, 0) === 1);
ok("nextPart: none after the last / not contiguous", S.nextPart(P, 1) === -1 && S.nextPart(P, 2) === -1);
ok("nextPart: a whole file has none", S.nextPart([{ start: 0, dur: 0, file: "w" }], 0) === -1);
// a simulated hand-over: play from 3000 to 3100 with a 0.25 s step, as the mirror would decide every tick
let cur = -1, swaps = 0, gap = false;
for (let t = 3000; t <= 3100; t += 0.25) {
    const n = S.pickPart(P, t, cur);
    if (n < 0) gap = true;
    if (n !== cur) { if (cur >= 0) swaps++; cur = n; }
}
ok("simulated 100 s across a boundary: one swap, never without a part", swaps === 1 && !gap && cur === 1, { swaps, gap, cur });
console.log("----\n" + pass + " passed, " + fail + " failed");
process.exit(fail ? 1 : 0);
