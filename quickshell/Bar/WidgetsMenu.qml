import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets.Services
import qs.NowPlaying

/*  WidgetsMenu — a Minecraft panel above the HUD's item-frame slot: the desktop layer and each card on/off, reset positions.
 *  Click outside (HyprlandFocusGrab) or Esc closes it. State lives in WidgetsState (persisted). Namespace overworld-widgetsmenu.
 *  Below the cards: the Now Playing PiP (an overlay, not a desktop card: "All widgets" and the chip's middle-click leave it alone;
 *  its on/off lives in NowPlayingService, ~/.config/overworld/nowplaying.json).
 */
PanelWindow {
    id: menu
    property Item target: null
    readonly property bool open: WidgetsState.menuOpen
    screen: target && target.QsWindow.window ? target.QsWindow.window.screen : null
    WlrLayershell.namespace: "overworld-widgetsmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.preview ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; left: true }
    margins.bottom: Theme.px(22)
    margins.left: {
        if (!target || !target.QsWindow.window) return Theme.px(2);
        return Math.max(Theme.px(2), target.mapToItem(null, 0, 0).x);
    }
    implicitWidth: Theme.px(150)
    implicitHeight: col.implicitHeight + Theme.px(24)
    visible: open && target !== null
    color: "transparent"

    HyprlandFocusGrab {
        windows: [menu]
        active: menu.visible && !ShellState.preview
        onCleared: WidgetsState.menuOpen = false
    }

    McPanel {
        anchors.fill: parent
        title: "Desk Widgets"
        focus: true
        Keys.onEscapePressed: WidgetsState.menuOpen = false

        Column {
            id: col
            y: Theme.px(10)
            width: parent.width
            spacing: Theme.px(2)

            McCheckbox {
                text: "All widgets"
                labelColor: Theme.guiText
                checked: WidgetsState.visible
                onToggled: WidgetsState.toggle()
            }
            McDivider { width: parent.width }
            Repeater {
                model: WidgetsState.cardList
                Item {
                    id: cardRow
                    required property var modelData
                    width: parent.width
                    height: Theme.px(20)
                    McCheckbox {
                        text: cardRow.modelData.name
                        labelColor: Theme.guiText
                        opacity: WidgetsState.visible ? 1 : 0.55
                        checked: WidgetsState.cardOn(cardRow.modelData.id)
                        onToggled: WidgetsState.toggleCard(cardRow.modelData.id)
                    }
                    McItemIcon {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        name: cardRow.modelData.item || ""
                    }
                }
            }
            McDivider { width: parent.width }
            Item {
                width: parent.width
                height: Theme.px(20)
                McCheckbox {
                    text: "Now Playing PiP"
                    labelColor: Theme.guiText
                    checked: NowPlayingService.on
                    onToggled: NowPlayingService.toggle()
                }
                McItemIcon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: "painting"
                }
            }
            McDivider { width: parent.width }
            McButton {
                width: parent.width
                text: "Reset Positions"
                onClicked: WidgetsState.resetAll()
            }
        }
    }
}
