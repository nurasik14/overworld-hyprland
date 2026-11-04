import QtQuick
import qs.Common as Common

/*  DEPRECATED: use McText.  Legacy role-based text, now Minecraft type.
 *  role: display | display_sm | title | subtitle | body | body_latin | ui | small | mono | clock_bar | weather_temp | quote_lock …
 *  muted: use Theme.textMuted.  Colour defaults to Theme.text; override `color` freely.
 */
Common.McText {
    id: root
    property string role: "body"
    property bool muted: false
    readonly property var spec: Common.Theme.fontFor(role)

    font.family: spec.family
    font.pixelSize: spec.pixelSize
    font.weight: spec.weight
    font.italic: spec.italic
    color: muted ? Common.Theme.textMuted : Common.Theme.text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
