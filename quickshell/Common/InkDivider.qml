import QtQuick
import qs.Common as Common

/*  DEPRECATED: use McDivider.  brush: true used the header separator tile; horizontal by default, vertical: true for a column rule.
 *  brushOpacity is kept for callers and applies to the whole divider.
 */
Common.McDivider {
    property bool brush: false
    property real brushOpacity: 1
    variant: brush && !vertical ? "header" : "bevel"
    opacity: brush ? brushOpacity : 1
    implicitWidth: vertical ? Common.Theme.px(2) : 200
    implicitHeight: vertical ? 200 : Common.Theme.px(2)
}
