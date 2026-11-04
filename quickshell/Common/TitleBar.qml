import QtQuick
import qs.Common as Common

/*  TitleBar — the lacquer/ink strip across the top of a PaperPanel (reference: qxb3 "ink" cards).
 *  title:    CJK title (ZCOOL XiaoWei), e.g. "天气"
 *  subtitle: Latin meaning (Cormorant Garamond, letter-spaced caps), e.g. "Weather" — never omit it when the title is CJK.
 *  dots:     two ghost squares + the seal at the right (the reference's three window dots, re-read as a seal)
 *  sealGlyph / showSeal
 *  Height 28 px. Colours: Theme.titlebar / Theme.titlebarText.
 */
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool dots: true
    property bool showSeal: true
    property string sealGlyph: "印"
    property bool compact: false       // 22 px variant for small cards / rows
    property alias titleItem: titleText

    implicitHeight: compact ? 22 : (Common.Theme.sizes.titlebar_height || 28)
    color: Common.Theme.titlebar
    Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
    Accessible.role: Accessible.Heading
    Accessible.name: subtitle.length ? (title + " — " + subtitle) : title

    Rectangle {   // bottom rule: separates the bar from a lacquer surface in dark mode (invisible on paper)
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 1
        color: Common.Theme.titlebarText
        opacity: Common.Theme.isDark ? 0.28 : 0.0
        Behavior on opacity { NumberAnimation { duration: Common.Theme.durTheme } }
    }

    Row {
        anchors.centerIn: parent
        spacing: Common.Theme.space.sm
        Text {
            id: titleText
            text: root.title
            color: Common.Theme.titlebarText
            font.family: Common.Theme.fontTitle
            font.pixelSize: root.compact ? 14 : Common.Theme.fontFor("title").pixelSize
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
        }
        Rectangle {   // tiny vertical hairline between CJK and Latin
            visible: root.title.length > 0 && root.subtitle.length > 0
            width: 1; height: root.compact ? 10 : 12
            color: Common.Theme.titlebarText; opacity: 0.35
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Common.Theme.titlebarText
            opacity: 0.9
            font.family: Common.Theme.fontSerif
            font.pixelSize: root.compact ? 12 : Common.Theme.fontFor("subtitle").pixelSize
            font.weight: 600
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Common.Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Repeater {
            model: root.dots ? 2 : 0
            Rectangle {
                width: root.compact ? 7 : 9; height: width
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.width: 1
                border.color: Common.Theme.titlebarText
                opacity: 0.4
                radius: 1
            }
        }
        Common.Seal {
            visible: root.showSeal
            size: root.compact ? 12 : (Common.Theme.sizes.seal_small || 14)
            glyph: root.sealGlyph
            label: root.subtitle
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
