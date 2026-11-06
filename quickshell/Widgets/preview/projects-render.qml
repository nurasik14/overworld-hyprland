//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Widgets
import qs.Widgets.Projects
import qs.Widgets.Services

/*  Offscreen render of the Projects card or its dialog (no compositor, nothing live is touched):
 *      OW_PROJECTS=<temp json> OW_RENDER_OUT=/tmp/x.png OW_RENDER_WHAT=card|dialog|edit|undo [OW_RENDER_PIN=<row>] [OW_RENDER_FOLD=1]
 *      OW_MODE=light|dark OW_WIDGETS_OPACITY=0.72 HOME=<temp home> QT_QPA_PLATFORM=offscreen qs -p quickshell/Widgets/preview/projects-render.qml
 *  The backdrop is a flat green-grey (or OW_RENDER_BG).  For `dialog`/`edit` the dim of the overlay is drawn behind the panel.
 */
ShellRoot {
    id: root
    readonly property string what: Quickshell.env("OW_RENDER_WHAT") || "card"
    Window {
        id: win
        width: what === "card" || what === "undo" ? 460 : 640
        height: what === "card" || what === "undo" ? 380 : 360
        visible: true
        color: "#4E6B45"
        Rectangle { anchors.fill: parent; color: "#4E6B45" }
        Image {
            anchors.fill: parent
            source: Quickshell.env("OW_RENDER_BG") ? "file://" + Quickshell.env("OW_RENDER_BG") : ""
            fillMode: Image.PreserveAspectCrop
        }
        Item {
            id: stage
            anchors.fill: parent
            ProjectsCard {
                id: card
                visible: root.what === "card" || root.what === "undo"
                cardId: "projects"
                x: 20; y: 12
                defaultX: 20; defaultY: 12
                pinHover: parseInt(Quickshell.env("OW_RENDER_PIN") || "-1")
                pinTip: Quickshell.env("OW_RENDER_TIP") === "1"
                builtOpen: Quickshell.env("OW_RENDER_FOLD") !== "1"
                builtAll: Quickshell.env("OW_RENDER_ALL") === "1"
            }
            Rectangle {
                anchors.fill: parent
                visible: root.what === "dialog" || root.what === "edit"
                color: "#c0101010"
            }
            ProjectsForm {
                visible: root.what === "dialog" || root.what === "edit"
                anchors.centerIn: parent
                active: visible
                editId: root.what === "edit" && ProjectsService.ordered.length > parseInt(Quickshell.env("OW_RENDER_EDIT") || "0") ? ProjectsService.ordered[parseInt(Quickshell.env("OW_RENDER_EDIT") || "0")].id : ""
            }
        }
        Timer {
            interval: 1500
            running: root.what !== "act"
            onTriggered: {
                if (root.what === "undo") { ProjectsService.remove(ProjectsService.items[1].id); undoShot.start(); return; }
                if (root.what === "dialog" && Quickshell.env("OW_RENDER_TYPE")) {
                    // pretend the user typed something
                }
                win.shoot();
            }
        }
        Timer { id: undoShot; interval: 900; onTriggered: win.shoot() }
        // OW_RENDER_WHAT=act: no picture; drives the card's own handlers (what a click on the box / ✕ / Undo ends in) and checks the result
        property int actStep: 0
        function pass(n, ok, x) { console.warn((ok ? "PASS " : "FAIL ") + n + (x !== undefined ? "  [" + x + "]" : "")); }
        Timer {
            id: actTimer; interval: 1100; running: root.what === "act"; repeat: true
            onTriggered: {
                const P = ProjectsService;
                if (win.actStep === 0) { win.pass("card shows the list", P.items.length === 7 && card.svc.inProgress.length === 4); card.toggleItem(P.inProgress[0]); }
                else if (win.actStep === 1) { win.pass("click on the box (toggleItem) → built, 5 built / 3 in progress", P.built.length === 4 && P.inProgress.length === 3, P.built.length + "/" + P.inProgress.length); card.toggleItem(P.built[0]); }
                else if (win.actStep === 2) { win.pass("click again → back in progress", P.inProgress.length === 4); card.removeItem(P.inProgress[0]); }
                else if (win.actStep === 3) { win.pass("✕ (removeItem) removes and offers undo", P.items.length === 6 && P.undo !== null && card.svc.undo.title.length > 0); P.undoRemove(); }
                else if (win.actStep === 4) { win.pass("Undo button (undoRemove) restores it", P.items.length === 7 && P.undo === null); card.builtAll = true; }
                else if (win.actStep === 5) { win.pass("+N more row only with > 5 built", card.hiddenBuilt === 0 && card.builtShown === P.built.length);
                    card.svc.openDialog(""); win.pass("+ button path (openDialog) sets dialogOpen", P.dialogOpen && P.editId === ""); card.svc.closeDialog(); Qt.quit(); }
                win.actStep++;
            }
        }
        function shoot() {
            win.contentItem.grabToImage(function (r) {
                const out = Quickshell.env("OW_RENDER_OUT") || "/tmp/ow-projects.png";
                console.warn("render: saved", r.saveToFile(out), out);
                Qt.quit();
            });
        }
    }
}
