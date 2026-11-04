import QtQuick
import qs.Common

/*  HeartsRow — battery as hearts, real hud/heart/* sprites.
 *    value: real        hearts, 0..max with halves (7.5); default max 10
 *    style: string      "normal", "poisoned", "withered", "frozen", "absorbing"
 *    hardcore: bool     the eyed hardcore hearts
 *    blinking: bool     the white damage-flash sprites
 *    jiggle: bool       hop at random each tick; defaults to true at or below `lowAt` (2 hearts), like low health
 *    regen: bool        a raised heart travels along the row
 *
 *    HeartsRow { value: battery / 10; regen: charging; hardcore: battery <= 5 }
 */
McStatRow {
    id: root
    property string style: "normal"
    property bool hardcore: false
    property bool blinking: false
    property bool regen: false
    property real lowAt: 2
    jiggle: value <= lowAt
    wave: regen
    spriteFor: (index, kind) => {
        const blink = blinking ? "_blinking" : "";
        const hc = hardcore ? "hardcore_" : "";
        if (kind === "empty") return "hud/heart/container" + (hardcore ? "_hardcore" : "") + blink;
        const prefix = style === "normal" ? "" : style + "_";
        return "hud/heart/" + prefix + hc + kind + blink;
    }
}
