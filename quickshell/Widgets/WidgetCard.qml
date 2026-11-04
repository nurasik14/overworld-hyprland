import QtQuick
import qs.Common
import qs.Widgets.Services

/*  WidgetCard — a PaperPanel placed on the desktop layer that follows WidgetsState.visible.
 *  Show / hide: opacity 0↔1 + 10 px rise, 450 ms OutQuint (`ink`), staggered 40 ms per `index`
 *  (reading order of the layout). Reduced motion (config.json) → no delay, no translate, 0 ms.
 *  `shown` may be overridden (previews); `index` is the stagger slot.
 *  Drag by the title bar to move the card (saved per `cardId` in WidgetsState; previews leave cardId "").
 */
PaperPanel {
    id: card
    property int index: 0
    property bool shown: WidgetsState.visible && (cardId === "" || WidgetsState.cardOn(cardId))
    fillOpacity: cardId === "" ? -1 : WidgetsState.cardOpacity
    shadowEnabled: fillOpacity < 0 || fillOpacity >= 0.85   // a blurred shadow would smudge through a see-through card
    readonly property bool reduced: ApoConfig.reducedMotion
    readonly property int delay: reduced ? 0 : index * Theme.stagger
    readonly property int duration: reduced ? 0 : 450
    property real rise: shown ? 0 : (reduced ? 0 : 10)

    // ---- position: saved (dragged) position, else the layout slot
    property string cardId: ""
    property real defaultX: 0
    property real defaultY: 0
    function bindPosition() {
        card.x = Qt.binding(() => WidgetsState.posX(card.cardId, card.defaultX));
        card.y = Qt.binding(() => WidgetsState.posY(card.cardId, card.defaultY));
    }
    Component.onCompleted: if (cardId !== "") bindPosition()
    Connections {
        target: WidgetsState
        function onLayoutReset() { if (card.cardId !== "") card.bindPosition() }
    }

    // drag handle = exactly the lacquer title bar. `parent: card` is required: PaperPanel's default property
    // sends declared children into the padded content area (that put the handle in an invisible strip
    // ~45 px down the card).
    Item {
        parent: card
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: card.hasTitle ? card.titleBar.implicitHeight + card.frameWidth : 30
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
            NumberAnimation { duration: card.duration; easing.type: Easing.OutQuint }
        }
    }
    Behavior on rise {
        SequentialAnimation {
            PauseAnimation { duration: card.delay }
            NumberAnimation { duration: card.duration; easing.type: Easing.OutQuint }
        }
    }
}
