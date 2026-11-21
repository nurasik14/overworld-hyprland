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
        // the active window as Hyprland would report it: `fullscreen 1` = maximized, 2 = fullscreen, `none` = no window
        function fullscreen(mode: string): string {
            if (mode === "none") { NowPlayingService.testToplevel = null; return "none"; }
            const n = Number(mode) || 0;
            NowPlayingService.testToplevel = { lastIpcObject: { "class": "zen", fullscreen: n }, wayland: { fullscreen: (n & 2) !== 0, maximized: n === 1, appId: "zen" } };
            return "fullscreen " + n;
        }
        function control(what: string): string { NowPlayingService.act(what); return NowPlayingService.route }
        // what the shell would send the daemon for an MPRIS-only YouTube video at `pos` ("" = nothing now)
        function want(id: string, dur: real, pos: real, paused: bool): string {
            const w = NowPlayingService.longWant({ kind: "mpris", youtubeId: id, key: "youtube-" + id, isVideo: true, duration: dur,
                                                   position: pos, ts: Date.now(), paused: paused, rate: 1 }, Date.now());
            return w ? JSON.stringify(w) : "";
        }
        // the source list with stand-in MPRIS players: "dbusName|identity|title|playing(1/0);…" (the qs CLI splits JSON on commas)
        function sourcesWith(spec: string): string {
            const list = String(spec).split(";").filter(x => x.length).map(x => {
                const f = x.split("|");
                return { dbusName: f[0], identity: f[1], trackTitle: f[2], isPlaying: f[3] === "1", desktopEntry: "", trackArtist: "",
                         trackArtUrl: "", playbackState: -1, metadata: {} };
            });
            return NowPlayingService.buildSources(NowPlayingService.daemonState, Date.now(), list).map(x => x.id + "|" + x.label + "|" + x.site).join(";");
        }
    }
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            const s = NowPlayingService;
            console.warn("STATE " + JSON.stringify({ on: s.on, shown: s.shown, daemon: s.daemonRunning, kind: s.cur.kind, site: s.site,
                title: s.title, artist: s.artist, aspect: Math.round(s.aspect * 1000) / 1000, videoFile: s.videoFile, videoStatus: s.videoStatus,
                paused: s.paused, pos: Math.round(s.positionNow() * 10) / 10, key: s.key, live: s.live, art: s.artUrl, hasMedia: s.hasMedia,
                lingering: s.lingering, fs: s.hiddenByFullscreen, canLike: s.canLike, liked: s.liked, saved: s.saved, reposted: s.reposted,
                busy: s.busy, actErr: s.actionError, actErrFor: s.actionErrorFor, actErrFresh: s.actionErrorFresh, status: s.statusLine(),
                sources: s.sources.map(x => x.id + "|" + x.label + "|" + (x.paused ? "paused" : "playing") + "|" + x.title).join(";"),
                pinned: s.pinnedId, auto: s.auto, shownId: s.shownId, shownIndex: s.shownIndex, route: s.route, canToggle: s.canToggle,
                canNext: s.canNext, canPrevious: s.canPrevious, tab: s.view.tab || "",
                inParts: s.videoInParts, partsText: s.partsText, mirrorParts: s.mirrorParts }));
        }
    }
}
