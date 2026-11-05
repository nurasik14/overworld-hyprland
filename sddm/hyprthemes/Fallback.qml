// Shown only when no look loads (a broken copy, a missing Qt module): plain, no assets, so a bad look can never lock you out.
import QtQuick

FocusScope {
    id: form

    function userName() {
        if (typeof userModel !== "undefined" && userModel.count > 0) {
            const i = userModel.lastIndex >= 0 ? userModel.lastIndex : 0;
            return userModel.data(userModel.index(i, 0), 257);
        }
        return "";
    }
    property string message: "No login theme could be loaded"
    Component.onCompleted: passwordInput.forceActiveFocus()

    Connections {
        target: sddm
        function onLoginFailed() { form.message = "Login failed"; passwordInput.text = ""; passwordInput.forceActiveFocus(); }
        function onInformationMessage(msg) { form.message = msg; }
    }

    Column {
        anchors.centerIn: parent
        spacing: 12
        width: 360
        Text { text: form.message; color: "white"; font.pixelSize: 16 }
        Rectangle {
            width: parent.width; height: 36; color: "#202020"; border.width: 1; border.color: "#808080"
            TextInput {
                id: userInput
                anchors.fill: parent; anchors.margins: 8
                verticalAlignment: TextInput.AlignVCenter
                color: "white"; font.pixelSize: 15
                text: form.userName()
                KeyNavigation.tab: passwordInput
            }
        }
        Rectangle {
            width: parent.width; height: 36; color: "#202020"; border.width: 1; border.color: "#808080"
            TextInput {
                id: passwordInput
                anchors.fill: parent; anchors.margins: 8
                verticalAlignment: TextInput.AlignVCenter
                color: "white"; font.pixelSize: 15
                echoMode: TextInput.Password
                KeyNavigation.tab: userInput
                onAccepted: sddm.login(userInput.text, text, (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0)
            }
        }
        Text { text: "Enter logs in"; color: "#a0a0a0"; font.pixelSize: 12 }
    }
}
