//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.NowPlaying

/*  The service + the PiP entry (IPC target `nowplaying`) in a private instance, driven from tests/nowplaying-service.test.sh.
 *  Needs OW_NOWPLAYING_STATE, HYPR_NOWPLAYING_RUNTIME/_CACHE/_DATA, OW_CONFIG (nowplaying.port) pointing at temp files.
 *  Prints one STATE line a second.
 */
ShellRoot {
    NowPlayingIpc {}
    IpcHandler {   // test-only: press the PiP's TikTok buttons (the product has no IPC verb for them)
        target: "nptest"
        function act(name: string): string { return NowPlayingService.act(name) ? "sent" : "refused" }
    }
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            const s = NowPlayingService;
            console.warn("STATE " + JSON.stringify({ on: s.on, shown: s.shown, daemon: s.daemonRunning, kind: s.cur.kind, site: s.site,
                title: s.title, artist: s.artist, aspect: Math.round(s.aspect * 1000) / 1000, videoFile: s.videoFile, videoStatus: s.videoStatus,
                paused: s.paused, pos: Math.round(s.positionNow() * 10) / 10, key: s.key, live: s.live, art: s.artUrl, hasMedia: s.hasMedia,
                lingering: s.lingering, fs: s.hiddenByFullscreen, canLike: s.canLike, liked: s.liked, saved: s.saved, reposted: s.reposted,
                busy: s.busy, actErr: s.actionError, actErrFor: s.actionErrorFor, actErrFresh: s.actionErrorFresh, status: s.statusLine() }));
        }
    }
}
