import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common

/*  OverlayWindow — a full-screen layer window hosting one modal GUI screen (launcher, power, wallpapers, network …).
 *  The look and the fade (≤ 150 ms, dimmed menu gradient) are McScreen's.
 *    open:        drives visibility; the window stays mapped for the fade-out, then unmaps
 *    background:  "gradient" (default, the in-world menu gradient) | "menu" (1.21 list screen, headerHeight/footerHeight)
 *    title, titleY: the white screen title
 *    closeOnClickOutside: a click that hits no widget closes (default true)
 *    namespace:   WlrLayershell namespace (overworld-launcher …)
 *    keyboard:    Exclusive while open (the panels need the fields and arrow keys), None otherwise (and always in previews)
 *    content:     default property; children are placed inside a FocusScope that handles Esc
 *    progress:    1 while open, 0 while closed; the fade already happens on the whole screen
 *  Placed per screen with Variants; only the focused monitor shows the surface.
 */
PanelWindow {
    id: root
    property bool open: false
    property string background: "gradient"
    property string title: ""
    property int titleY: 20
    property int headerHeight: 33
    property int footerHeight: 33
    property bool closeOnClickOutside: true
    property string namespace: "overworld-overlay"
    property bool onlyFocusedScreen: true
    readonly property real progress: open ? 1 : 0
    readonly property bool onFocusedScreen: !onlyFocusedScreen || !Hyprland.focusedMonitor || !screen
                                            || Hyprland.focusedMonitor.name === screen.name
    readonly property bool shown: open && onFocusedScreen
    default property alias content: contentScope.data
    property alias contentItem: contentScope
    property alias gui: gui
    signal closeRequested()

    WlrLayershell.namespace: root.namespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown && !ShellState.preview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onShownChanged: {
        if (shown) {
            unmapTimer.stop();
            visible = true;
            gui.opened = true;
            contentScope.forceActiveFocus();
        } else {
            gui.opened = false;
            unmapTimer.restart();
        }
    }
    Timer { id: unmapTimer; interval: Theme.guiFade + 30; onTriggered: if (!root.shown) root.visible = false }

    McScreen {
        id: gui
        anchors.fill: parent
        title: root.title
        titleY: root.titleY
        background: root.background
        headerHeight: root.headerHeight
        footerHeight: root.footerHeight
        closeOnEscape: false

        Rectangle {   // the game blurs the world behind a list screen; there is no blur here, so it dims it further instead
            anchors.fill: parent
            visible: root.background === "menu"
            color: "#B0000000"
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.closeOnClickOutside
            onClicked: root.closeRequested()
        }
        FocusScope {
            id: contentScope
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { event.accepted = true; root.closeRequested(); }
            }
        }
    }
}
