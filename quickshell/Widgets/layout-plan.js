.pragma library
/*  layout-plan.js — default slots for the desktop cards (pure JS, no QML: `node tests/widgets-layout.test.js` checks it).
 *    plan(W, H, gui, sizes, nBase)   W×H screen px, gui = GUI scale, sizes = [{w, h}] in GUI px, in reading order;
 *                                    the first nBase (default all) go in the stacks, the rest in overflow columns (see extras)
 *    → [{x, y, fits}] in screen px, one per card
 *  Normal case (GUI scale 1–2 at 1080p): two stacks, even cards left, odd cards right, exactly like the original layout.
 *  When a stack would run into the HUD (the chips along the bottom edge), the cards are re-dealt over up to three columns
 *  (left edge, right edge, centre) by trying every assignment: the most cards win, ties prefer the original left/right split, so the
 *  last cards (Sign, Note block…) are the ones left out when a screen is simply too small (`fits: false`; the card stays
 *  switched on, it just has no slot — the layer hides it until it is dragged somewhere, see WidgetCard.fits).
 *  Limits: side columns end 22 GUI px above the bottom edge (HUD flanks), the centre column 62 GUI px (hotbar, hearts and
 *  the item name sit there).
 */
function plan(W, H, gui, allSizes, nBase) {
    const n = nBase === undefined ? allSizes.length : Math.min(nBase, allSizes.length);
    const sizes = allSizes.slice(0, n);
    const edge = 12 * gui, gap = 6 * gui, first = 8 * gui;
    const cw = Math.max.apply(null, allSizes.map(s => s.w)) * gui;
    const sideLimit = H - 22 * gui, midLimit = H - 62 * gui;
    const cols = [{ x: edge, limit: sideLimit }, { x: W - edge - cw, limit: sideLimit }];
    if (W >= 3 * cw + 2 * edge + 2 * gap)
        cols.push({ x: Math.round((W - cw) / 2 / gui) * gui, limit: midLimit });

    // assign[i] = column index, or -1 = no room. Returns {pos, fitted, score}.
    function layout(assign) {
        const y = cols.map(() => first), pos = [];
        let fitted = 0, score = 0, natural = 0;
        for (let i = 0; i < n; i++) {
            const c = assign[i];
            if (c < 0) { pos.push({ x: cols[0].x, y: first, fits: false }); continue; }
            const h = sizes[i].h * gui;
            if (y[c] + h > cols[c].limit) return null;
            pos.push({ x: cols[c].x, y: y[c], fits: true });
            y[c] += h + gap;
            fitted++; score += Math.pow(2, n - 1 - i);
            if (c === i % 2) natural++;
        }
        return { pos: pos, fitted: fitted, score: score, natural: natural };
    }

    const basePos = planBase();
    return basePos.concat(extras(basePos));

    function planBase() {
        const original = layout(sizes.map((s, i) => i % 2));
        if (original) return original.pos;

        // brute force: (cols+1)^n assignments, 4^8 = 65536 at most, runs once per size / scale change
        const base = cols.length + 1;
        let best = null;
        const assign = new Array(n).fill(0);
        for (let k = 0, total = Math.pow(base, n); k < total; k++) {
            let r = k;
            for (let i = 0; i < n; i++) { assign[i] = (r % base) - 1; r = Math.floor(r / base); }
            const l = layout(assign);
            if (l && (!best || l.score > best.score || (l.score === best.score && l.natural > best.natural))) best = l;
        }
        return best ? best.pos : sizes.map(() => ({ x: cols[0].x, y: first, fits: false }));
    }

    // Cards past nBase (the Projects card) are not part of the two stacks, which are full: each goes into the first free spot of an
    // overflow column next to the right stack, then next to the left one, scanning down past the cards already there.  The top
    // centre belongs to the boss bars (37 GUI px high, ±131 wide) and the bottom centre to the HUD, so a column under them starts lower
    // / ends higher.  No spot → fits = false, like the base cards.
    function extras(basePos) {
        const placed = [];
        basePos.forEach((p, i) => { if (p.fits) placed.push({ x: p.x, y: p.y, w: cw, h: sizes[i].h * gui }); });
        const inner = [W - edge - 2 * cw - gap, edge + cw + gap];
        const out = [];
        for (let k = n; k < allSizes.length; k++) {
            const h = allSizes[k].h * gui;
            let pos = null;
            for (let c = 0; c < inner.length && !pos; c++) {
                const x = inner[c];
                if (x < 0 || x + cw > W) continue;
                const underBoss = x < W / 2 + 131 * gui && x + cw > W / 2 - 131 * gui;
                const overHud = x < W / 2 + 100 * gui && x + cw > W / 2 - 100 * gui;
                const limit = overHud ? midLimit : sideLimit;
                let y = underBoss ? Math.max(first, 40 * gui) : first;
                for (let guard = 0; guard < 32; guard++) {
                    const hit = placed.find(r => x < r.x + r.w && r.x < x + cw && y < r.y + r.h && r.y < y + h);
                    if (!hit) break;
                    y = hit.y + hit.h + gap;
                }
                if (y + h <= limit && !placed.some(r => x < r.x + r.w && r.x < x + cw && y < r.y + r.h && r.y < y + h)) {
                    pos = { x: x, y: y, fits: true };
                    placed.push({ x: x, y: y, w: cw, h: h });
                }
            }
            out.push(pos || { x: cols[0].x, y: first, fits: false });
        }
        return out;
    }
}
