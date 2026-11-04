import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  HerbCard — 药 · HERB OF THE DAY (380 × 220).  HerbService picks herbs[dayOfYear % n].
 *  name_cjk (brush), name_en + reading, kind badge (草 herb = success · 毒 poison = seal · both = both),
 *  fact, Maomao's note (EB Garamond italic, 猫 seal), and the ink plate tinted with Theme.text
 *  (MultiEffect colorization) — the image column collapses when `plate` is null or the file is missing.
 *  Click → next herb.
 */
WidgetCard {
    id: card
    title: "药"
    subtitle: "Herb of the day"
    sealGlyph: "药"
    width: 380
    height: 220
    padding: 14

    readonly property var svc: HerbService
    readonly property bool isPoison: svc.kind === "poison"
    readonly property bool isBoth: svc.kind === "both"
    readonly property bool hasPlate: svc.plateUrl.length > 0 && plate.status === Image.Ready
    readonly property int plateW: 96

    // ---- plate (black-ink RGBA mask → tinted with the text colour)
    Item {
        id: plateBox
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: card.hasPlate ? card.plateW : 0
        visible: card.hasPlate
        Image {
            id: plate
            anchors.fill: parent
            source: card.svc.plateUrl
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(256, 384)
            asynchronous: true
            smooth: true; mipmap: true
            visible: false
        }
        MultiEffect {
            source: plate
            anchors.fill: plate
            visible: card.hasPlate
            colorization: 1.0
            colorizationColor: Theme.text
            opacity: 0.9
        }
    }

    Column {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.right: plateBox.left
        anchors.rightMargin: card.hasPlate ? Theme.space.sm : 0
        spacing: 2

        Row {   // CJK name + kind badge
            spacing: Theme.space.sm
            width: parent.width
            Text {
                id: cjkName
                text: card.svc.nameCjk
                color: Theme.text
                font.family: Theme.brushFamilyFor(card.svc.nameCjk)
                font.pixelSize: card.svc.nameCjk.length > 7 ? 24 : 30
                width: Math.min(implicitWidth, parent.width - badge.width - Theme.space.sm)
                elide: Text.ElideRight
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
            Row {
                id: badge
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                Seal { visible: !card.isPoison; size: 18; glyph: "草"; label: "herb"; color: Theme.success; outline: false }
                Seal { visible: card.isPoison || card.isBoth; size: 18; glyph: "毒"; label: "poison"; color: Theme.seal; outline: false }
            }
        }
        Row {
            spacing: Theme.space.sm
            width: parent.width
            InkText { role: "title"; font.pixelSize: 15; text: card.svc.nameEn; width: Math.min(implicitWidth, parent.width); elide: Text.ElideRight }
        }
        InkText {
            role: "small"; muted: true
            text: card.svc.reading + (card.isBoth ? "  · herb and poison" : card.isPoison ? "  · poison" : "  · herb")
            width: parent.width
            elide: Text.ElideRight
        }
        Item { width: 1; height: 2 }
        InkText {
            role: "body"
            font.pixelSize: 12
            text: card.svc.fact
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 1.1
        }
        Item { width: 1; height: 2 }
        Row {
            width: parent.width
            spacing: 6
            Seal { size: 14; glyph: "猫"; label: "Maomao"; anchors.top: parent.top; anchors.topMargin: 2 }
            Text {
                text: card.svc.note
                color: Theme.textMuted
                font.family: Theme.fontSerifBody
                font.italic: true
                font.pixelSize: 13
                width: parent.width - 20
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 1.1
                renderType: Text.NativeRendering
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => { if (mouse.button === Qt.RightButton) card.svc.previous(); else card.svc.next() }
        Accessible.role: Accessible.Button
        Accessible.name: "Next herb"
    }
}
