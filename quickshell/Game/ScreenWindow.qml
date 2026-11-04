import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common

/*  ScreenWindow — a full-screen layer window hosting one McScreen of this module (advancements, stats, options, switcher).
 *    open: bool            drives the screen; the window stays mapped for the fade-out, then unmaps
 *    namespace: string     layer namespace (overworld-advancements …)
 *    title, titleY, background   forwarded to McScreen
 *    content               default property: placed inside the McScreen
 *    signal closeRequested()   Esc or a click on the empty backdrop
 *  Shown on the focused monitor only. OW_NOFOCUS=1 (previews) never takes the keyboard.
 */
PanelWindow {
    id: win
    property bool open: false
    property string namespace: "overworld-screen"
    property alias title: screen.title
    property alias titleY: screen.titleY
    property alias background: screen.background
    property alias headerHeight: screen.headerHeight
    property alias footerHeight: screen.footerHeight
    default property alias content: screen.data
    readonly property alias screenItem: screen
    readonly property bool onFocusedScreen: !Hyprland.focusedMonitor || !win.screen || Hyprland.focusedMonitor.name === win.screen.name
    readonly property bool shown: open && onFocusedScreen
    readonly property bool grabKeys: Quickshell.env("OW_NOFOCUS") !== "1"
    signal closeRequested()

    WlrLayershell.namespace: win.namespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.shown && win.grabKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onShownChanged: {
        if (shown) { unmap.stop(); visible = true; screen.open(); screen.forceActiveFocus(); }
        else { screen.opened = false; unmap.restart(); }
    }
    Timer { id: unmap; interval: Theme.guiFade + 80; onTriggered: if (!win.shown) win.visible = false }

    McScreen {
        id: screen
        anchors.fill: parent
        closeOnEscape: false
        focus: true
        Keys.onEscapePressed: event => { event.accepted = true; win.closeRequested(); }
        MouseArea { anchors.fill: parent; z: -1; onClicked: win.closeRequested() }
    }
}
