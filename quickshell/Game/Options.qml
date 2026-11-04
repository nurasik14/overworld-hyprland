pragma Singleton
import QtQuick
import Quickshell
import qs.Services

/*  Options — config.json as the Options screen sees it. Writes go through scripts/game/set-config.sh (jq, in place).
 *    Options.get("sound_volume.master", 100) · Options.set("particles", "decreased") · Options.revision
 *  Keys the screen writes (ConfigService/Theme/ow-sound/fx-world read them; defaults in brackets):
 *    gui_scale 1|2|3|4|"auto" [2] · animations bool [true] · reduced_motion bool [false] · particles "all"|"decreased"|"minimal" ["all"]
 *    weather_effects bool [true] · daycycle "auto"|"day"|"night" ["auto"] · widgets.opacity 0.3–1 [0.72]
 *    sounds bool [true] · sound_volume.{master,ui,toasts,blocks,ambient} 0–100 [100]
 *  Difficulty (Peaceful) is not a key: it is NotificationService.dnd.
 */
Singleton {
    id: root
    readonly property string path: GameCore.statePath("config.json")
    property var config: ({})
    property int revision: 0
    property double lastSet: 0

    JsonStore {
        id: store
        path: root.path
        watch: true
        onLoadedFile: {
            if (Date.now() - root.lastSet < 900) return;   // our own write echoing back: the local copy is newer
            root.config = store.data;
            root.revision++;
        }
    }

    function get(dotted, fallback) {
        let cur = revision >= 0 ? root.config : null;
        const parts = dotted.split(".");
        for (let i = 0; i < parts.length; i++) {
            if (cur === null || typeof cur !== "object" || !(parts[i] in cur)) return fallback;
            cur = cur[parts[i]];
        }
        return cur === undefined ? fallback : cur;
    }
    function set(dotted, value) {
        const cfg = JSON.parse(JSON.stringify(root.config || {}));
        const parts = dotted.split(".");
        let cur = cfg;
        for (let i = 0; i < parts.length - 1; i++) {
            if (cur[parts[i]] === undefined || typeof cur[parts[i]] !== "object") cur[parts[i]] = {};
            cur = cur[parts[i]];
        }
        cur[parts[parts.length - 1]] = value;
        root.config = cfg; root.lastSet = Date.now(); root.revision++;
        Quickshell.execDetached([GameCore.gameScripts + "/set-config.sh", root.path, dotted, JSON.stringify(value)]);
    }
}
