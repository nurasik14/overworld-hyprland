import QtQuick
import qs.Common

/*  McStatRow — the generic HUD stat row behind HeartsRow, HungerRow, ArmorRow, AirRow: `max` icons, 8 GUI px apart, half values.
 *    value: real            icons filled (7.5 = seven full + one half)
 *    max: int               icons in the row; default 10
 *    reverse: bool          fill from the right (hunger, air)
 *    emptySprite, halfSprite, fullSprite: string   overlays are drawn on the empty sprite
 *    spriteFor: var         optional function(index, kind) -> sprite, where kind = "empty"|"half"|"full"
 *    jiggle: bool           every icon hops at random each tick, like hearts at low health
 *    shake: bool            all icons jitter ±1 now and then, like hunger with no saturation
 *    wave: bool             a raised icon travels along the row, like regeneration
 *    lifted: int            raises an icon by 2 GUI px (index, -1 = none). wave drives it
 *  Icons never move while Theme.reducedMotion is true.
 *
 *    McStatRow { value: 7.5; emptySprite: "hud/armor_empty"; halfSprite: "hud/armor_half"; fullSprite: "hud/armor_full" }
 */
Item {
    id: root
    property real value: 0
    property int max: 10
    property bool reverse: false
    property string emptySprite: ""
    property string halfSprite: ""
    property string fullSprite: ""
    property var spriteFor: null
    property bool jiggle: false
    property bool shake: false
    property bool wave: false
    property int lifted: -1

    implicitWidth: Theme.px(8 * Math.max(max, 0) + 1)
    implicitHeight: Theme.px(9)

    readonly property bool _moving: !Theme.reducedMotion && (jiggle || shake || wave)
    McTicker { id: clock; active: root._moving && root.visible }

    // The game draws a seeded random per tick. A small integer hash keeps it stable within one tick.
    function _rand(tick, i) {
        let h = (tick * 312871 + i * 7919) | 0;
        h = (h ^ (h >>> 13)) * 1274126177 | 0;
        return (h ^ (h >>> 16)) >>> 0;
    }
    function _offset(i, tick) {
        if (Theme.reducedMotion) return 0;
        let dy = 0;
        if (jiggle) dy += _rand(tick, i) % 2;
        if (shake && tick % 12 === 0) dy += (_rand(tick, i) % 3) - 1;
        if (wave && tick % (max * 2 + 5) === i * 2) dy -= 2;
        if (lifted === i) dy -= 2;
        return dy;
    }
    function _kind(slot) {
        if (value >= slot + 1) return "full";
        if (value >= slot + 0.5) return "half";
        return "empty";
    }

    Repeater {
        model: root.max
        Item {
            id: cell
            required property int index
            readonly property int slot: root.reverse ? root.max - 1 - index : index   // draw position → fill order
            readonly property string kind: root._kind(index)
            x: Theme.px(8 * cell.slot)
            y: Theme.px(root._offset(index, clock.tick))
            width: Theme.px(9)
            height: Theme.px(9)
            McSprite {
                sprite: root.spriteFor ? root.spriteFor(cell.index, "empty") : root.emptySprite
            }
            McSprite {
                visible: cell.kind !== "empty"
                sprite: !visible ? ""
                      : root.spriteFor ? root.spriteFor(cell.index, cell.kind)
                      : (cell.kind === "full" ? root.fullSprite : root.halfSprite)
            }
        }
    }
}
