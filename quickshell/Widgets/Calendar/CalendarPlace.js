.pragma library
/*  CalendarPlace.js — where the quick-add panel goes (pure JS, checked by tests/widgets-layout.test.js).
 *    place(rect, W, H, w, h, gui, margin) → {x, y}    rect = the card {x, y, w, h, shown} or null; W×H the output; w×h the panel
 *  Centred over the card, then kept on the screen, on the GUI pixel grid; no card on the screen (hidden, or no room for it) = the
 *  middle of the screen.
 */
function place(rect, W, H, w, h, gui, margin) {
    const snap = v => Math.round(v / gui) * gui;
    if (!rect || !rect.shown) return { x: snap((W - w) / 2), y: snap((H - h) / 2) };
    const x = rect.x + (rect.w - w) / 2;
    const y = rect.y + (rect.h - h) / 2;
    const maxX = W - w - margin, maxY = H - h - margin;
    return { x: snap(Math.max(margin, Math.min(maxX, x))), y: snap(Math.max(margin, Math.min(maxY, y))) };
}
