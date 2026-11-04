import QtQuick
import qs.Common
import qs.Widgets.Services

/*  WidgetCard — a McPanel (GUI panel with the dark-grey title, see-through centre) placed on the desktop layer.
 *    guiW, guiH     size in GUI px (multiples of the GUI scale keep the bevel crisp)
 *    index          stagger slot: fade-in starts 40 ms × index after the layer appears
 *    cardId         saved position key; "" (previews) disables dragging and the saved position
 *    defaultX/Y     the layout slot; double-click the title bar or `widgets layout` returns the card there
 *    shown          follows WidgetsState.visible + the per-card switch
 *  Show / hide: opacity fade + a 4 GUI px rise, 250 ms OutQuad, staggered.  Reduced motion → instant.
 *  Drag by the title bar (the top 17 GUI px).  The centre fill is Theme.widgetOpacity (config widgets.opacity);
 *  bevels, text and icons stay opaque.
 */
McPanel {
    id: card
    property int guiW: 160
    property int guiH: 100
    property int index: 0
    property string cardId: ""
    property real defaultX: 0
    property real defaultY: 0
    property bool shown: WidgetsState.visible && (cardId === "" || WidgetsState.cardOn(cardId))

    // content area (cards lay out in GUI px inside it): the panel minus 7 px margins, 17 px title row = (guiW − 14) × (guiH − 24)

    width: Theme.px(guiW)
    height: Theme.px(guiH)
    fillOpacity: cardId === "" ? -1 : WidgetsState.cardOpacity

    readonly property bool reduced: Theme.reducedMotion
    readonly property int delay: reduced ? 0 : index * 40
    readonly property int duration: Theme.ms(250)
    property real rise: shown ? 0 : (reduced ? 0 : Theme.px(4))

    // ---- position: saved (dragged) position, else the layout slot
    function bindPosition() {
        card.x = Qt.binding(() => WidgetsState.posX(card.cardId, card.defaultX));
        card.y = Qt.binding(() => WidgetsState.posY(card.cardId, card.defaultY));
    }
    Component.onCompleted: if (cardId !== "") bindPosition()
    Connections {
        target: WidgetsState
        function onLayoutReset() { if (card.cardId !== "") card.bindPosition() }
    }

    // drag handle = the title bar. `parent: card` keeps it out of McPanel's padded content area.
    Item {
        parent: card
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Theme.px(17)
        z: 100
        enabled: card.cardId !== ""
        HoverHandler { cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
        DragHandler {
            id: drag
            target: card
            xAxis.minimum: 0
            xAxis.maximum: (card.parent ? card.parent.width : 1920) - card.width
            yAxis.minimum: 0
            yAxis.maximum: (card.parent ? card.parent.height : 1080) - card.height
            dragThreshold: 2
            onActiveChanged: {
                WidgetsState.dragging = active;
                if (!active) WidgetsState.setPos(card.cardId, card.x, card.y);
            }
        }
        TapHandler {   // double-click the title bar: back to the layout slot
            onDoubleTapped: WidgetsState.resetPos(card.cardId)
        }
    }

    opacity: shown ? 1 : 0
    visible: opacity > 0.001
    transform: Translate { y: card.rise }

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: card.delay }
            NumberAnimation { duration: card.duration; easing.type: Easing.OutQuad }
        }
    }
    Behavior on rise {
        SequentialAnimation {
            PauseAnimation { duration: card.delay }
            NumberAnimation { duration: card.duration; easing.type: Easing.OutQuad }
        }
    }
}
