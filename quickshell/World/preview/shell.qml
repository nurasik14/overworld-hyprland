//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.World

/*  World-effects preview (weather overlay, F3, day cycle) on the real output.  Run from the repo root:
 *      source scripts/dev-env.sh
 *      OW_PREVIEW=1 OW_WORLD_DRYRUN=1 qs -p $PWD/quickshell/World/preview > /tmp/fxw.log 2>&1 &
 *      qs -p $PWD/quickshell/World/preview ipc call world weather rain ; … world f3 on ; … world time
 *  OW_PREVIEW=1 keeps ConfigService from writing the real config; OW_WORLD_DRYRUN=1 makes the day cycle only print.
 *  OW_WORLD_NOW=2026-11-05T17:43:50+08:00 fakes the clock to watch a transition.
 *  OW_WORLD_BACKDROP=<png> paints that picture on the background layer first (so shots show the overlay over an Overworld wallpaper
 *  instead of whatever awww displays); it is mapped before the weather layer, so it sits under it.
 *  Screenshot: scripts/dev-shot.sh qa/screenshots/fx-world-<what>.png
 */
ShellRoot {
    Variants {
        model: (Quickshell.env("OW_WORLD_BACKDROP") || "").length ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "overworld-world-preview-backdrop"
            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "black"
            mask: Region {}
            Image { anchors.fill: parent; source: "file://" + Quickshell.env("OW_WORLD_BACKDROP"); fillMode: Image.PreserveAspectCrop }
        }
    }
    WorldFx {}
}
