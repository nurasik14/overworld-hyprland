import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  NoteToast — one notification in the real toast/* frames. McToast's own animation and geometry, grown for what a desktop note
 *  needs: markup and links in the body, action buttons, a dismiss cross on hover, a timeout line.
 *    note: NotificationService wrapper
 *    normal  = dark advancement frame, yellow title (summary), white body
 *    critical = same frame, purple "Challenge Complete!", summary in white, body grey; plays ui.toast.challenge; stays until dismissed
 *    low     = the light recipe frame, dark text
 *  Slides in from the right over Theme.toastSlide and out when the service marks it `closing`.
 */
Item {
    id: root
    property var note: null
    property int maxWidth: 240
    signal closeClicked()

    readonly property bool critical: note ? note.critical : false
    readonly property bool low: note ? note.low : false
    readonly property string appIcon: note ? note.appIcon : ""
    readonly property url iconUrl: {
        if (note && note.image.length) return note.image.indexOf("file://") === 0 || note.image.indexOf("image://") === 0 ? note.image : "file://" + note.image;
        if (appIcon.length) return appIcon.indexOf("/") === 0 ? "file://" + appIcon : Quickshell.iconPath(appIcon, true);
        return "";
    }
    readonly property string titleText: critical ? "Challenge Complete!" : (note ? (note.summary.length ? note.summary : note.appName) : "")
    readonly property string subText: critical && note ? (note.summary.length ? note.summary : note.appName) : ""
    readonly property int textX: Theme.px(30)
    readonly property int textW: width - textX - Theme.px(8)

    implicitWidth: Theme.px(maxWidth)
    implicitHeight: Theme.px(8) + col.height + Theme.px(6)
    Accessible.role: Accessible.Notification
    Accessible.name: note ? (note.appName + ": " + note.summary) : ""

    property real _timeLeft: 1
    NumberAnimation {
        target: root; property: "_timeLeft"; from: 1; to: 0
        duration: root.note ? Math.max(1, root.note.timeout) : 1
        running: root.note ? (root.note.popup && root.note.timeout > 0 && !root.note.hovered) : false
    }
    property real _slide: 1
    Component.onCompleted: {
        slideIn.start();
        Theme.playSound(critical ? "ui.toast.challenge" : "ui.toast.in");
    }
    NumberAnimation { id: slideIn; target: root; property: "_slide"; to: 0; duration: Theme.toastSlide; easing.type: Theme.easeToast }
    NumberAnimation { id: slideOut; target: root; property: "_slide"; to: 1; duration: Theme.toastSlide; easing.type: Easing.OutQuad }
    Connections {
        target: root.note
        function onClosingChanged() {
            if (root.note.closing) { slideIn.stop(); slideOut.start(); Theme.playSound("ui.toast.out"); }
        }
    }

    HoverHandler { id: hover; onHoveredChanged: if (root.note) root.note.hovered = hovered }

    Item {
        id: frame
        width: root.width
        height: root.height
        x: Math.round(root._slide * root.width / Theme.gui) * Theme.gui

        McNineSlice {
            anchors.fill: parent
            sprite: root.low ? "toast/recipe" : "toast/advancement"
            scaling: ({ type: "nine_slice", width: 160, height: 32, border: 4 })
        }
        MouseArea {   // body click: default action, else dismiss
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationService.invokeDefault(root.note)
        }
        McItemIcon {
            x: Theme.px(8); y: Theme.px(8)
            source: root.iconUrl
            name: root.iconUrl.toString().length ? "" : Theme.itemFor((root.note ? root.note.appName : "") || "", root.note ? root.note.summary : "")
        }
        Column {
            id: col
            x: root.textX
            y: Theme.px(6)
            width: root.textW
            spacing: 0
            McText {
                width: parent.width - (hover.hovered ? Theme.px(14) : 0)
                text: root.titleText
                color: root.low ? Theme.toastLightTitle : root.critical ? Theme.toastChallenge : Theme.toastTitle
                shadow: !root.low
                elide: Text.ElideRight
            }
            McText {
                visible: root.subText.length > 0
                width: parent.width
                text: root.subText
                color: Theme.toastText
                elide: Text.ElideRight
            }
            McText {
                visible: text.length > 0
                width: parent.width
                text: root.note ? root.note.body : ""
                textFormat: Text.StyledText
                color: root.low ? Theme.toastLightText : root.critical ? Theme.tooltipDesc : Theme.toastText
                shadow: !root.low
                linkColor: Theme.chat["b"]
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                onLinkActivated: link => ShellState.run(["xdg-open", link])
            }
            Flow {
                visible: root.note && root.note.actions && root.note.actions.length > 0
                width: parent.width
                topPadding: Theme.px(2)
                spacing: Theme.px(2)
                Repeater {
                    model: root.note ? root.note.actions : []
                    McButton {
                        required property var modelData
                        fit: true
                        height: Theme.px(14)
                        horizontalPadding: Theme.px(4)
                        text: modelData.text || modelData.identifier
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
        McSprite {   // dismiss cross, on hover
            visible: hover.hovered
            anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Theme.px(4)
            sprite: crossArea.containsMouse ? "widget/cross_button_highlighted" : "widget/cross_button"
            MouseArea {
                id: crossArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.closeClicked()
            }
        }
        Rectangle {   // what is left of the timeout, one GUI pixel high, starts over when the pointer leaves (so does the service's timer)
            visible: root.note && root.note.timeout > 0 && !root.note.closing
            x: Theme.px(4)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.px(3)
            height: Theme.gui
            width: Math.round(root._timeLeft * (frame.width - Theme.px(8)) / Theme.gui) * Theme.gui
            color: root.low ? Theme.toastLightTitle : Theme.xp
        }
    }
}
