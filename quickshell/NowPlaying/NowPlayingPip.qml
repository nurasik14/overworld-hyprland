import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.NowPlaying

/*  NowPlayingPip — the floating Now Playing mini-player (entry, instantiated once in shell.qml).
 *  One layer surface on ONE monitor (the focused one when it appears; `reveal` brings it to the focused one), namespace
 *  overworld-nowplaying, layer Overlay (above fullscreen apps; config nowplaying.layer "top" keeps it below them), no keyboard,
 *  no exclusive zone. The surface spans the monitor but its input mask is the mini-player only, so the rest is click-through;
 *  while it is dragged or resized the mask is the whole monitor, so a fast flick cannot outrun it.
 *  Position per monitor (NowPlayingService.positions): distances from the nearest two edges; default bottom-right, above the HUD.
 *  IPC: qs -c overworld ipc call nowplaying toggle | on | off | status | reveal | reset
 */
Scope {
    id: root
    readonly property var svc: NowPlayingService
    readonly property string screenName: svc.screenName
    readonly property var screenObj: {
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) if (list[i].name === root.screenName) return list[i];
        return list.length ? list[0] : null;
    }
    Connections {
        target: root.svc
        function onShownChanged() { if (root.svc.shown && !win.visible) root.svc.pickScreen() }
        function onLayoutReset(name) { if (!name || name === root.screenName) { view.boxW = Qt.binding(() => root.boxDefault); root.bindPosition(); } }
    }

    readonly property var saved: svc.positions[screenName] || null
    readonly property int boxDefault: saved && saved.w > 0 ? Math.max(200, Math.min(960, saved.w)) : svc.defaultWidth
    readonly property int margin: Theme.px(6)
    readonly property int hudReserve: Theme.px(40)        // the HUD's exclusive zone at the bottom edge (Bar.qml)
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function placeX() {
        const W = win.width, w = view.width, s = root.saved;
        const x = !s ? W - root.margin - w : s.ax === "left" ? s.dx : W - s.dx - w;
        return Math.round(clamp(x, 0, Math.max(0, W - w)));
    }
    function placeY() {
        const H = win.height, h = view.height, s = root.saved;
        const y = !s ? H - root.hudReserve - root.margin - h : s.ay === "top" ? s.dy : H - s.dy - h;
        return Math.round(clamp(y, 0, Math.max(0, H - h)));
    }
    function bindPosition() { view.x = Qt.binding(root.placeX); view.y = Qt.binding(root.placeY); }
    function savePlace() {
        const W = win.width, H = win.height;
        const left = view.x + view.width / 2 < W / 2, top = view.y + view.height / 2 < H / 2;
        root.svc.savePos(root.screenName, {
            ax: left ? "left" : "right", ay: top ? "top" : "bottom",
            dx: left ? view.x : W - view.x - view.width, dy: top ? view.y : H - view.y - view.height, w: view.boxW
        });
        view.boxW = Qt.binding(() => root.boxDefault);
        bindPosition();
    }

    PanelWindow {
        id: win
        screen: root.screenObj
        WlrLayershell.namespace: "overworld-nowplaying"
        WlrLayershell.layer: root.svc.layerName === "top" ? WlrLayer.Top : WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        visible: root.svc.shown || view.opacity > 0.01

        Item { id: catcher; anchors.fill: parent }
        mask: Region { item: view.interacting ? catcher : view }

        NowPlayingView {
            id: view
            boxW: root.boxDefault
            opacity: root.svc.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.ms(250); easing.type: Easing.OutQuad } }
            Component.onCompleted: root.bindPosition()
            onGripActiveChanged: if (gripActive) { x = x; y = y; }      // hold the top-left corner while the grip resizes
            onDragFinished: root.savePlace()
            onResizeFinished: newBoxW => root.savePlace()
            onResetRequested: root.svc.resetPos(root.screenName)
            onCloseRequested: root.svc.setOn(false)
        }
    }

    NowPlayingIpc {}
}
