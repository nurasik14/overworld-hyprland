//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.Services
import qs.Widgets
import qs.Brew

/*  Brew dialog + widget preview on one output (default: a headless one, so the real desktop is untouched):
 *      hyprctl output create headless BREWTEST
 *      source scripts/dev-env.sh && BREW_PREVIEW_OUTPUT=BREWTEST qs -p quickshell/Brew/preview
 *      qs -p quickshell/Brew/preview ipc call brew open ;  grim -o BREWTEST shot.png
 *      hyprctl output remove BREWTEST
 */
ShellRoot {
    id: root
    readonly property var target: Quickshell.screens.filter(s => s.name === (Quickshell.env("BREW_PREVIEW_OUTPUT") || "BREWTEST"))
    DesktopWidgets { model: root.target }
    BrewDialog { model: root.target; onlyFocusedScreen: false }
}
