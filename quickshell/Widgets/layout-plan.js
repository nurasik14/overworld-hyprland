.pragma library
/*  layout-plan.js — default slots for the desktop cards (pure JS, no QML: `node tests/widgets-layout.test.js` checks it).
 *    plan(W, H, gui, sizes)   W×H screen px, gui = GUI scale, sizes = [{w, h}] in GUI px, in reading order
 *    → [{x, y, fits}] in screen px, one per card
 *  Normal case (GUI scale 1–2 at 1080p): two stacks, even cards left, odd cards right, exactly like the original layout.
 *  When a stack would run into the HUD (the chips along the bottom edge), the cards are re-dealt over up to three columns
 *  (left edge, right edge, centre) by trying every assignment: the most cards win, ties prefer the original left/right split, so the
 *  last cards (Sign, Note block…) are the ones left out when a screen is simply too small (`fits: false`; the card stays
 *  switched on, it just has no slot — the layer hides it until it is dragged somewhere, see WidgetCard.fits).
 *  Limits: side columns end 22 GUI px above the bottom edge (HUD flanks), the centre column 62 GUI px (hotbar, hearts and
 *  the item name sit there).
 */
function plan(W, H, gui, sizes) {
    const n = sizes.length;
    const edge = 12 * gui, gap = 6 * gui, first = 8 * gui;
    const cw = Math.max.apply(null, sizes.map(s => s.w)) * gui;
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
