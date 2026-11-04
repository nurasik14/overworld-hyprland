//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.Widgets

/*  Widget-layer preview.  Run from the repo root:
 *      source scripts/dev-env.sh && qs -p quickshell/Widgets/preview
 *  `Common` → ../../Common and `Widgets` → .. are symlinks inside this directory, so `import qs.Common`,
 *  `import qs.Widgets` and `import qs.Widgets.Services` resolve exactly as in the real shell (config root =
 *  quickshell/).  The Theme singleton finds the repo via shellDir/../../.. (see docs/DESIGN.md §12).
 *  Everything else (IPC targets `widgets`, `brew`) works the same:  qs -p … ipc call widgets toggle
 */
ShellRoot {
    DesktopWidgets {}
}
