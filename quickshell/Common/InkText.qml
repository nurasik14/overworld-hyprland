import QtQuick
import qs.Common as Common

/*  InkText — Text with a type role from tokens.shared.type.roles.
 *  role: display | display_sm | title | subtitle | body | body_latin | ui | small | mono | clock_bar | weather_temp | quote_lock …
 *  muted: use Theme.textMuted.  Colour defaults to Theme.text; override `color` freely.
 *  CJK brush roles automatically switch to the JP brush family when the text contains kana / 薬 / 宮.
 */
Text {
    id: root
    property string role: "body"
    property bool muted: false
    readonly property var spec: Common.Theme.fontFor(role)

    font.family: (role === "display" || role === "display_sm") ? Common.Theme.brushFamilyFor(text) : spec.family
    font.pixelSize: spec.pixelSize
    font.weight: spec.weight
    font.italic: spec.italic
    font.letterSpacing: spec.letterSpacing * spec.pixelSize
    color: muted ? Common.Theme.textMuted : Common.Theme.text
    renderType: Text.NativeRendering
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: Common.Theme.durTheme; easing.type: Easing.OutCubic } }
}
