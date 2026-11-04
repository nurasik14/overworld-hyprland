import QtQuick
import Quickshell
import qs.Common
import qs.Services

/*  Hotbar — workspaces 1–9 in the real hud/hotbar sprite, workspace 10 in the offhand slot on the left, occupied special
 *  workspaces in the offhand slot on the right. Coordinates are the game's: item at slot + (3, 3), selection frame 24×23.
 *    each slot: the dominant app's item icon, stack count = windows, hover = tooltip (title, note, apps), click = switch, wheel = cycle
 *    signal switched(int id)   the focused workspace changed: the HUD shows the item name
 */
Item {
    id: root
    signal switched(int id)
    readonly property int g: Theme.gui
    readonly property int selectedId: HyprlandState.focusedId
    readonly property var special: HyprlandState.specials.length ? HyprlandState.specials[0] : null

    width: Theme.px(29 + 182 + 29)
    height: Theme.px(23)

    Connections {
        target: HyprlandState
        function onFocusedIdChanged() { if (HyprlandState.armed && root.selectedId >= 1 && root.selectedId <= 10) root.switched(root.selectedId); }
    }

    // ------------------------------------------------------------ sprites
    McSprite { x: 0; y: 0; sprite: "hud/hotbar_offhand_left" }
    McSprite { x: Theme.px(29); y: root.g; sprite: "hud/hotbar" }
    McSprite { visible: root.special !== null; x: Theme.px(29 + 182); y: 0; sprite: "hud/hotbar_offhand_right" }

    // ------------------------------------------------------------ slots 1–9 + offhand 10
    Repeater {
        model: 10
        HotbarSlot {
            required property int index
            wsId: index + 1
            x: index < 9 ? Theme.px(29 + 1 + index * 20) : 0
            y: root.g
            offhand: index === 9
        }
    }

    // ------------------------------------------------------------ the selection frame: snaps, never animates
    McSprite {
        visible: root.selectedId >= 1 && root.selectedId <= 10
        x: root.selectedId === 10 ? -root.g : Theme.px(29 - 1 + (root.selectedId - 1) * 20)
        y: 0
        sprite: "hud/hotbar_selection"
    }

    // ------------------------------------------------------------ special workspace: the other offhand
    Item {
        id: specialSlot
        visible: root.special !== null
        x: Theme.px(29 + 182)
        y: root.g
        width: Theme.px(29)
        height: Theme.px(22)
        readonly property bool active: root.special !== null && HyprlandState.activeSpecial === root.special.name
        McItemIcon {
            x: Theme.px(10); y: Theme.px(3)
            name: "ender_chest"
        }
        McText {
            visible: root.special !== null && root.special.count > 1
            text: root.special ? String(root.special.count) : ""
            color: Theme.hudText
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(2)
            y: Theme.px(11)
        }
        McSprite {
            visible: specialSlot.active
            x: Theme.px(6); y: -root.g
            sprite: "hud/hotbar_selection"
        }
        MouseArea {
            id: specialArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (root.special) HyprlandState.toggleSpecial(root.special.name)
        }
        Loader {
            active: specialArea.containsMouse && root.special !== null
            sourceComponent: McTooltip {
                title: "Ender Chest"
                description: HyprlandState.specials.map(s => (s.name.replace(/^special:?/, "") || "special") + ": " + s.count + " window" + (s.count === 1 ? "" : "s")).join("\n")
                category: "Special workspace"
                target: specialArea
                targetX: specialArea.mouseX
                targetY: specialArea.mouseY
            }
        }
    }
    // Scrolling anywhere on the bar cycles the slots.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => HyprlandState.cycle(event.angleDelta.y > 0 ? -1 : 1)
    }

    component HotbarSlot: Item {
        id: slot
        property int wsId: 1
        property bool offhand: false
        readonly property var info: HyprlandState.info(wsId)
        width: Theme.px(offhand ? 22 : 20)
        height: Theme.px(22)
        Accessible.role: Accessible.Button
        Accessible.name: "Workspace " + wsId + (root.selectedId === wsId ? " (active)" : "")

        McItemIcon {
            visible: slot.info.count > 0
            x: Theme.px(slot.offhand ? 3 : 2); y: Theme.px(3)
            name: slot.info.item
        }
        Rectangle {   // the game's slot highlight
            x: Theme.px(slot.offhand ? 3 : 2); y: Theme.px(3)
            width: Theme.px(16); height: Theme.px(16)
            color: Theme.slotHover
            visible: area.containsMouse
        }
        McText {
            visible: slot.info.count > 1
            text: String(slot.info.count)
            color: Theme.hudText
            x: Theme.px(slot.offhand ? 3 : 2) + Theme.px(17) - implicitWidth
            y: Theme.px(11)
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: HyprlandState.go(slot.wsId)
        }
        Loader {
            active: area.containsMouse
            sourceComponent: McTooltip {
                id: slotTip
                readonly property string note: WorkspaceNotes.note(slot.wsId)
                title: WorkspaceNotes.displayTitle(slot.wsId) + (WorkspaceNotes.isAuto(slot.wsId) ? " (auto)" : "")
                description: note
                lines: slot.info.count > 0
                    ? slot.info.apps.map(a => "§7" + (a.cls.length ? a.cls : a.item) + (a.count > 1 ? " ×" + a.count : ""))
                    : ["§8Empty"]
                category: slot.wsId === 10 ? "Offhand · Workspace 10" : "Workspace " + slot.wsId
                maxWidth: 180
                target: area
                targetX: area.mouseX
                targetY: Theme.px(10) - slotTip.height + 2 * slotTip.margin   // sits above the hotbar instead of over the slots
            }
        }
    }
}
