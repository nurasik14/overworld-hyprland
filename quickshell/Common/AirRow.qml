import QtQuick
import qs.Common

/*  AirRow — air bubbles, real hud/air* sprites, filling from the right. Halves show the bursting bubble.
 *    value: real        bubbles, 0..max
 *
 *    AirRow { value: 7.5 }
 */
McStatRow {
    reverse: true
    emptySprite: "hud/air_empty"
    halfSprite: "hud/air_bursting"
    fullSprite: "hud/air"
}
