import QtQuick
import qs.Common

/*  McSplash — the title screen's yellow splash: rotated −20°, its scale pulsing twice a second with the game's formula
 *  (1.8 − |sin(2πt)| · 0.1) · 100 / (textWidth + 32), so long splashes are drawn smaller.
 *    text: string
 *    units: real          base size multiplier on top of the formula; default 1
 *    running: bool        default true; reducedMotion freezes it
 *  It occupies no layout space: place its centre where the splash goes.
 *
 *    McSplash { text: "Also try Terraria!"; x: Theme.px(320); y: Theme.px(60) }
 */
Item {
    id: root
    property string text: ""
    property real units: 1
    property bool running: true
    property real phase: 0

    NumberAnimation on phase {
        from: 0; to: 1
        duration: 1000
        loops: Animation.Infinite
        running: root.running && root.visible && !Theme.reducedMotion
    }

    readonly property real _pulse: 1.8 - Math.abs(Math.sin(phase * 2 * Math.PI)) * 0.1
    readonly property real _textGui: label.implicitWidth / Theme.gui

    McText {
        id: label
        x: -implicitWidth / 2
        y: -implicitHeight / 2
        rotation: -20
        transformOrigin: Item.Center
        scale: root._pulse * 100 / (root._textGui + 32) * root.units
        text: root.text
        color: Theme.splash
        // The whole label is scaled and rotated as one nearest-sampled texture, like the game's quad.
        layer.enabled: true
        layer.smooth: false
        layer.textureSize: Qt.size(implicitWidth + Theme.gui, implicitHeight + Theme.gui)
    }
}
