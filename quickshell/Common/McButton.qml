import QtQuick
import qs.Common

/*  McButton — the real widget/button sprites; hover swaps to button_highlighted instantly, disabled to button_disabled.
 *  The game has no pressed sprite: click feedback is the highlight plus the ui.click sound.
 *    text: string          centred white label with shadow, elided (#A0A0A0 when disabled)
 *    labelColor: color     override the label colour
 *    wide, small: bool     200 or 98 GUI px wide; default 150. Height always 20 GUI px. width: overrides.
 *    fit: bool             width follows the label + padding
 *    icon: string          item name drawn left of the label (16 GUI px)
 *    glyph: string         Nerd Font glyph drawn left of the label (Monocraft)
 *    flat: bool            no sprite unless hovered/focused (toolbars)
 *    highlighted: bool     force the highlight (keyboard-driven lists, previews)
 *    focusRing: bool       force the focus ring (previews); shown automatically on keyboard focus
 *    soundId: string       default "ui.click"; "" for silence
 *    tooltip, tooltipDescription, tooltipCategory: string   hover tooltip
 *    readonly hovered, pressed;  signal clicked()
 *  Keyboard: focusable with Tab; Enter/Return/Space activate.
 *
 *    McButton { text: "Back to Game"; wide: true; onClicked: screen.close() }
 */
Item {
    id: root
    property string text: ""
    property color labelColor: enabled ? Theme.buttonText : Theme.buttonTextDisabled
    property bool wide: false
    property bool small: false
    property bool fit: false
    property string icon: ""
    property string glyph: ""
    property bool flat: false
    property bool highlighted: false
    property bool focusRing: false
    property string soundId: "ui.click"
    property string tooltip: ""
    property string tooltipDescription: ""
    property string tooltipCategory: ""
    property int horizontalPadding: Theme.px(8)
    readonly property alias hovered: area.containsMouse
    readonly property bool pressed: area.pressed || keyDown
    property bool keyDown: false
    readonly property bool lit: enabled && (hovered || pressed || highlighted || activeFocus)
    default property alias extraContent: extra.data
    signal clicked()

    implicitWidth: fit ? content.implicitWidth + horizontalPadding * 2 : Theme.px(wide ? 200 : small ? 98 : 150)
    implicitHeight: Theme.px(20)
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: text.length ? text : tooltip
    Accessible.onPressAction: root.activate()

    function activate() {
        if (!enabled) return;
        if (soundId.length) Theme.playSound(soundId);
        root.clicked();
    }

    McNineSlice {
        anchors.fill: parent
        visible: !root.flat || root.lit
        sprite: !root.enabled ? "widget/button_disabled" : root.lit ? "widget/button_highlighted" : "widget/button"
    }
    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.px(3)
        McItemIcon {
            visible: root.icon.length > 0
            name: root.icon
            anchors.verticalCenter: parent.verticalCenter
        }
        McText {
            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            mono: true
            color: root.labelColor
        }
        McText {
            visible: root.text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.labelColor
            elide: Text.ElideRight
            width: root.fit ? implicitWidth : Math.min(implicitWidth, root.width - root.horizontalPadding - (root.icon.length ? Theme.px(19) : root.glyph.length ? Theme.px(12) : 0))
        }
    }
    Item { id: extra; anchors.fill: parent }

    Rectangle {   // keyboard focus ring: 1 GUI px outside the button, the game has none but a desktop shell needs one
        anchors.fill: parent
        anchors.margins: -Theme.gui
        color: "transparent"
        border.width: Theme.gui
        border.color: Theme.focusRing
        visible: root.activeFocus || root.focusRing
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onClicked: root.activate()
    }
    Keys.onPressed: event => {
        if (!root.enabled) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.keyDown = true; event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (root.keyDown && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            root.keyDown = false; event.accepted = true; root.activate();
        }
    }

    Loader {
        active: root.tooltip.length > 0 && area.containsMouse
        sourceComponent: McTooltip {
            title: root.tooltip
            description: root.tooltipDescription
            category: root.tooltipCategory
            target: root
            targetX: area.mouseX
            targetY: area.mouseY
        }
    }
}
