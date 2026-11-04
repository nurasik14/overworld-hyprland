import QtQuick
import qs.Common

/*  ArmorRow — armor points, real hud/armor_* sprites, filling from the left.
 *    value: real        icons, 0..max with halves
 *
 *    ArmorRow { value: (1 - cpuLoad) * 10 }
 */
McStatRow {
    emptySprite: "hud/armor_empty"
    halfSprite: "hud/armor_half"
    fullSprite: "hud/armor_full"
}
