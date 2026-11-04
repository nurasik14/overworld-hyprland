import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  MusicCard — 音乐 · SPOTIFY (300 × 420, translucent paper over the wallpaper, like the reference).
 *  Album cover (rounded 4, soft shadow; paper square with 音 when there is no art), title, artist,
 *  prev / play-pause / next, seekable ink progress line with a seal knob, elapsed / length.
 *  Empty state: "Nothing playing · 靜" over a faint enso.
 */
WidgetCard {
    id: card
    title: "音乐"
    subtitle: MusicService.identity.length ? MusicService.identity : "Music"
    sealGlyph: "猫"
    transparent: true
    width: 300
    height: 420

    readonly property var svc: MusicService
    readonly property bool active: svc.hasPlayer && (svc.title.length > 0 || svc.artist.length > 0)
    readonly property int coverSize: 196

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: Theme.space.md
        visible: card.active

        // ---- cover
        Item {
            width: card.coverSize; height: card.coverSize
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                id: coverShadowSrc
                anchors.fill: parent; radius: 4; color: Theme.shadowStrong; visible: false; layer.enabled: true
            }
            MultiEffect {
                source: coverShadowSrc; anchors.fill: coverShadowSrc; anchors.topMargin: 4
                blurEnabled: true; blur: 1.0; blurMax: 20; blurMultiplier: 0.5; autoPaddingEnabled: true
            }
            Rectangle {   // paper fallback square
                anchors.fill: parent
                radius: 4
                color: Theme.surfaceAlt
                border.width: 1; border.color: Theme.hairline
                Text {
                    anchors.centerIn: parent
                    text: "音"
                    color: Theme.textMuted
                    font.family: Theme.fontDisplay
                    font.pixelSize: 72
                    renderType: Text.NativeRendering
                }
            }
            Image {
                id: cover
                anchors.fill: parent
                source: card.svc.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize: Qt.size(card.coverSize * 2, card.coverSize * 2)
                visible: false
            }
            MultiEffect {   // rounded corners for the cover
                source: cover
                anchors.fill: cover
                visible: cover.status === Image.Ready
                maskEnabled: true
                maskSource: coverMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            Item {
                id: coverMask
                width: cover.width; height: cover.height
                layer.enabled: true
                visible: false
                Rectangle { anchors.fill: parent; radius: 4; color: "black" }
            }
            Rectangle {   // 1 px ink hairline over the cover edge
                anchors.fill: parent; radius: 4; color: "transparent"
                border.width: 1; border.color: Theme.withAlpha(Theme.frame, 0.35)
            }
        }

        // ---- title / artist
        Column {
            width: parent.parent.width
            spacing: 1
            InkText {
                role: "title"
                text: card.svc.title
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            InkText {
                role: "body"
                muted: true
                text: card.svc.artist
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        // ---- controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.space.lg
            InkButton { quiet: true; icon: "󰒮"; tooltip: "Previous"; enabled: card.svc.canGoPrevious; onClicked: card.svc.previous() }
            InkButton {
                icon: card.svc.playing ? "󰏤" : "󰐊"
                tooltip: card.svc.playing ? "Pause" : "Play"
                enabled: card.svc.canToggle
                horizontalPadding: Theme.space.lg
                onClicked: card.svc.togglePlaying()
            }
            InkButton { quiet: true; icon: "󰒭"; tooltip: "Next"; enabled: card.svc.canGoNext; onClicked: card.svc.next() }
        }

        // ---- progress
        Item {
            id: progress
            width: parent.parent.width
            height: 16
            readonly property real frac: card.svc.length > 0 ? Math.max(0, Math.min(1, card.svc.position / card.svc.length)) : 0
            property bool dragging: false
            property real dragFrac: 0
            readonly property real shownFrac: dragging ? dragFrac : frac
            Rectangle {   // track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 2
                color: Theme.hairline
            }
            Rectangle {   // elapsed ink
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * progress.shownFrac; height: 2
                color: Theme.text
                Behavior on width { enabled: !progress.dragging; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
            Rectangle {   // seal knob
                x: parent.width * progress.shownFrac - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 1
                color: Theme.seal
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35)
                Behavior on x { enabled: !progress.dragging; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                enabled: card.svc.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: mouse => { progress.dragging = true; progress.dragFrac = Math.max(0, Math.min(1, mouse.x / width)) }
                onPositionChanged: mouse => { if (pressed) progress.dragFrac = Math.max(0, Math.min(1, mouse.x / width)) }
                onReleased: { progress.dragging = false; card.svc.seek(progress.dragFrac * card.svc.length) }
            }
        }
        Item {
            width: parent.parent.width; height: 14
            InkText { role: "mono"; font.pixelSize: 11; muted: true; text: card.svc.fmt(card.svc.position); anchors.left: parent.left }
            InkText { role: "mono"; font.pixelSize: 11; muted: true; text: card.svc.fmt(card.svc.length); anchors.right: parent.right }
        }
    }

    // ---- empty state
    Item {
        anchors.fill: parent
        visible: !card.active
        Image {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -20
            width: 150; height: 150
            source: Theme.texture("enso-ink")
            opacity: 0.18
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true; asynchronous: true
        }
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -20
            spacing: 4
            Text {
                text: "靜"
                color: Theme.textMuted
                font.family: Theme.fontBody
                font.pixelSize: 40
                renderType: Text.NativeRendering
                anchors.horizontalCenter: parent.horizontalCenter
            }
            InkText { role: "body"; muted: true; text: "Nothing playing"; anchors.horizontalCenter: parent.horizontalCenter }
        }
        InkText {
            role: "small"; muted: true
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
            text: card.svc.players.length ? card.svc.players.length + " player" + (card.svc.players.length > 1 ? "s" : "") + " · idle" : "no MPRIS player"
        }
    }
}
