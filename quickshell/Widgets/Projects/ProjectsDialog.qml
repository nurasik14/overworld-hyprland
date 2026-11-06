import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  ProjectsDialog — the add / edit screen of the Projects card (namespace overworld-projects).  A full-screen overlay like the brew
 *  dialog: dimmed world, a panel in the middle, the keyboard grabbed (Exclusive) while it is open, so typing works even though the
 *  widget layer itself never takes focus.  Opened by the card's "+", a double-click on a title, `overworld projects open`,
 *  `ipc call projects open|edit`; ProjectsService.dialogOpen / editId drive it.  The form is Projects/ProjectsForm.qml.
 *  Enter = add / save · Esc or a click outside = cancel.
 */
Variants {
    id: root
    model: Quickshell.screens
    property bool onlyFocusedScreen: true      // previews render on a headless output

    OverlayWindow {
        id: win
        required property var modelData
        screen: modelData
        namespace: "overworld-projects"
        onlyFocusedScreen: root.onlyFocusedScreen
        open: ProjectsService.dialogOpen
        onCloseRequested: ProjectsService.closeDialog()

        ProjectsForm {
            x: Math.round((parent.width - width) / 2 / Theme.gui) * Theme.gui
            y: Math.round((parent.height - height) / 2 / Theme.gui) * Theme.gui
            active: win.shown
            editId: ProjectsService.editId
            onDone: ProjectsService.closeDialog()
            onCancelled: ProjectsService.closeDialog()
        }
    }
}
