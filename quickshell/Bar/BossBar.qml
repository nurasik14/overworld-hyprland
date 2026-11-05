import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  BossBar — top centre, namespace overworld-bossbar, click-through, only while something is active.
 *  Several active bars STACK like several bosses in the game (19 GUI px apart):
 *    1. the brew timer ("Brewing: <workspace title>  12:34", drains as time passes; green while resting, yellow when paused)
 *    2. the playing media ("Now Playing: <title>", follows the track position)
 *  config.json hud.bossbar_media: "playing" (default, as long as it plays) | "track" (10 s after a track starts) | "off".
 */
Scope {
    id: root
    readonly property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++) if (list[i].isPlaying) return list[i];
        return null;
    }
    readonly property string mediaMode: String(ConfigService.get("hud.bossbar_media"))
    readonly property string trackId: player ? String(player.trackTitle) + "|" + String(player.trackArtist) : ""
    property bool trackFresh: false
    onTrackIdChanged: if (trackId.length) { trackFresh = true; trackTimer.restart(); }
    Timer { id: trackTimer; interval: 10000; onTriggered: root.trackFresh = false }
    Timer {   // Mpris position does not notify on its own
        interval: 1000; repeat: true
        running: root.mediaShown
        onTriggered: if (root.player) root.player.positionChanged()
    }

    readonly property bool brewShown: BrewTimer.active
    readonly property bool mediaShown: player !== null
        && (mediaMode === "playing" || (mediaMode === "track" && trackFresh))
    readonly property int count: (brewShown ? 1 : 0) + (mediaShown ? 1 : 0)
    readonly property bool shown: count > 0

    readonly property string brewTitle: {
        const phase = BrewTimer.phase;
        const task = WorkspaceNotes.title(HyprlandState.focusedId);
        if (phase === "breaking") return (BrewTimer.state === "paused" ? "Resting (paused)  " : "Resting  ") + BrewTimer.mmss;
        const what = task.length ? "Brewing: " + task : "Brewing";
        return what + (BrewTimer.state === "paused" ? " (paused)  " : "  ") + BrewTimer.mmss;
    }
    readonly property string mediaTitle: player ? "Now Playing: " + (player.trackTitle || player.identity || "") : ""

    readonly property int rowH: 15      // one bar: title line + bar, in GUI px
    readonly property int rowStep: 19   // the game's spacing between stacked boss bars

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "overworld-bossbar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            margins.top: Theme.px(3)
            implicitWidth: Theme.px(182 + 80)
            implicitHeight: Theme.px(root.rowH + Math.max(0, root.count - 1) * root.rowStep)
            color: "transparent"
            mask: Region {}
            visible: root.shown && !ConfigService.isSpectator && !ShellState.hudHidden

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.px(root.rowStep - root.rowH)

                // 1. brew timer
                Item {
                    visible: root.brewShown
                    width: Theme.px(182 + 80); height: Theme.px(root.rowH)
                    McText {   // a long title may be wider than the bar, like the game
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, parent.width)
                        text: root.brewTitle
                        color: Theme.hudText
                        elide: Text.ElideRight
                    }
                    McProgressBar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: Theme.px(182)
                        kind: "boss"
                        color: BrewTimer.state === "paused" ? "yellow" : BrewTimer.phase === "breaking" ? "green" : "purple"
                        notches: 10
                        value: 1 - BrewTimer.progress
                    }
                }

                // 2. now playing
                Item {
                    visible: root.mediaShown
                    width: Theme.px(182 + 80); height: Theme.px(root.rowH)
                    McText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, parent.width)
                        text: root.mediaTitle
                        color: Theme.hudText
                        elide: Text.ElideRight
                    }
                    McProgressBar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: Theme.px(182)
                        kind: "boss"
                        color: "pink"
                        notches: 0
                        value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 1
                    }
                }
            }
        }
    }
}
