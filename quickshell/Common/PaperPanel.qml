import QtQuick
import qs.Common as Common

/*  DEPRECATED: use McPanel.  Legacy API on top of it: title, subtitle (preferred when set: legacy titles were CJK), padding,
 *  transparent (widget opacity), fillOpacity (< 0 = default), content/contentItem, titleBar.implicitHeight, frameWidth, hasTitle.
 *  showSeal, dots, sealGlyph, shadowEnabled, hairline, titleCompact, radius: ignored, kept for callers.
 */
Common.McPanel {
    id: root
    property string subtitle: ""
    property bool transparent: false
    property bool showSeal: false
    property bool dots: false
    property string sealGlyph: ""
    property bool shadowEnabled: false
    property bool hairline: false
    property bool titleCompact: false
    property real radius: 0
    readonly property int frameWidth: Common.Theme.gui * 3
    readonly property bool hasTitle: title.length > 0 || subtitle.length > 0
    readonly property QtObject titleBar: QtObject { readonly property int implicitHeight: Common.Theme.px(14) }

    fillOpacity: transparent ? Common.Theme.cardTransparentOpacity : 1
    padding: Common.Theme.sizes.card_padding || 14
    implicitWidth: 320
    implicitHeight: 200
    Binding { target: root.titleItem; property: "text"; value: root.subtitle.length ? root.subtitle : root.title }
    Binding { target: root.titleItem; property: "visible"; value: root.hasTitle }
}
