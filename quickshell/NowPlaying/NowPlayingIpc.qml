import QtQuick
import Quickshell
import Quickshell.Io
import qs.NowPlaying

/*  IPC target `nowplaying` (lives in NowPlayingPip; separate so offscreen tests can load it without a layer surface), and the
 *  memory of the chosen source across shell reloads (PersistentProperties do not survive a reload inside a singleton):
 *    qs -c overworld ipc call nowplaying toggle | on | off | status | reveal | reset
 *    qs -c overworld ipc call nowplaying sources            one line per source (0 = auto), `*` = the current choice
 *    qs -c overworld ipc call nowplaying pick <n|next|prev|auto>   pin source n (released when it goes away) / Auto
 */
Scope {
    PersistentProperties {
        id: keep
        reloadableId: "nowplayingPinnedSource"
        property string pinned: ""
        onLoaded: NowPlayingService.restorePin(keep.pinned)
    }
    Connections { target: NowPlayingService; function onPinnedIdChanged() { keep.pinned = NowPlayingService.pinnedId } }

    IpcHandler {
        target: "nowplaying"
        function toggle(): string { NowPlayingService.toggle(); return NowPlayingService.on ? "on" : "off" }
        function on(): string { NowPlayingService.setOn(true); return "on" }
        function off(): string { NowPlayingService.setOn(false); return "off" }
        function status(): string { return NowPlayingService.statusLine() }
        // `reveal`, not `show` (the qs CLI swallows a function named show): on, on the focused monitor, visible for a while even when idle
        function reveal(): string { NowPlayingService.reveal(); return "revealed on " + NowPlayingService.screenName }
        function reset(): string { NowPlayingService.resetPos(NowPlayingService.screenName); return "position and size reset on " + NowPlayingService.screenName }
        // several tabs / apps: list them, pin one (or `auto`, `next`, `prev`)
        function sources(): string { return NowPlayingService.sourcesText() }
        function pick(which: string): string { return NowPlayingService.pick(which) }
    }
}
