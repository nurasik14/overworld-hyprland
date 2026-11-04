pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Common
import qs.Widgets.Services

/*  MusicService — the MPRIS player shown by the Music card.
 *  Player choice: spotify (by dbusName / identity) → any playing player → the first one.
 *  Position: MprisPlayer.position is interpolated by Quickshell but bindings only refresh on
 *  positionChanged(); a 1 s Timer copies it into `position` while playing (and re-emits it).
 *  Demo (WidgetsState.demo): mocked track so the card can be screenshotted without a player.
 */
Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(p => p && !(p.dbusName || "").includes("playerctld"))
    property MprisPlayer player: pick()
    readonly property bool demo: WidgetsState.demo && player === null
    readonly property bool hasPlayer: player !== null || demo

    function pick() {
        const list = players;
        if (!list.length) return null;
        const sp = list.find(p => (p.dbusName || "").toLowerCase().includes("spotify") || (p.identity || "").toLowerCase().includes("spotify"));
        if (sp && (sp.isPlaying || !list.some(p => p.isPlaying))) return sp;
        return list.find(p => p.isPlaying) || sp || list[0];
    }
    function repick() { root.player = pick() }
    Connections { target: Mpris.players; function onValuesChanged() { root.repick() } }
    Instantiator {   // follow playback-state changes of every player (a newly playing one takes over)
        model: Mpris.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onPlaybackStateChanged() { root.repick() }
        }
    }

    // ---- demo track
    readonly property string demoTitle: "幾億光年"
    readonly property string demoArtist: "Omoinotake"
    readonly property real demoLength: 277
    property real demoPosition: 21
    readonly property string demoArt: "file://" + Theme.repoDir + "/assets/art/portrait-maomao.png"
    property bool demoPlaying: true

    // ---- unified view
    readonly property string title: demo ? demoTitle : (player ? (player.trackTitle || "") : "")
    readonly property string artist: demo ? demoArtist : (player ? (player.trackArtist || "") : "")
    readonly property string album: demo ? "" : (player ? (player.trackAlbum || "") : "")
    readonly property string artUrl: demo ? demoArt : (player ? (player.trackArtUrl || "") : "")
    readonly property string identity: demo ? "Spotify" : (player ? (player.identity || "") : "")
    readonly property bool playing: demo ? demoPlaying : (player ? player.isPlaying : false)
    readonly property real length: demo ? demoLength : (player && player.lengthSupported ? player.length : 0)
    readonly property bool canSeek: demo ? true : (player ? (player.canSeek && player.positionSupported) : false)
    readonly property bool canGoNext: demo ? true : (player ? player.canGoNext : false)
    readonly property bool canGoPrevious: demo ? true : (player ? player.canGoPrevious : false)
    readonly property bool canToggle: demo ? true : (player ? player.canTogglePlaying : false)
    property real position: 0

    function syncPosition() {
        if (demo) { root.position = demoPosition; return }
        if (player) { player.positionChanged(); root.position = player.positionSupported ? player.position : 0 }
        else root.position = 0;
    }
    Timer {
        interval: 1000; repeat: true
        running: root.hasPlayer && root.playing
        onTriggered: {
            if (root.demo) root.demoPosition = (root.demoPosition + 1) % root.demoLength;
            root.syncPosition();
        }
    }
    onPlayerChanged: syncPosition()
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() { if (root.player) root.position = root.player.positionSupported ? root.player.position : 0 }
        function onTrackChanged() { root.syncPosition() }
    }
    onDemoChanged: syncPosition()

    // ---- controls
    function togglePlaying() { if (demo) demoPlaying = !demoPlaying; else if (player && player.canTogglePlaying) player.togglePlaying() }
    function next() { if (demo) demoPosition = 0; else if (player && player.canGoNext) player.next() }
    function previous() { if (demo) demoPosition = 0; else if (player && player.canGoPrevious) player.previous() }
    function seek(seconds) {
        if (demo) { demoPosition = Math.max(0, Math.min(demoLength, seconds)); syncPosition(); return }
        if (player && canSeek) { player.position = Math.max(0, Math.min(length, seconds)); syncPosition() }
    }
    function fmt(s) {
        if (!s || s < 0 || !isFinite(s)) return "0:00";
        s = Math.floor(s);
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
