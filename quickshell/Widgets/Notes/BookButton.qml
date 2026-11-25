import QtQuick
import qs.Common

/*  BookButton — the game's button (widget/button, _highlighted on hover, _disabled) at a free integer scale: McButton is tied to the GUI scale, but the
 *  editor draws its book one step bigger, so its buttons and labels have to follow.  Same look as McButton: white label with shadow, #A0A0A0 disabled.
 *    text: string     label
 *    u: int           screen px per GUI pixel (the sprite's border and the font follow)
 *    soundId: string  default "ui.click"
 *  signal clicked()
 */
Item {
    id: btn
    property string text: ""
    property int u: Theme.gui
    property string soundId: "ui.click"
    property string tooltip: ""
    property string tooltipDescription: ""
    readonly property alias hovered: area.containsMouse
    readonly property color labelColor: enabled ? Theme.buttonText : Theme.buttonTextDisabled
    readonly property bool lit: enabled && (hovered || activeFocus)
    signal clicked()
    implicitWidth: 98 * u
    implicitHeight: 20 * u
    activeFocusOnTab: false
    Accessible.role: Accessible.Button
    Accessible.name: text.length ? text : tooltip
    function activate() {
        if (!enabled) return;
        if (soundId.length) Theme.playSound(soundId);
        btn.clicked();
    }
    McNineSlice {
        anchors.fill: parent
        scaleFactor: btn.u
        sprite: !btn.enabled ? "widget/button_disabled" : btn.lit ? "widget/button_highlighted" : "widget/button"
    }
    Item {   // label with the game's hard shadow, one texel at this scale
        anchors.centerIn: parent
        width: parent.width - btn.u * 4
        height: btn.u * 8
        Repeater {
            model: [1, 0]
            Text {
                required property int modelData
                anchors.fill: parent
                anchors.leftMargin: modelData * btn.u; anchors.topMargin: modelData * btn.u
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: btn.text
                elide: Text.ElideRight
                color: modelData ? Theme.shadowOf(btn.labelColor) : btn.labelColor
                font.family: Theme.fontUi
                font.pixelSize: 8 * btn.u
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.NativeRendering
                antialiasing: false
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.activate()
    }
    Loader {
        active: btn.tooltip.length > 0 && area.containsMouse
        sourceComponent: McTooltip {
            title: btn.tooltip
            description: btn.tooltipDescription
            target: btn
            targetX: area.mouseX
            targetY: area.mouseY
        }
    }
}
