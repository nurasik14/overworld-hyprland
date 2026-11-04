import QtQuick
import QtQuick.Effects
import qs.Common as Common

/*  PaperPanel — the framed desktop card (reference: qxb3 "ink" cards, made Overworld).
 *
 *  Anatomy (outside → inside):
 *    soft shadow (blurred rect, Theme.shadow, y+4 blur 12)
 *    fill: Theme.surface @ surfaceOpacity (0.88: the wallpaper shows faintly) + tile  ← transparent: surface @ 0.82, no tile
 *    2 px frame  Theme.frame, radius md (8)
 *    1 px hairline inset 4 px, radius md-3                                         ← the scroll-mount double rule
 *    TitleBar (28 px) when title != ""                                              ← lacquer bar, CJK title · LATIN, seal
 *    content: default property, padded by `padding` (16)
 *
 *  Properties: title, subtitle, padding, transparent, showSeal, sealGlyph, dots, shadowEnabled, titleCompact
 *  Content children go inside `contentItem` (default property).  Size the panel explicitly (width/height) —
 *  it never grows from its content (desktop cards have fixed slots).
 */
Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property int padding: Common.Theme.sizes.card_padding || 16
    property bool transparent: false
    property bool showSeal: true
    property bool dots: true
    property string sealGlyph: "印"
    property bool shadowEnabled: true
    property bool hairline: true
    property bool titleCompact: false
    property real fillOpacity: -1          // < 0 = Theme.surfaceOpacity (desktop widgets pass their own)
    property real radius: Common.Theme.radius.md
    readonly property int frameWidth: Common.Theme.border.frame
    readonly property bool hasTitle: title.length > 0 || subtitle.length > 0
    readonly property alias titleBar: bar
    default property alias content: contentItem.data
    property alias contentItem: contentItem

    implicitWidth: 320
    implicitHeight: 200

    // ---- shadow: a blurred copy of a plain rounded rect, drawn behind the card (the card stays interactive)
    Rectangle {
        id: shadowSource
        anchors.fill: parent
        radius: root.radius
        color: Common.Theme.shadow
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        visible: root.shadowEnabled
        source: shadowSource
        anchors.fill: shadowSource
        anchors.topMargin: (Common.Theme.shadowSpec.card || {}).y || 4
        blurEnabled: true
        blur: 1.0
        blurMax: 24
        blurMultiplier: 0.6
        autoPaddingEnabled: true
        Behavior on opacity { NumberAnimation { duration: Common.Theme.durBase } }
    }

    // ---- fill
    Rectangle {
        id: fill
        anchors.fill: parent
        radius: root.radius
        color: Common.Theme.withAlpha(Common.Theme.surface, root.transparent ? Math.min(Common.Theme.cardTransparentOpacity, root.fillOpacity < 0 ? 1 : root.fillOpacity) : (root.fillOpacity < 0 ? Common.Theme.surfaceOpacity : root.fillOpacity))
        Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
    }
    Item {   // texture, inset inside the frame so the square corners hide under the 2 px border
        anchors.fill: parent
        anchors.margins: root.frameWidth
        clip: true
        visible: !root.transparent
        Image {
            anchors.fill: parent
            source: Common.Theme.texture("ground-tile")
            fillMode: Image.Tile
            opacity: Common.Theme.textureOpacity * (root.fillOpacity < 0 ? Common.Theme.surfaceOpacity : root.fillOpacity)
            smooth: false
            cache: true
            asynchronous: true
        }
    }

    // ---- title bar (top corners follow the outer radius)
    Item {
        id: barClip
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: root.frameWidth
        height: root.hasTitle ? bar.implicitHeight : 0
        clip: true
        visible: root.hasTitle
        Common.TitleBar {
            id: bar
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: implicitHeight + root.radius     // extra height is clipped: only the top corners stay round
            radius: Math.max(0, root.radius - root.frameWidth)
            title: root.title
            subtitle: root.subtitle
            showSeal: root.showSeal
            dots: root.dots
            sealGlyph: root.sealGlyph
            compact: root.titleCompact
        }
    }

    // ---- content
    Item {
        id: contentItem
        anchors.fill: parent
        anchors.topMargin: (root.hasTitle ? barClip.height + root.frameWidth : 0) + root.padding
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: root.padding
    }

    // ---- frame + hairline, drawn last so they sit above texture and content edges
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root.frameWidth
        border.color: Common.Theme.frame
        Behavior on border.color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        visible: root.hairline
        anchors.fill: parent
        anchors.margins: Common.Theme.sizes.hairline_inset || 4
        anchors.topMargin: (root.hasTitle ? barClip.height + root.frameWidth : 0) + (Common.Theme.sizes.hairline_inset || 4) - (root.hasTitle ? 2 : 0)
        radius: Math.max(2, root.radius - 3)
        color: "transparent"
        border.width: Common.Theme.border.hairline
        border.color: Common.Theme.hairline
        opacity: root.transparent ? 0.6 : 1
        Behavior on border.color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
    }
}
