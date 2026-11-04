import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

/*  FxLayer — one transparent, click-through, full-output overlay (namespace overworld-break, Overlay layer) that hosts the
 *  effects registered in InteractFx: crack textures over a mined window, break particles, place dust, XP orbs, the pickup pop.
 *  It is mapped only while an effect exists (plus a short tail), so an idle shell has no overlay surface at all.
 */
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property int myIndex: Quickshell.screens.indexOf(modelData)
    readonly property bool wanted: InteractFx.count > 0

    WlrLayershell.namespace: "overworld-break"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}          // no input region: clicks fall through to whatever is below
    visible: false

    onWantedChanged: {
        if (wanted) { unmap.stop(); visible = true; }
        else unmap.restart();
    }
    Timer { id: unmap; interval: 120; onTriggered: if (!win.wanted) win.visible = false }

    Repeater {
        model: InteractFx.model
        delegate: Item {
            id: fx
            required property int eid
            required property string kind
            required property int gx
            required property int gy
            required property int gw
            required property int gh
            required property int stage
            readonly property bool mine: InteractFx.screenFor({ x: gx, y: gy, w: gw, h: gh }) === win.myIndex
            readonly property var fxData: InteractFx.payload(eid)
            visible: mine
            x: gx - win.modelData.x
            y: gy - win.modelData.y
            width: gw
            height: gh

            Loader {
                anchors.fill: parent
                active: fx.mine
                sourceComponent: fx.kind === "mine" ? mineC : fx.kind === "burst" || fx.kind === "dust" ? burstC
                               : fx.kind === "orbs" ? orbsC : fx.kind === "pickup" ? pickupC : null
            }
            Component {
                id: mineC
                MineOverlay { stage: fx.stage }
            }
            Component {
                id: burstC
                FragmentBurst {
                    mode: fx.kind === "dust" ? "dust" : "break"
                    palette: fx.fxData.palette || []
                    count: fx.fxData.count || 40
                    onFinished: InteractFx.remove(fx.eid)
                }
            }
            Component {
                id: orbsC
                XpOrbs {
                    level: fx.fxData.level || 0
                    count: fx.fxData.count || 14
                    onFinished: InteractFx.remove(fx.eid)
                }
            }
            Component {
                id: pickupC
                PickupFx {
                    item: fx.fxData.item || "filled_map"
                    onFinished: InteractFx.remove(fx.eid)
                }
            }
        }
    }
}
