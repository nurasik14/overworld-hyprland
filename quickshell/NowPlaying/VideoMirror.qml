import QtQuick
import QtMultimedia
import "sync.js" as Sync

/*  VideoMirror — the silent picture of what the browser plays. A MediaPlayer with NO audio output at all (so it cannot make a
 *  sound, and no stream shows up in the mixer) drawing into a VideoOutput, steered by the browser's clock (sync.js):
 *    source: string      a local file (the daemon's cache), "" = nothing
 *    clock: var          {valid, position, ts, paused, rate, duration} (NowPlayingService.clock)
 *    active: bool        false = stop and release the file (hidden PiP, an ad, video off)
 *    readonly ready      a picture is up (fade it in over the thumbnail)
 *    readonly lastDecision  the last sync.decide() result (tests, the status line)
 *  Steering: once a second and at once when the clock changes (play / pause / seek / rate).
 */
Item {
    id: root
    property string source: ""
    property var clock: ({ valid: false })
    property bool active: true
    property int fillMode: VideoOutput.PreserveAspectCrop
    readonly property bool loaded: player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia
                                   || player.mediaStatus === MediaPlayer.BufferingMedia || player.mediaStatus === MediaPlayer.EndOfMedia
    readonly property bool failed: player.error !== MediaPlayer.NoError || player.mediaStatus === MediaPlayer.InvalidMedia
    property bool framed: false               // the first frame after a load has been drawn
    readonly property bool ready: root.active && root.loaded && !root.failed && root.framed && player.hasVideo
    property var lastDecision: ({ reason: "idle" })
    property real lastSeekMs: 0
    property int failedSeeks: 0
    property bool seekPending: false
    readonly property alias mediaPlayer: player

    MediaPlayer {
        id: player
        source: root.active && root.source.length ? (root.source.indexOf("/") === 0 ? "file://" + root.source : root.source) : ""
        videoOutput: out
        audioOutput: null            // never any sound: the audio stays in the browser
        loops: 1
        onSourceChanged: { root.framed = false; root.failedSeeks = 0; root.lastSeekMs = 0; }
        onMediaStatusChanged: if (root.loaded) root.steer()
        onPositionChanged: if (!root.framed && root.loaded) root.framed = true
        onErrorOccurred: (error, errorString) => console.warn("nowplaying mirror:", errorString)
    }
    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: root.fillMode
    }
    Timer { interval: 1000; repeat: true; running: root.active && root.loaded; onTriggered: root.steer() }
    Timer { id: frameGuard; interval: 600; running: root.loaded && !root.framed; onTriggered: root.framed = true }   // paused at a frame: no position tick
    // the clock object is rebuilt on every service update (several a second): steer at once only when something the browser did changed
    property var _lastClock: ({})
    onClockChanged: {
        const c = clock || {}, l = _lastClock || {};
        const jump = c.valid && l.valid && Math.abs(Sync.target(c, Date.now()) - Sync.target(l, Date.now())) > 0.25;
        _lastClock = c;
        if (c.paused !== l.paused || c.rate !== l.rate || c.valid !== l.valid || jump) steer();
    }

    function steer() {
        if (!root.active || !root.loaded || root.failed) return;
        const now = Date.now();
        const c = root.clock || { valid: false };
        const t = Sync.target(c, now);
        const mirrorPos = player.position / 1000;
        const fresh = c.valid && (c.paused || (now - c.ts) < 3500);
        // did the last seek hold? (judged on a decision at least 0.9 s later: right after a seek the position has not caught up yet)
        if (root.seekPending && now - root.lastSeekMs >= 900) {
            root.seekPending = false;
            if (t >= 0 && Math.abs(t - mirrorPos) > Sync.SEEK) root.failedSeeks++;
            else root.failedSeeks = 0;
        }
        const d = Sync.decide({
            loaded: true, target: t, mirrorPos: mirrorPos, mirrorDuration: player.duration / 1000,
            buffering: player.mediaStatus === MediaPlayer.BufferingMedia || player.mediaStatus === MediaPlayer.StalledMedia,
            playing: c.valid && !c.paused, rate: c.rate || 1, nowMs: now, lastSeekMs: root.lastSeekMs,
            failedSeeks: root.failedSeeks, fresh: fresh
        });
        root.lastDecision = d;
        if (Math.abs(player.playbackRate - d.rate) > 0.001) player.playbackRate = d.rate;
        if (d.seekTo >= 0) {
            player.position = Math.round(d.seekTo * 1000);
            root.lastSeekMs = now;
            root.seekPending = true;
        }
        if (d.play && player.playbackState !== MediaPlayer.PlayingState) player.play();
        else if (!d.play && player.playbackState === MediaPlayer.PlayingState) player.pause();
        else if (!d.play && player.playbackState === MediaPlayer.StoppedState && d.seekTo >= 0) player.pause();   // show the paused frame
    }
    onActiveChanged: if (!active) player.stop()
}
