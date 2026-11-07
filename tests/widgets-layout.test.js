// node tests/widgets-layout.test.js — checks quickshell/Widgets/layout-plan.js (strips the QML-only `.pragma` line)
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "../quickshell/Widgets/layout-plan.js"), "utf8").replace(/^\.pragma.*$/m, "");
const plan = new Function(src + "; return plan;")();
// reading order of WidgetLayout.qml: weather, calendar, music, sysinfo, brew, cava, block, quote, projects, notes  (GUI px); the first 8 form the stacks
const sizes = [150, 156, 106, 148, 84, 82, 138, 78, 150, 130].map(h => ({ w: 190, h }));
const N = sizes.length, BASE = 8;
let bad = 0;
function check(W, H, gui) {
    const t0 = Date.now(), p = plan(W, H, gui, sizes, BASE), ms = Date.now() - t0;
    const rects = p.map((s, i) => ({ ...s, w: 190 * gui, h: sizes[i].h * gui, i })).filter(r => r.fits);
    let ok = true, why = [];
    for (const r of rects) {
        if (r.x < 0 || r.x + r.w > W || r.y < 0) { ok = false; why.push(`card ${r.i} off screen`); }
        const limit = (r.x > 0.3 * W && r.x + r.w < 0.7 * W) ? H - 62 * gui : H - 22 * gui;
        // the overflow card never sits under the boss bars (top centre, 37 GUI px high, ±91 GUI px wide)
        if (r.i >= BASE && r.x < W / 2 + 91 * gui && r.x + r.w > W / 2 - 91 * gui && r.y < 40 * gui) { ok = false; why.push(`card ${r.i} under the boss bars`); }
        if (r.y + r.h > limit) { ok = false; why.push(`card ${r.i} bottom ${r.y + r.h} > ${limit}`); }
        for (const o of rects) if (o.i < r.i && r.x < o.x + o.w && o.x < r.x + r.w && r.y < o.y + o.h && o.y < r.y + r.h) { ok = false; why.push(`cards ${o.i}/${r.i} overlap`); }
    }
    const hidden = p.map((s, i) => s.fits ? null : i).filter(i => i !== null);
    console.log(`${ok ? "ok  " : "FAIL"} ${W}x${H} gui ${gui}: ${rects.length}/${N} placed, hidden [${hidden}] ${ms} ms ${why.join("; ")}`);
    if (!ok) bad++;
    return p;
}
const a = check(1920, 1080, 1), b = check(1920, 1080, 2), c = check(1920, 1080, 3);
check(1920, 1080, 4); check(2560, 1440, 3); check(1366, 768, 2); check(3840, 2160, 3);
// scale 1 and 2 keep the original two stacks and place the Projects card too, in the column next to the right stack
for (const p of [a, b]) if (!p[8].fits || p[8].x > p[1].x - 190 * (p === a ? 1 : 2)) { console.log("FAIL projects card not placed next to the right stack"); bad++; }
// Notes goes below Projects in the same overflow column, clear of the HUD
for (const p of [a, b]) if (!p[9].fits || p[9].x !== p[8].x || p[9].y <= p[8].y) { console.log("FAIL notes card not placed below the projects card"); bad++; }
const g2 = 2;
if (b[9].y + 130 * g2 > 1080 - 62 * g2) { console.log("FAIL notes card runs into the HUD at GUI 2"); bad++; }
const nine = plan(1920, 1080, 2, sizes.slice(0, 9), BASE);
if (JSON.stringify(nine) !== JSON.stringify(b.slice(0, 9))) { console.log("FAIL the first 9 slots changed when the Notes card was added"); bad++; }
const only8 = plan(1920, 1080, 2, sizes.slice(0, 8));
if (JSON.stringify(only8) !== JSON.stringify(b.slice(0, 8))) { console.log("FAIL the first 8 slots changed when the 9th card was added"); bad++; }
for (const p of [a, b]) if (!p.slice(0, 8).every((s, i) => s.fits && (i % 2 === 0 ? s.x === 12 * (p === a ? 1 : 2) : s.x > 960))) { console.log("FAIL original two-stack layout changed"); bad++; }
if (!c.slice(0, 7).every(s => s.fits)) { console.log("FAIL gui 3 should place at least 7 cards"); bad++; }

// the editor's sheet: over the card's paper, on the screen, on the GUI grid; no card = the middle of the screen
const placeSrc = fs.readFileSync(path.join(__dirname, "../quickshell/Widgets/Notes/NotesPlace.js"), "utf8").replace(/^\.pragma.*$/m, "");
const place = new Function(placeSrc + "; return place;")();
function near(name, got, want) { if (got.x !== want.x || got.y !== want.y) { console.log(`FAIL place ${name}: got ${got.x},${got.y} wanted ${want.x},${want.y}`); bad++; } }
const fw = 432, fh = 374;
const paper = { x: b[9].x + 14, y: b[9].y + 34, w: 344, h: 172, shown: true };
const over = place(paper, 1920, 1080, fw, fh, 2, 12);
if (!(over.x <= paper.x && over.x + fw >= paper.x + paper.w && over.y <= paper.y && over.y + 300 >= paper.y + paper.h)) { console.log("FAIL the editor sheet does not cover the card's paper"); bad++; }
near("centres over the paper", over, { x: paper.x + (paper.w - fw) / 2, y: paper.y - 8 });
near("null rect = screen centre", place(null, 1920, 1080, fw, fh, 2, 12), { x: 744, y: 354 });
near("hidden card = screen centre", place({ ...paper, shown: false }, 1920, 1080, fw, fh, 2, 12), { x: 744, y: 354 });
near("kept on screen, left", place({ x: 0, y: 500, w: 344, h: 172, shown: true }, 1920, 1080, fw, fh, 2, 12), { x: 12, y: 492 });
near("kept on screen, right and bottom", place({ x: 1900, y: 1000, w: 344, h: 172, shown: true }, 1920, 1080, fw, fh, 2, 12), { x: 1476, y: 694 });
near("kept on screen, top", place({ x: 800, y: 0, w: 344, h: 172, shown: true }, 1920, 1080, fw, fh, 2, 12), { x: 756, y: 12 });
const odd = place({ x: 801, y: 301, w: 344, h: 172, shown: true }, 1920, 1080, fw, fh, 3, 12);
if (odd.x % 3 || odd.y % 3) { console.log("FAIL place is not on the GUI grid"); bad++; }
process.exit(bad ? 1 : 0);
