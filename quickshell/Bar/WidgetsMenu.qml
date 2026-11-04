import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Widgets.Services

/*  WidgetsMenu — paper slip under the bar's widgets chip (󰕮): switch the desktop layer and each card on/off.
 *  Click outside (HyprlandFocusGrab) or Esc closes it.  State lives in WidgetsState (persisted).
 */
PanelWindow {
    id: menu
    property Item target: null
    readonly property bool open: WidgetsState.menuOpen
    // A layer-shell panel right under the chip (an xdg popup off the bar landed at x = 0 on Hyprland 0.56).
    screen: target && target.QsWindow.window ? target.QsWindow.window.screen : null
    WlrLayershell.namespace: "overworld-widgetsmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins.top: (Theme.sizes.bar_height || 36) + 4
    margins.right: {
        if (!target || !target.QsWindow.window) return 8;
        const p = target.mapToItem(null, 0, 0);
        return Math.max(4, target.QsWindow.window.width - (p.x + target.width));
    }
    implicitWidth: 248
    implicitHeight: col.implicitHeight + Theme.space.sm * 2
    visible: open && target !== null
    color: "transparent"

    HyprlandFocusGrab {
        windows: [menu]
        active: menu.visible
        onCleared: WidgetsState.menuOpen = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.md
        color: Theme.bg1
        border.width: 1
        border.color: Theme.frame
        focus: true
        Keys.onEscapePressed: WidgetsState.menuOpen = false

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space.sm }
            spacing: 2

            Row {   // header
                spacing: Theme.space.sm
                leftPadding: Theme.space.xs || 4
                height: 26
                Text {
                    text: "台"; color: Theme.seal
                    font.family: Theme.fontDisplay; font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
                Text {
                    text: "DESK WIDGETS"; color: Theme.textMuted
                    font.family: Theme.fontUi; font.pixelSize: 11; font.letterSpacing: 1.2
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
            }

            MenuRow {
                cjk: "全"; label: "All widgets  (Super+G)"
                checked: WidgetsState.visible
                onToggled: WidgetsState.toggle()
            }
            Rectangle { width: parent.width; height: 1; color: Theme.hairline }

            Repeater {
                model: WidgetsState.cardList
                MenuRow {
                    required property var modelData
                    cjk: modelData.cjk; label: modelData.name
                    checked: WidgetsState.cardOn(modelData.id)
                    dimmed: !WidgetsState.visible
                    onToggled: WidgetsState.toggleCard(modelData.id)
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hairline }
            MenuRow {
                cjk: "原"; label: "Reset positions"; isAction: true
                onToggled: WidgetsState.resetAll()
            }
        }
    }

    component MenuRow: Item {
        id: row
        property string cjk: ""
        property string label: ""
        property bool checked: false
        property bool dimmed: false
        property bool isAction: false
        signal toggled()
        width: parent ? parent.width : 200
        height: 28
        Rectangle {
            anchors.fill: parent; radius: Theme.radius.sm
            color: Theme.inkWash
            opacity: ma.pressed ? 1 : (ma.containsMouse ? 0.7 : 0)
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.space.sm
            spacing: Theme.space.sm
            opacity: row.dimmed ? 0.55 : 1
            Rectangle {   // seal checkbox
                visible: !row.isAction
                width: 14; height: 14; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: row.checked ? Theme.seal : "transparent"
                border.width: 1; border.color: row.checked ? Theme.seal : Theme.textMuted
                Text {
                    anchors.centerIn: parent; visible: row.checked
                    text: "✓"; color: Theme.textOnSeal
                    font.pixelSize: 10; font.weight: 700
                    renderType: Text.NativeRendering
                }
            }
            Text {
                text: row.cjk; color: Theme.text
                width: 26
                font.family: Theme.fontBody; font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
            }
            Text {
                text: row.label; color: row.isAction ? Theme.textMuted : Theme.text
                font.family: Theme.fontUi; font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
    }
}
