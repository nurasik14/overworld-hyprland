import QtQuick
import qs.Common

/*  HudSlot — one inventory slot on the HUD's flanks: McSlot plus the wheel and the middle button.
 *    Everything McSlot has, plus signals wheelMoved(int delta) and middleClicked().
 */
McSlot {
    id: root
    signal wheelMoved(int delta)
    signal middleClicked()
    soundId: "ui.click"

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.wheelMoved(event.angleDelta.y > 0 ? 1 : -1)
    }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        gesturePolicy: TapHandler.WithinBounds
        onTapped: root.middleClicked()
    }
}
