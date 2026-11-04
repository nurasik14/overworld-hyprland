import QtQuick
import qs.Common as Common

/*  DEPRECATED: use McItemIcon.  The old stamp is now a redstone dust icon; legacy `size` is in screen px here, GUI px on McItemIcon.
 *  label kept; glyph, rough, outline, color, glyphColor ignored, kept for callers.
 */
Common.McItemIcon {
    property string glyph: ""
    property bool rough: false
    property bool outline: false
    property string label: ""
    property color color: Common.Theme.seal
    property color glyphColor: Common.Theme.textOnSeal
    name: "redstone"
    implicitWidth: size
    implicitHeight: size
    Accessible.role: Accessible.Graphic
    Accessible.name: label
}
