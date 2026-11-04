import QtQuick
import qs.Common

/*  InkField — a single-line text field on paper (search drawer, password, command).
 *    text · placeholder · password (echo dots + "show" toggle) · icon (Nerd glyph left) · accept() · signal accepted/escaped
 *    frame → accent while focused; error=true → frame seal + 160 ms shake.
 */
FocusScope {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property string icon: ""
    property bool password: false
    property bool revealed: false
    property bool error: false
    property bool arrowsNavigate: false     // Left/Right always go to navigate() (grid launchers)
    property alias input: input
    property int padding: Theme.space.md
    property color fill: Theme.surface
    signal accepted()
    signal escaped()
    signal navigate(int key)

    implicitHeight: Theme.sizes.control_height || 32
    implicitWidth: 240
    activeFocusOnTab: true

    function shake() { shakeAnim.restart(); }
    onErrorChanged: if (error) shake()

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radius.sm
        color: root.fill
        border.width: root.activeFocus ? 2 : Theme.border.hairline
        border.color: root.error ? Theme.seal : (root.activeFocus ? Theme.accent : Theme.hairline)
        Behavior on color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: frame; property: "x"; from: 0; to: -4; duration: 40 }
        NumberAnimation { target: frame; property: "x"; to: 4; duration: 40 }
        NumberAnimation { target: frame; property: "x"; to: -2; duration: 40 }
        NumberAnimation { target: frame; property: "x"; to: 0; duration: 40 }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        spacing: Theme.space.sm
        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.activeFocus ? Theme.accent : Theme.textMuted
            font.family: Theme.fontMono
            font.pixelSize: 15
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }
        Item {
            width: parent.width - (root.icon.length ? 15 + parent.spacing : 0) - (root.password ? showBtn.width + parent.spacing : 0)
            height: parent.height
            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.selection
                selectedTextColor: Theme.text
                font.family: Theme.fontBody
                font.pixelSize: Theme.fontFor("body").pixelSize
                renderType: Text.NativeRendering
                echoMode: root.password && !root.revealed ? TextInput.Password : TextInput.Normal
                passwordCharacter: "•"
                clip: true
                focus: true
                cursorVisible: root.activeFocus
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { event.accepted = true; root.accepted(); }
                    else if (event.key === Qt.Key_Escape) { event.accepted = true; root.escaped(); }
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_PageUp
                             || event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab
                             || ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && (root.arrowsNavigate || input.text.length === 0))) {
                        event.accepted = true; root.navigate(event.key);
                    }
                }
            }
            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text.length === 0
                text: root.placeholder
                color: Theme.textMuted
                opacity: 0.8
                font.family: Theme.fontBody
                font.pixelSize: Theme.fontFor("body").pixelSize
                renderType: Text.NativeRendering
                elide: Text.ElideRight
            }
        }
        InkButton {
            id: showBtn
            visible: root.password
            quiet: true
            text: root.revealed ? "hide" : "show"
            tooltip: root.revealed ? "Hide password" : "Show password"
            implicitHeight: 24
            horizontalPadding: 6
            activeFocusOnTab: false
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { root.revealed = !root.revealed; input.forceActiveFocus(); }
        }
    }
}
