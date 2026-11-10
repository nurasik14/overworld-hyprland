import QtQuick
import Quickshell
import Quickshell.Io
import qs.NowPlaying

/*  IPC target `nowplaying` (lives in NowPlayingPip; separate so offscreen tests can load it without a layer surface):
 *    qs -c overworld ipc call nowplaying toggle | on | off | status | reveal | reset
 */
IpcHandler {
    target: "nowplaying"
    function toggle(): string { NowPlayingService.toggle(); return NowPlayingService.on ? "on" : "off" }
    function on(): string { NowPlayingService.setOn(true); return "on" }
    function off(): string { NowPlayingService.setOn(false); return "off" }
    function status(): string { return NowPlayingService.statusLine() }
    // `reveal`, not `show` (the qs CLI swallows a function named show): on, on the focused monitor, visible for a while even when idle
    function reveal(): string { NowPlayingService.reveal(); return "revealed on " + NowPlayingService.screenName }
    function reset(): string { NowPlayingService.resetPos(NowPlayingService.screenName); return "position and size reset on " + NowPlayingService.screenName }
}
