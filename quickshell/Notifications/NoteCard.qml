import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services

/*  NoteCard — a folded paper note (DESIGN §6.4).  note = NotificationService NoteWrapper.
 *    compact: true in the notification centre (no timeout line, close always visible, narrower padding)
 *  critical ("imperial order"): seal frame, sealWash ground, 印 stamped over the fold, title in error colour
 *  low: hairline frame, 0.92 opacity · hover: ink wash + ✕ · click body: default action or dismiss
 */
Item {
    id: root
    property var note: null
    property bool compact: false
    readonly property bool critical: note ? note.critical : false
    readonly property bool low: note ? note.low : false
    readonly property bool hovered: hover.hovered
    readonly property string appIcon: note ? note.appIcon : ""
    readonly property string iconSource: appIcon.length ? (appIcon.indexOf("/") === 0 ? "file://" + appIcon : Quickshell.iconPath(appIcon, true)) : ""
    readonly property string imageSource: note && note.image.length ? (note.image.indexOf("file://") === 0 || note.image.indexOf("image://") === 0 ? note.image : "file://" + note.image) : ""
    readonly property int pad: compact ? Theme.space.md : Theme.space.md
    signal closeClicked()

    implicitWidth: 340
    implicitHeight: column.implicitHeight + pad * 2 + (root.compact ? 0 : 2)
    Accessible.role: Accessible.Notification
    Accessible.name: note ? (note.appName + ": " + note.summary) : ""
    opacity: low ? 0.92 : 1

    HoverHandler { id: hover; onHoveredChanged: if (root.note) root.note.hovered = hovered }

    Rectangle {   // note shadow 2 3 6
        anchors.fill: paper
        anchors.leftMargin: 2; anchors.topMargin: 3
        radius: paper.radius
        color: Theme.shadow
        visible: !root.compact
    }
    Rectangle {
        id: paper
        anchors.fill: parent
        radius: Theme.radius.md
        color: Theme.surface
        border.width: root.low ? 1 : Theme.border.frame
        border.color: root.critical ? Theme.seal : (root.low ? Theme.hairline : Theme.frame)
        Behavior on color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Theme.durTheme; easing.type: Easing.OutCubic } }
        Item {   // paper grain
            anchors.fill: parent; anchors.margins: paper.border.width; clip: true
            Image { anchors.fill: parent; source: Theme.texture("ground-tile"); fillMode: Image.Tile; opacity: Theme.textureOpacity * 0.8; smooth: false; asynchronous: true }
        }
        Rectangle {   // imperial order: vermilion wash over the paper
            visible: root.critical
            anchors.fill: parent; anchors.margins: paper.border.width
            radius: paper.radius - 1
            color: Theme.sealWash
        }
        Rectangle {   // hover wash
            anchors.fill: parent; anchors.margins: paper.border.width
            radius: paper.radius - 1
            color: Theme.inkWash
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
    }
    // folded corner (top-right): the paper is "cut" and a surfaceAlt triangle folds over it
    Canvas {
        id: fold
        anchors.right: parent.right; anchors.top: parent.top
        width: 16; height: 16
        readonly property color inkA: Theme.surfaceAlt
        readonly property color inkB: root.critical ? Theme.seal : Theme.frame
        readonly property color ground: Theme.bg0
        onInkAChanged: requestPaint()
        onInkBChanged: requestPaint()
        onGroundChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            // the flap: surfaceAlt triangle folded over the lower-left half, a hairline along the crease
            ctx.fillStyle = inkA;
            ctx.beginPath(); ctx.moveTo(1, 0); ctx.lineTo(1, height - 1); ctx.lineTo(width - 1, height - 1); ctx.closePath(); ctx.fill();
            ctx.strokeStyle = inkB; ctx.lineWidth = 1.5;
            ctx.beginPath(); ctx.moveTo(1, 0); ctx.lineTo(width - 1, height - 1); ctx.stroke();
        }
    }
    Seal {   // 印 stamped over the fold on imperial orders
        visible: root.critical
        anchors.right: parent.right; anchors.top: parent.top
        anchors.rightMargin: 10; anchors.topMargin: 10
        size: 24; glyph: "印"; label: "Imperial order — critical"
        rotation: -8
    }

    Column {
        id: column
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: root.pad
        spacing: Theme.space.sm

        Row {   // seal + title + time
            width: parent.width
            spacing: Theme.space.md
            Item {   // app seal 24: icon inside, else a glyph
                width: 24; height: 24
                anchors.top: parent.top
                Seal {
                    anchors.fill: parent
                    size: 24
                    glyph: root.iconSource.length ? "" : NotificationService.appGlyph(root.note ? root.note.appName : "")
                    label: root.note ? root.note.appName : ""
                    color: root.critical ? Theme.seal : Theme.frame
                    glyphColor: Theme.titlebarText
                    outline: false
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
                        visible: root.iconSource.length > 0
                        source: root.iconSource
                    }
                }
            }
            Column {
                width: parent.width - 24 - parent.spacing - (root.critical ? 52 : 28)
                spacing: 2
                Row {
                    width: parent.width
                    spacing: Theme.space.sm
                    Text {
                        width: parent.width - timeText.implicitWidth - parent.spacing
                        text: root.note ? (root.note.summary.length ? root.note.summary : root.note.appName) : ""
                        color: root.critical ? Theme.error : Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontFor("ui").pixelSize
                        font.weight: 600
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        renderType: Text.NativeRendering
                        Behavior on color { ColorAnimation { duration: Theme.durTheme } }
                    }
                    InkText {
                        id: timeText
                        role: "small"; muted: true
                        text: root.note ? TimeService.relative(root.note.time) : ""
                        anchors.top: parent.top
                    }
                }
                InkText {
                    visible: root.note && root.note.appName.length > 0 && root.note.summary.length > 0
                    role: "small"; muted: true
                    text: root.note ? root.note.appName : ""
                    width: parent.width
                }
            }
        }
        Row {   // body (+ image)
            width: parent.width
            spacing: Theme.space.md
            visible: bodyText.text.length > 0 || root.imageSource.length > 0
            Rectangle {
                visible: root.imageSource.length > 0
                width: 48; height: 48; radius: Theme.radius.xs
                color: Theme.surfaceAlt; border.width: 1; border.color: Theme.hairline
                clip: true
                Image { anchors.fill: parent; anchors.margins: 1; source: root.imageSource; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 96 }
            }
            Text {
                id: bodyText
                width: parent.width - (root.imageSource.length ? 48 + parent.spacing : 0)
                text: root.note ? root.note.body : ""
                color: Theme.textMuted
                font.family: Theme.fontBody
                font.pixelSize: Theme.fontFor("body").pixelSize
                lineHeight: 1.3
                wrapMode: Text.Wrap
                maximumLineCount: root.compact ? 4 : 3
                elide: Text.ElideRight
                textFormat: Text.StyledText
                renderType: Text.NativeRendering
                linkColor: Theme.link
                onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
        }
        Flow {   // actions
            width: parent.width
            spacing: Theme.space.sm
            visible: root.note && root.note.actions && root.note.actions.length > 0
            Repeater {
                model: root.note ? root.note.actions : []
                InkButton {
                    required property var modelData
                    quiet: false
                    implicitHeight: 28
                    text: modelData.text || modelData.identifier
                    primary: root.critical && modelData.identifier !== "default"
                    onClicked: modelData.invoke()
                }
            }
        }
    }

    // body click → default action / dismiss
    MouseArea {
        anchors.fill: column
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.compact ? NotificationService.dismiss(root.note) : NotificationService.invokeDefault(root.note)
    }
    InkButton {   // close ✕
        anchors.right: parent.right; anchors.top: parent.top
        anchors.rightMargin: root.critical ? 40 : 10; anchors.topMargin: 8
        quiet: true
        icon: "󰅖"
        tooltip: "Dismiss"
        implicitHeight: 22; implicitWidth: 22
        horizontalPadding: 0
        opacity: root.compact || root.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        onClicked: root.closeClicked()
    }
    // timeout progress: 2 px accent line, restarts when the pointer leaves (the service timer restarts too)
    Rectangle {
        visible: !root.compact && root.note && root.note.timeout > 0 && !root.note.closing
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.leftMargin: 6; anchors.bottomMargin: 3
        height: 2
        color: root.critical ? Theme.seal : Theme.accent
        width: 0
        NumberAnimation on width {
            id: progress
            from: root.width - 12; to: 0
            duration: root.note ? Math.max(1, root.note.timeout) : 1
            running: root.note ? (root.note.popup && root.note.timeout > 0 && !root.note.hovered) : false
        }
    }
}
