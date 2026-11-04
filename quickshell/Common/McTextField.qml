import QtQuick
import qs.Common

/*  McTextField — the game's edit box: widget/text_field(_highlighted) sprites, black fill, grey border (white when focused),
 *  light text with shadow, `_` cursor at the end of the text ( `|` inside it) blinking 6 ticks on, 6 off.
 *    text: string              read/write
 *    placeholderText: string   grey hint while empty
 *    echoMode                  TextInput.Normal | Password… password echo uses the game's * character
 *    maxLength, validator, readOnly, inputMethodHints, selectByMouse   as TextInput
 *    highlighted: bool         force the focused look and cursor (previews, or a field driven by keys forwarded from a list)
 *    input                     the inner TextInput (forceActiveFocus(), selectAll()…)
 *    signals accepted(), edited(), escapePressed()
 *    default height 20 GUI px, default width 150 GUI px
 *
 *    McTextField { id: pw; placeholderText: "Password"; echoMode: TextInput.Password; onAccepted: connect(text) }
 */
Item {
    id: root
    property alias text: input.text
    property string placeholderText: ""
    property alias echoMode: input.echoMode
    property alias maxLength: input.maximumLength
    property alias validator: input.validator
    property alias readOnly: input.readOnly
    property alias inputMethodHints: input.inputMethodHints
    property alias selectByMouse: input.selectByMouse
    property alias input: input
    property alias cursorPosition: input.cursorPosition
    property bool highlighted: false
    readonly property bool focused: input.activeFocus || highlighted
    signal accepted()
    signal edited()
    signal escapePressed()

    implicitWidth: Theme.px(150)
    implicitHeight: Theme.px(20)
    activeFocusOnTab: enabled
    onActiveFocusChanged: if (activeFocus) input.forceActiveFocus()
    Accessible.role: Accessible.EditableText
    Accessible.name: placeholderText

    McNineSlice {
        anchors.fill: parent
        sprite: root.focused ? "widget/text_field_highlighted" : "widget/text_field"
    }

    Item {
        id: viewport
        anchors.fill: parent
        anchors.leftMargin: Theme.px(4)
        anchors.rightMargin: Theme.px(4)
        clip: true

        McText {   // a Text under the input carries the shadow; it follows the input's horizontal scroll
            id: shadowText
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Theme.gui
            x: { input.text; input.cursorPosition; input.width; return Theme.gui + input.positionToRectangle(0).x; }
            text: input.displayText
            color: Theme.shadowOf(input.color)
            shadow: false
        }
        McText {
            visible: input.text.length === 0 && input.preeditText.length === 0
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: root.placeholderText
            color: Theme.fieldPlaceholder
            elide: Text.ElideRight
            shadow: false
        }
        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: root.enabled ? Theme.fieldText : Theme.fieldTextDisabled
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontPx(1)
            font.hintingPreference: Font.PreferNoHinting
            renderType: TextInput.NativeRendering
            antialiasing: false
            passwordCharacter: "*"
            passwordMaskDelay: 0
            selectByMouse: true
            selectionColor: Theme.fieldSelection
            selectedTextColor: Theme.hudText
            activeFocusOnTab: false
            cursorDelegate: Item { }
            onAccepted: root.accepted()
            onTextEdited: root.edited()
            Keys.onEscapePressed: event => { root.escapePressed(); event.accepted = false; }
        }
        McTicker {
            id: blink
            active: root.focused && root.visible && !input.readOnly && !Theme.reducedMotion
        }
        // Own cursor: `_` after the last character, a thin bar inside the text.
        readonly property int cursorX: { input.text; input.width; return input.positionToRectangle(input.cursorPosition).x; }
        readonly property bool cursorOn: root.focused && !input.readOnly && (Theme.reducedMotion || (blink.tick % 12) < 6)
        readonly property bool atEnd: input.cursorPosition >= input.length
        McText {
            visible: viewport.cursorOn && viewport.atEnd
            x: viewport.cursorX
            anchors.verticalCenter: parent.verticalCenter
            text: "_"
            color: Theme.fieldText
        }
        Rectangle {
            visible: viewport.cursorOn && !viewport.atEnd
            x: viewport.cursorX
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.gui
            height: Theme.px(10)
            color: Theme.fieldText
        }
    }
}
