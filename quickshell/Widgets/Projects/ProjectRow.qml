import QtQuick
import qs.Common
import qs.Widgets.Services

/*  ProjectRow — one project on the card: checkbox · title (elided) · ✕ (appears on hover).  13 GUI px high.
 *    item: the ProjectsService item        width: from the list
 *    click the box = toggle · double-click the title = edit (dialog) · ✕ = remove (the card then offers Undo for 5 s)
 *    hover (after 0.4 s) = the game's tooltip: full title, the note, added / built dates
 *    signals toggled(item), removeRequested(item), editRequested(item)
 */
Item {
    id: row
    property var item: null
    readonly property bool built: item ? item.status === "built" : false
    property bool hoverPin: false          // previews only: draw the hover state without a pointer
    property bool tipPin: false            // previews only: …and the tooltip
    readonly property bool hovered: hh.hovered || hoverPin
    signal toggled(var item)
    signal removeRequested(var item)
    signal editRequested(var item)

    height: Theme.px(13)

    function dateOf(iso) { const d = new Date(iso); return isNaN(d.getTime()) ? "" : Qt.formatDate(d, "d MMM yyyy"); }
    function daysBetween(a, b) { const x = new Date(a), y = new Date(b); return isNaN(x.getTime()) || isNaN(y.getTime()) ? -1 : Math.round((y - x) / 86400000); }
    readonly property var tipLines: {
        if (!item) return [];
        const out = [];
        if (item.created) out.push("§8Added " + dateOf(item.created));
        if (built && item.built_at) {
            const d = daysBetween(item.created, item.built_at);
            out.push("§aBuilt " + dateOf(item.built_at) + (d > 0 ? " · took " + d + (d === 1 ? " day" : " days") : ""));
        }
        out.push("§8Double-click to edit");
        return out;
    }

    HoverHandler { id: hh }
    Rectangle {   // hover wash
        anchors.fill: parent
        anchors.leftMargin: -Theme.gui; anchors.rightMargin: -Theme.gui
        color: Theme.inkWash
        opacity: row.hovered ? 0.55 : 0
    }

    ProjectBox {
        id: box
        x: 0; y: Theme.gui
        checked: row.built
        highlighted: row.hovered
        onClicked: row.toggled(row.item)
    }
    McText {
        id: label
        x: Theme.px(15); y: 0
        width: row.width - Theme.px(15) - Theme.px(13)
        height: row.height
        verticalAlignment: Text.AlignVCenter
        text: row.item ? row.item.title : ""
        color: row.built ? Theme.textMuted : Theme.guiText
        font.strikeout: row.built
        elide: Text.ElideRight
        MouseArea {
            anchors.fill: parent
            onDoubleClicked: row.editRequested(row.item)
        }
    }
    Item {   // ✕
        id: cross
        anchors.right: parent.right
        y: Theme.gui
        width: Theme.px(11); height: Theme.px(11)
        opacity: row.hovered ? 1 : 0
        PixelGlyph {
            anchors.centerIn: parent
            kind: "cross"
            color: crossArea.containsMouse ? Theme.chatReadable("c") : Theme.textMuted
        }
        MouseArea {
            id: crossArea
            anchors.fill: parent
            enabled: row.hovered
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.removeRequested(row.item)
        }
    }

    // tooltip
    property bool tipOn: false
    Timer { id: tipTimer; interval: 400; running: hh.hovered || row.tipPin; onTriggered: row.tipOn = true }
    onHoveredChanged: if (!hovered && !tipPin) tipOn = false
    Loader {
        active: row.tipOn && row.item !== null
        sourceComponent: McTooltip {
            title: row.item.title
            description: row.item.note || ""
            category: row.built ? "Built" : "In progress"
            lines: row.tipLines
            target: row
            targetX: hh.hovered ? hh.point.position.x : row.width / 2
            targetY: hh.hovered ? hh.point.position.y : row.height / 2
        }
    }
}
