import QtQuick
import qs.Common

/*  AdvancementsConfirm — the confirm screen of the reset buttons (Advancements: "Reset all advancements?", Statistics: "Reset all
 *  statistics?"). Fills its parent, dims what is below, swallows clicks. Cancel is the default; Esc cancels (the key is accepted, so
 *  the screen below stays open); Left/Right/Tab move the highlight, Enter/Space activate it.
 *    shown: bool          visible + focused
 *    title, detail: string
 *    confirmText: string  label of the red button (default "Reset")
 *    signals confirmed(), cancelled()
 */
FocusScope {
    id: root
    property bool shown: false
    property string title: "Reset all advancements?"
    property string detail: "This cannot be undone."
    property string confirmText: "Reset"
    property int choice: 1            // 0 = the red button, 1 = Cancel
    signal confirmed()
    signal cancelled()

    anchors.fill: parent
    visible: shown
    focus: shown
    onShownChanged: if (shown) { choice = 1; forceActiveFocus(); }

    function accept() { Theme.playSound("ui.click"); root.confirmed(); }
    function cancel() { Theme.playSound("ui.click"); root.cancelled(); }

    Rectangle { anchors.fill: parent; color: "#e0101010" }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: root.cancel() }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true; }
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { root.choice = 1 - root.choice; event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (root.choice === 0) root.accept(); else root.cancel();
            event.accepted = true;
        }
        else event.accepted = true;      // nothing leaks to the screen below while the question is open
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.px(10)
        McText {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            text: root.title
        }
        McText {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#aaaaaa"
            text: root.detail
        }
        Item { width: 1; height: Theme.px(6) }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.px(8)
            McButton {
                text: root.confirmText
                labelColor: "#ff5555"
                highlighted: root.choice === 0
                activeFocusOnTab: false
                soundId: ""
                onHoveredChanged: if (hovered) root.choice = 0
                onClicked: root.accept()
            }
            McButton {
                text: "Cancel"
                highlighted: root.choice === 1
                activeFocusOnTab: false
                soundId: ""
                onHoveredChanged: if (hovered) root.choice = 1
                onClicked: root.cancel()
            }
        }
    }
}
