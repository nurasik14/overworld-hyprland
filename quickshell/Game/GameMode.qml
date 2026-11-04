pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

/*  GameMode — survival | creative | adventure | spectator, stored as one word in ~/.config/overworld/gamemode (watched live).
 *    GameMode.mode · GameMode.set(m) · GameMode.cycle(±1) · info(m) → {name, item, summary, lines[]} · modes
 *  Effects (HUD modules read the file or this singleton):
 *    survival   normal                          creative   no heart/hunger warnings (`GameMode.creative`)
 *    adventure  performance mode (scripts/game/apply-gamemode.sh)
 *    spectator  HUD and widgets hidden (`GameMode.spectator`), gaps 0, DND on; leaving restores
 *  A legacy flag file from the Apothecary CLI ("visible"/"hidden") reads as adventure — that CLI mode *is* adventure.
 */
Singleton {
    id: root
    readonly property var modes: ["survival", "creative", "adventure", "spectator"]
    readonly property string path: GameCore.statePath("gamemode")
    property string mode: "survival"
    readonly property bool creative: mode === "creative"
    readonly property bool spectator: mode === "spectator"
    readonly property bool adventure: mode === "adventure"
    property bool dndBefore: false
    property bool dndSet: false

    readonly property var table: ({
        survival:  { name: "Survival Mode",  item: "iron_sword", summary: "Normal desktop",
                     lines: ["Everything on, as installed."] },
        creative:  { name: "Creative Mode",  item: "grass_block", summary: "No hunger or heart warnings",
                     lines: ["Hearts and hunger never jiggle or shake.", "Everything else stays on."] },
        adventure: { name: "Adventure Mode", item: "map", summary: "Performance",
                     lines: ["Animations, blur, shadows and gaps off.", "Desktop widgets hidden."] },
        spectator: { name: "Spectator Mode", item: "ender_eye", summary: "Focus",
                     lines: ["HUD and widgets hidden, gaps 0.", "Difficulty Peaceful (Do Not Disturb)."] }
    })
    function info(m) { return table[m] || table.survival; }
    function valid(m) { return modes.indexOf(m) >= 0; }

    function normalise(text) {
        const w = (text || "").trim().toLowerCase();
        if (valid(w)) return w;
        if (w === "visible" || w === "hidden") return "adventure";
        return "survival";
    }
    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        atomicWrites: false
        printErrors: false
        onLoaded: root.mode = root.normalise(text())
        onLoadFailed: error => root.mode = "survival"
        onFileChanged: reload()
    }

    function set(m) {
        m = String(m).toLowerCase();
        if (!valid(m)) return false;
        const old = root.mode;
        file.setText(m + "\n");
        root.mode = m;
        if (m !== old) {
            GameCore.run([GameCore.gameScripts + "/apply-gamemode.sh", m, old]);
            if (m === "spectator") {
                dndBefore = NotificationService.dnd; dndSet = true;
                if (!NotificationService.dnd) NotificationService.toggleDnd();
            } else if (old === "spectator" && dndSet) {
                dndSet = false;
                if (NotificationService.dnd !== dndBefore) NotificationService.toggleDnd();
            }
        }
        GameEvents.emit("gamemode", { mode: m });
        return true;
    }
    function cycle(d) {
        const i = modes.indexOf(root.mode);
        set(modes[(i + d + modes.length) % modes.length]);
    }
}
