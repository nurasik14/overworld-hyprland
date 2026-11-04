import QtQuick
import qs.Common as Common

/*  DEPRECATED: use the `title` of McPanel.  title + subtitle in the GUI title style on a flat strip.
 *  dots, showSeal, sealGlyph, compact: ignored, kept for callers.
 */
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool dots: false
    property bool showSeal: false
    property string sealGlyph: ""
    property bool compact: false
    property alias titleItem: titleText

    implicitHeight: Common.Theme.px(14)
    color: "transparent"
    Accessible.role: Accessible.Heading
    Accessible.name: subtitle.length ? (title + " " + subtitle) : title

    Common.McText {
        id: titleText
        anchors.verticalCenter: parent.verticalCenter
        x: Common.Theme.px(8)
        width: parent.width - Common.Theme.px(16)
        text: root.title + (root.title.length && root.subtitle.length ? " · " : "") + root.subtitle
        guiTitle: true
        elide: Text.ElideRight
    }
}
