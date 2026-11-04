import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common

/*  OverlayWindow — a full-screen layer window hosting one modal surface (launcher, power, wallpapers, network …).
 *    open:       drives visibility; the window stays mapped for the close animation (durFast) then unmaps
 *    scrim:      35 % overlay behind the surface; clicking it closes
 *    namespace:  WlrLayershell namespace (overworld-launcher …)
 *    keyboard:   Exclusive while open (panels need the password field / search field / arrow keys), None otherwise
 *    content:    default property; children are placed inside a FocusScope that handles Esc
 *    progress:   0 → 1 while opening (use it for translate/opacity in the content)
 *  Placed per screen with Variants; only the focused monitor shows the surface.
 */
PanelWindow {
    id: root
    property bool open: false
    property bool scrim: true
    property string namespace: "overworld-overlay"
    property bool onlyFocusedScreen: true
    property real progress: 0
    readonly property bool onFocusedScreen: !onlyFocusedScreen || !Hyprland.focusedMonitor || !screen
                                            || Hyprland.focusedMonitor.name === screen.name
    readonly property bool shown: open && onFocusedScreen
    default property alias content: contentScope.data
    property alias contentItem: contentScope
    signal closeRequested()

    WlrLayershell.namespace: root.namespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    onShownChanged: {
        if (shown) { unmapTimer.stop(); visible = true; root.progress = 1; contentScope.forceActiveFocus(); }
        else { root.progress = 0; unmapTimer.restart(); }
    }
    Behavior on progress {
        NumberAnimation {
            duration: root.progress > 0 ? Theme.durBase : Theme.durFast
            easing.type: root.progress > 0 ? Theme.easeInk : Theme.easeBrush
        }
    }
    Timer { id: unmapTimer; interval: Theme.durFast + 60; onTriggered: if (!root.shown) root.visible = false }

    Rectangle {   // scrim
        anchors.fill: parent
        color: Theme.overlay
        visible: root.scrim
        opacity: root.progress
        MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
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
