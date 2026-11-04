import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  CavaCard — the note-block equaliser (190 × 80 GUI px).  24 columns (cava bars, 0–100) built from 6×6 GUI px block
 *  patches, 7 rows high: the lower rows are note blocks, the upper ones lit redstone lamps, unlit cells stay dark.
 *  Each column's peak is a note particle (particle/note, tinted with the game's note colour for that pitch) that holds,
 *  then sinks; the stack falls one row per tick.  Everything steps on the 20 TPS clock.
 *  Idle (≈1.5 s of silence) shows the dark grid and "Silence…"; cava is only running while the layer is visible
 *  (CavaService).  "cava not running" when the binary fails.
 */
WidgetCard {
    id: card
    title: "Note Block"
    guiW: 190
    guiH: 82

    readonly property var svc: CavaService
    readonly property int bars: svc.bars
    readonly property int rows: 7
    readonly property int pitch: 7                          // GUI px between cells (6 + 1 gap)
    property var levels: new Array(bars).fill(0)             // displayed stack height, rows (float)
    property var peaks: new Array(bars).fill(0)
    property var hold: new Array(bars).fill(0)

    McTicker {
        active: card.visible
        onTicked: {
            const lv = card.levels.slice(), pk = card.peaks.slice(), hd = card.hold.slice();
            for (let i = 0; i < card.bars; i++) {
                const target = card.svc.idle ? 0 : Math.min(card.rows, (card.svc.values[i] || 0) / 100 * card.rows * 1.15);
                lv[i] = target >= lv[i] ? target : Math.max(target, lv[i] - 1);                 // rises at once, falls a row a tick
                if (lv[i] >= pk[i]) { pk[i] = lv[i]; hd[i] = 8 }                                // hold 8 ticks …
                else if (hd[i] > 0) hd[i]--;
                else pk[i] = Math.max(lv[i], pk[i] - 0.5);                                      // … then sink half a row per tick
            }
            card.levels = lv; card.peaks = pk; card.hold = hd;
        }
    }
    // the game's note-particle colour for note n of 24 (ParticleNote)
    function noteColor(n) {
        const f = n / 24;
        const c = k => Math.max(0, Math.sin((f + k) * 2 * Math.PI) * 0.65 + 0.35);
        return Qt.rgba(c(0), c(1 / 3), c(2 / 3), 1);
    }

    Item {
        id: grid
        x: Theme.px(4); y: 0
        width: Theme.px(168); height: Theme.px(56)
        Repeater {
            model: card.bars
            delegate: Item {
                id: col
                required property int index
                readonly property int lit: Math.round(card.levels[index] || 0)
                readonly property int peakRow: Math.round(card.peaks[index] || 0)
                x: index * Theme.px(card.pitch)
                width: Theme.px(6); height: grid.height
                Repeater {
                    model: card.rows
                    delegate: Item {
                        id: cellBox
                        required property int index
                        width: Theme.px(6); height: Theme.px(6)
                        y: grid.height - (index + 1) * Theme.px(card.pitch) + Theme.px(1)
                        readonly property bool on: index < col.lit
                        Rectangle { anchors.fill: parent; color: "#000000"; opacity: card.svc.idle ? 0.32 : 0.22; visible: !cellBox.on }
                        BlockPatch {
                            visible: cellBox.on
                            size: 6; u: 5; v: 5
                            texture: index < 4 ? "block/note_block" : "block/redstone_lamp_on"
                            fallback: index < 4 ? "#6B4A2E" : "#FFA64A"
                        }
                    }
                }
                BlockPatch {   // the peak: a note particle, one row above the stack's best
                    visible: !card.svc.idle && col.peakRow > 0
                    size: 8; u: 0; v: 0
                    texture: "particle/note"
                    tint: card.noteColor(col.index)
                    x: -Theme.gui
                    y: grid.height - col.peakRow * Theme.px(card.pitch) - Theme.px(8)
                }
            }
        }
    }
    McText {
        anchors.right: parent.right; anchors.top: parent.top
        visible: card.svc.idle
        color: Theme.textMuted
        text: card.svc.available ? "Silence…" : "cava not running"
    }
}
