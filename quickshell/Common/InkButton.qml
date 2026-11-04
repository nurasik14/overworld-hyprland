import QtQuick
import qs.Common as Common

/*  DEPRECATED: use McButton.  Legacy API on top of it:
 *    text, icon (Nerd Font glyph), primary (yellow label), accentFill (green label), quiet (flat), large, checked, tooltip,
 *    horizontalPadding, hovered, pressed, keyDown, focusRingVisible, filled, clicked()
 */
Item {
    id: root
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool accentFill: false
    property bool quiet: false
    property bool large: false
    property bool checked: false
    property string tooltip: ""
    property int horizontalPadding: Common.Theme.space.md
    property bool focusRingVisible: false
    readonly property bool filled: primary || accentFill
    readonly property bool hovered: button.hovered
    readonly property bool pressed: button.pressed
    readonly property alias keyDown: button.keyDown
    signal clicked()

    implicitHeight: Common.Theme.px(large ? 24 : 20)
    implicitWidth: Math.max(implicitHeight, button.implicitWidth)
    activeFocusOnTab: enabled
    onActiveFocusChanged: if (activeFocus) button.forceActiveFocus()

    Common.McButton {
        id: button
        anchors.fill: parent
        text: root.text
        glyph: root.icon
        fit: true
        flat: root.quiet
        highlighted: root.checked
        focusRing: root.focusRingVisible
        tooltip: root.tooltip
        horizontalPadding: root.horizontalPadding
        labelColor: !root.enabled ? Common.Theme.buttonTextDisabled
                  : root.primary ? Common.Theme.chat.e
                  : root.accentFill ? Common.Theme.chat.a : Common.Theme.buttonText
        onClicked: root.clicked()
    }
}
