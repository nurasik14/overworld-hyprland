import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  MusicCard — the Jukebox (190 × 106 GUI px).
 *  Left: the album art pixelated into an item frame.  Right: a jukebox block with the record on the turntable (the disc
 *  spins in 7.5° steps on the 20 TPS clock while playing), elapsed / length, prev · play/pause · next as small
 *  Minecraft buttons.  Bottom: the action-bar line "Now Playing: Artist - Title" in the game's rainbow colour
 *  (scrolls when it does not fit) and the XP-style progress bar (click / drag to seek when the player allows it).
 *  Player choice and position polling live in MusicService (spotify first, else playing, else first; playerctld ignored).
 *  Empty state: an idle jukebox and "Nothing playing".
 */
WidgetCard {
    id: card
    title: MusicService.hasPlayer && MusicService.identity.length ? "Jukebox · " + MusicService.identity : "Jukebox"
    guiW: 190
    guiH: 106

    readonly property var svc: MusicService
    readonly property bool active: svc.hasPlayer && (svc.title.length > 0 || svc.artist.length > 0)

    McTicker { id: clock; active: card.visible && card.active && card.svc.playing && !Theme.reducedMotion }
    readonly property real discAngle: (clock.tick % 48) * 7.5

    // ---------------------------------------------------------------- playing
    Item {
        anchors.fill: parent
        visible: card.active

        // item frame holding the cover
        Item {
            id: frame
            width: Theme.px(58); height: Theme.px(58)
            Rectangle { anchors.fill: parent; color: "#5B3F22" }                       // 1 px outline
            Rectangle { x: Theme.gui; y: Theme.gui; width: parent.width - 2 * Theme.gui; height: parent.height - 2 * Theme.gui; color: "#C8B07A" }   // fallback tan
            Image {                                                                      // tan wooden border
                x: Theme.gui; y: Theme.gui; width: parent.width - 2 * Theme.gui; height: parent.height - 2 * Theme.gui
                source: Theme.tex("block/birch_planks"); fillMode: Image.Tile; smooth: false
                visible: source.toString() !== Theme.missingTexture
                horizontalAlignment: Image.AlignLeft; verticalAlignment: Image.AlignTop
            }
            Rectangle { x: Theme.px(3); y: Theme.px(3); width: Theme.px(52); height: Theme.px(52); color: "#7A4A2A" }
            Image {                                                                      // the frame's back
                x: Theme.px(3); y: Theme.px(3); width: Theme.px(52); height: Theme.px(52)
                source: Theme.tex("block/item_frame"); fillMode: Image.Tile; smooth: false
                visible: source.toString() !== Theme.missingTexture
            }
            Item {                                                                       // art: sampled down to 52×52 texels, like a map
                id: art
                x: Theme.px(3); y: Theme.px(3); width: Theme.px(52); height: Theme.px(52)
                visible: cover.status === Image.Ready
                layer.enabled: true
                layer.smooth: false
                layer.textureSize: Qt.size(52, 52)
                Image {
                    id: cover
                    anchors.fill: parent
                    source: card.svc.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    mipmap: true
                    sourceSize: Qt.size(208, 208)
                }
            }
            McItemIcon {                                                                  // no art: the record itself
                visible: cover.status !== Image.Ready
                size: 32
                anchors.centerIn: parent
                name: card.svc.disc
            }
            Rectangle { x: Theme.px(3); y: Theme.px(3); width: Theme.px(52); height: Theme.gui; color: "#40000000" }   // inner shadow under the top rail
        }

        // jukebox + turntable
        Item {
            x: Theme.px(64); y: 0
            width: Theme.px(112); height: Theme.px(18)
            McItemIcon { id: jukebox; name: "jukebox"; size: 16 }
            Item {   // the record, centred on a 16×16 slot, rotated in 7.5° steps
                x: Theme.px(22); width: Theme.px(16); height: Theme.px(16)
                rotation: card.discAngle
                McItemIcon { anchors.fill: parent; name: card.svc.disc; }
            }
            McText {
                x: Theme.px(44); anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(68)
                text: card.svc.playing ? "Playing" : "Paused"
                color: Theme.textMuted
                units: 1
            }
        }
        McText {
            x: Theme.px(64); y: Theme.px(21)
            width: Theme.px(112)
            text: card.svc.fmt(card.svc.position) + (card.svc.length > 0 ? " / " + card.svc.fmt(card.svc.length) : "")
            color: Theme.guiText
        }
        Row {
            x: Theme.px(64); y: Theme.px(36)
            spacing: Theme.px(2)
            McButton { width: Theme.px(34); height: Theme.px(16); glyph: "󰒮"; tooltip: "Previous"; enabled: card.svc.canGoPrevious; onClicked: card.svc.previous() }
            McButton {
                width: Theme.px(34); height: Theme.px(16)
                glyph: card.svc.playing ? "󰏤" : "󰐊"
                tooltip: card.svc.playing ? "Pause" : "Play"
                enabled: card.svc.canToggle
                onClicked: card.svc.togglePlaying()
            }
            McButton { width: Theme.px(34); height: Theme.px(16); glyph: "󰒭"; tooltip: "Next"; enabled: card.svc.canGoNext; onClicked: card.svc.next() }
        }

        // action bar: "Now Playing: Artist - Title" in the rainbow colour
        Item {
            id: bar
            y: Theme.px(62)
            width: Theme.px(176); height: Theme.px(10)
            clip: true
            readonly property bool overflow: line.implicitWidth > width
            property real offset: 0
            McTicker {
                active: card.visible && card.svc.playing && bar.overflow && !Theme.reducedMotion
                onTicked: n => {   // hold 30 ticks, crawl 1 GUI px per 2 ticks, hold, snap back
                    const travel = Math.ceil((line.implicitWidth - bar.width) / Theme.gui);
                    const cycle = 60 + travel * 2;
                    const t = n % cycle;
                    bar.offset = t < 30 ? 0 : Math.min(travel, Math.floor((t - 30) / 2)) * Theme.gui;
                }
            }
            McText {
                id: line
                x: bar.overflow ? -bar.offset : (bar.width - implicitWidth) / 2
                text: card.svc.nowPlaying
                rainbow: card.svc.playing          // repaints the whole widget layer at 20 Hz: only while there is music
                wrapMode: Text.NoWrap
            }
        }

        // XP-style progress, seekable
        Item {
            id: progress
            y: Theme.px(74)
            width: Theme.px(176); height: Theme.px(5)
            readonly property real frac: card.svc.length > 0 ? Math.max(0, Math.min(1, card.svc.position / card.svc.length)) : 0
            property bool dragging: false
            property real dragFrac: 0
            McProgressBar { anchors.fill: parent; width: parent.width; value: progress.dragging ? progress.dragFrac : progress.frac }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -Theme.px(3); anchors.bottomMargin: -Theme.px(3)
                enabled: card.svc.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: mouse => { progress.dragging = true; progress.dragFrac = Math.max(0, Math.min(1, mouse.x / width)) }
                onPositionChanged: mouse => { if (pressed) progress.dragFrac = Math.max(0, Math.min(1, mouse.x / width)) }
                onReleased: { progress.dragging = false; card.svc.seek(progress.dragFrac * card.svc.length) }
            }
        }
    }

    // ---------------------------------------------------------------- idle
    Item {
        anchors.fill: parent
        visible: !card.active
        McItemIcon { anchors.horizontalCenter: parent.horizontalCenter; y: Theme.px(8); size: 32; name: "jukebox" }
        McText {
            anchors.horizontalCenter: parent.horizontalCenter; y: Theme.px(46)
            text: "Nothing playing"
            color: Theme.guiText
        }
        McText {
            anchors.horizontalCenter: parent.horizontalCenter; y: Theme.px(58)
            color: Theme.textMuted
            text: card.svc.players.length ? card.svc.players.length + " player" + (card.svc.players.length > 1 ? "s" : "") + " idle" : "Insert a music disc (no MPRIS player)"
        }
    }
}
