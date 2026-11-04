import QtQuick
import qs.Common

/*  OptSlider — an Options slider bound to one config.json key. The value is written 250 ms after the last move
 *  (one jq write per gesture, not per pixel).
 *    key: "sound_volume.master"   dflt: default value in the key's own unit   scale: 100 → slider 0..1 maps to 0..100
 *    minimum: smallest slider value (opacity never goes to 0)   offAt0: print "OFF" at 0   suffix: "%"
 */
McSlider {
    id: root
    property string key: ""
    property real dflt: 100
    property real scale: 100
    property real minimum: 0
    property bool offAt0: true
    property string labelText: ""
    value: Math.max(minimum, Number(Options.get(key, dflt)) / scale)
    from: minimum
    stepSize: 0.01
    text: labelText + ": " + (offAt0 && value <= 0 ? "OFF" : Math.round(value * 100) + "%")
    live: true
    soundId: ""
    onMoved: v => { pending.v = v; pending.restart(); }
    Timer {
        id: pending
        property real v: 0
        interval: 250
        onTriggered: Options.set(root.key, Math.round(v * root.scale * 100) / 100)
    }
}
