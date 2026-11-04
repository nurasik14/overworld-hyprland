import QtQuick
import qs.Common

/*  HungerRow — memory as drumsticks, real hud/food_* sprites, filling from the right like the game.
 *    value: real        drumsticks, 0..max with halves
 *    hunger: bool       the green Hunger-effect sprites
 *    shake: bool        the occasional jitter of an empty stomach
 *
 *    HungerRow { value: freeRamRatio * 10; shake: swapHeavy }
 */
McStatRow {
    id: root
    property bool hunger: false
    reverse: true
    spriteFor: (index, kind) => "hud/food_" + kind + (hunger ? "_hunger" : "")
}
