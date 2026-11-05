import QtQuick
import qs.Common

/*  McSlider — the Options slider: widget/slider track, widget/slider_handle, centred label "Name: value" written on it.
 *    label: string          "Master Volume"
 *    value, from, to, stepSize: real    default 0..1, step 0 = continuous
 *    valueText: string      what follows the colon; default percent of the range
 *    codes: string          §-coded override of the printed text (McText codes), e.g. a red value
 *    text: string           full override of the printed text (e.g. the brightness "Moody"/"Bright" labels)
 *    live: bool             moved() fires during the drag; default true. false fires only on release
 *    highlighted: bool      force the highlighted handle (previews)
 *    focusLook: bool        force the focused track (previews); shown automatically on keyboard focus
 *    soundId: string        played on release; default "ui.click"
 *    signals moved(real value), released(real value)
 *  Keyboard: Left/Right step (1 % of the range without stepSize). Mouse wheel too.
 *
 *    McSlider { label: "Master Volume"; value: vol; onMoved: v => setVolume(v) }
 */
Item {
    id: root
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property string valueText: Math.round(position * 100) + "%"
    property string text: label.length ? label + ": " + valueText : valueText
    property string codes: ""          // optional §-coded label (e.g. "Master Volume: §c120%"); overrides text when set
    property bool live: true
    property bool highlighted: false
    property bool focusLook: false
    property string soundId: "ui.click"
    readonly property alias hovered: area.containsMouse
    readonly property alias pressed: area.pressed
    readonly property real position: to === from ? 0 : Math.min(1, Math.max(0, (value - from) / (to - from)))
    signal moved(real value)
    signal released(real value)

    implicitWidth: Theme.px(150)
    implicitHeight: Theme.px(20)
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Slider
    Accessible.name: text

    function _snap(v) {
        if (stepSize > 0) v = from + Math.round((v - from) / stepSize) * stepSize;
        return Math.min(to, Math.max(from, v));
    }
    function _setFromX(mx) {
        const handle = Theme.px(8);
        const p = Math.min(1, Math.max(0, (mx - handle / 2) / Math.max(1, width - handle)));
        const v = _snap(from + p * (to - from));
        if (v !== value) {
            value = v;
            if (live) moved(v);
        }
    }
    function _nudge(dir) {
        const step = stepSize > 0 ? stepSize : (to - from) / 100;
        const v = _snap(value + dir * step);
        if (v !== value) { value = v; moved(v); released(v); }
    }

    McNineSlice {
        anchors.fill: parent
        sprite: root.activeFocus || root.focusLook ? "widget/slider_highlighted" : "widget/slider"
    }
    McNineSlice {
        x: Math.round(root.position * (root.width - width) / Theme.gui) * Theme.gui
        width: Theme.px(8)
        height: root.height
        sprite: area.containsMouse || area.pressed || root.activeFocus || root.highlighted ? "widget/slider_handle_highlighted" : "widget/slider_handle"
    }
    McText {
        anchors.centerIn: parent
        visible: root.codes.length === 0
        width: Math.min(implicitWidth, root.width - Theme.px(4))
        text: root.text
        color: root.enabled ? Theme.buttonText : Theme.buttonTextDisabled
        elide: Text.ElideRight
    }
    McText {   // §-coded variant; the slider track is dark in both modes, so colours are literal
        anchors.centerIn: parent
        visible: root.codes.length > 0
        width: Math.min(implicitWidth, root.width - Theme.px(4))
        codes: root.codes
        darkGround: true
        color: root.enabled ? Theme.buttonText : Theme.buttonTextDisabled
        elide: Text.ElideRight
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        preventStealing: true
        onPressed: mouse => root._setFromX(mouse.x)
        onPositionChanged: mouse => { if (pressed) root._setFromX(mouse.x); }
        onReleased: {
            if (root.soundId.length) Theme.playSound(root.soundId);
            if (!root.live) root.moved(root.value);
            root.released(root.value);
        }
        onWheel: wheel => root._nudge(wheel.angleDelta.y > 0 ? 1 : -1)
    }
    Keys.onLeftPressed: _nudge(-1)
    Keys.onRightPressed: _nudge(1)
}
