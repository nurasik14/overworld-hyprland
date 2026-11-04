import QtQuick
import qs.Common

/*  McCheckbox — the real widget/checkbox sprites (20×20), label to the right.
 *    text: string          label
 *    checked: bool
 *    labelColor: color     default Theme.guiText (use Theme.fieldText / hudText over a world or a dark screen)
 *    highlighted: bool     force the highlighted sprite (previews)
 *    soundId: string       default "ui.click"
 *    signal toggled(bool checked)
 *  Keyboard: Tab to focus, Space/Enter toggle.
 *
 *    McCheckbox { text: "Show particles"; checked: cfg.particles; onToggled: c => cfg.particles = c }
 */
Item {
    id: root
    property string text: ""
    property bool checked: false
    property color labelColor: Theme.guiText
    property bool highlighted: false
    property string soundId: "ui.click"
    readonly property alias hovered: area.containsMouse
    signal toggled(bool checked)

    implicitWidth: box.width + (text.length ? Theme.px(4) + label.implicitWidth : 0)
    implicitHeight: Theme.px(20)
    activeFocusOnTab: enabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked

    function toggle() {
        if (!enabled) return;
        if (soundId.length) Theme.playSound(soundId);
        checked = !checked;
        toggled(checked);
    }

    McSprite {
        id: box
        width: Theme.px(20)
        height: Theme.px(20)
        readonly property bool lit: area.containsMouse || root.activeFocus || root.highlighted
        sprite: "widget/checkbox" + (root.checked ? "_selected" : "") + (lit ? "_highlighted" : "")
    }
    McText {
        id: label
        anchors.left: box.right
        anchors.leftMargin: Theme.px(4)
        anchors.verticalCenter: box.verticalCenter
        text: root.text
        color: root.labelColor
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onClicked: root.toggle()
    }
    Keys.onSpacePressed: toggle()
    Keys.onReturnPressed: toggle()
    Keys.onEnterPressed: toggle()
}
