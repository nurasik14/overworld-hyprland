import QtQuick
import qs.Common
import qs.Services

/*  Workspaces — 1–10 as 一二三四五六七八九十.  States: absent (faint), exists (muted), occupied (ink), active (seal behind glyph).
 *  Click switches, wheel cycles.  Glyph Ma Shan Zheng 15; active glyph in titlebarText on a 14 px seal (DESIGN §7.1).
 */
Row {
    id: root
    spacing: 4
    readonly property int rev: HyprlandState.revision

    Repeater {
        model: 10
        Item {
            id: ws
            required property int index
            readonly property int wid: index + 1
            readonly property bool exists: root.rev >= 0 && HyprlandState.exists(wid)
            readonly property bool occupied: root.rev >= 0 && HyprlandState.occupied(wid)
            readonly property bool active: root.rev >= 0 && HyprlandState.isActive(wid)
            width: 24; height: 28
            Accessible.role: Accessible.Button
            Accessible.name: "Workspace " + wid + (active ? " (active)" : "")

            Rectangle {   // hover wash
                anchors.fill: parent
                radius: Theme.radius.sm
                color: Theme.inkWash
                opacity: area.containsMouse ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            }
            Seal {        // the active marker sits behind the glyph
                anchors.centerIn: parent
                size: Theme.sizes.seal_small || 14
                glyph: ""
                label: "active workspace"
                outline: false
                opacity: ws.active ? 1 : 0
                scale: ws.active ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: Theme.durBase; easing.type: Theme.easeDrift } }
                Behavior on scale { NumberAnimation { duration: Theme.durBase; easing.type: Theme.easeDrift } }
            }
            Text {
                anchors.centerIn: parent
                text: TimeService.numeral(ws.wid)
                font.family: Theme.fontDisplay
                font.pixelSize: 15
                renderType: Text.NativeRendering
                color: ws.active ? Theme.textOnSeal : (ws.occupied ? Theme.text : Theme.textMuted)
                opacity: ws.active || ws.exists ? 1 : 0.35
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HyprlandState.go(ws.wid)
                onWheel: ev => { HyprlandState.cycle(ev.angleDelta.y > 0 ? -1 : 1); ev.accepted = true; }
            }
            BarTooltip {   // your title for this workspace (overworld ws)
                target: ws
                shown: area.containsMouse
                text: WorkspaceNotes.title(ws.wid).length > 0 ? ws.wid + " · " + WorkspaceNotes.title(ws.wid) : "Workspace " + ws.wid
            }
        }
    }
}
