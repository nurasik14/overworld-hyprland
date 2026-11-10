pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*  ConfigService — ~/.config/overworld/config.json (user overrides), watched live, plus the gamemode state file.
 *
 *    ConfigService.get("notifications.timeout.normal", 7000)   value, else the fallback, else the default below
 *    ConfigService.set("sound_volume.ui", 40)                  writes the key in place (keeps every other key)
 *    ConfigService.gamemode                                    survival|creative|adventure|spectator, watches ~/.config/overworld/gamemode
 *
 *  Keys with defaults (the Options screen edits these; qs-features owns the screen):
 *    gui_scale 2 (1-4 | "auto") · sound_volume.{master,ui,toasts,blocks,ambient} 100 (0-100) · sounds true
 *    animations true · reduced_motion false · particles "all" ("all"|"decreased"|"minimal") · weather_effects true
 *    daycycle "auto" ("auto"|"day"|"night"|"off") · difficulty "normal" ("normal"|"peaceful" = DND) · widgets.opacity 0.72
 *    death_screen true · hud.bossbar_media "playing" ("playing"|"track"|"off")
 *    notifications.timeout.{low 4000, normal 7000} · workspace_card.{enabled,duration,position,show_untitled}
 *    nowplaying.{layer "overlay"|"top", autoHideSec 20, maxVideoMin 20, hideWhenSourceFullscreen true, width 360, cacheMB 400,
 *                port 47833, video true}   (the Now Playing PiP, quickshell/NowPlaying)
 *
 *  OW_CONFIG=<path> points the service at another file (tests).
 */
Singleton {
    id: root
    readonly property string path: Quickshell.env("OW_CONFIG") || (Quickshell.env("HOME") + "/.config/overworld/config.json")
    readonly property string gamemodePath: Quickshell.env("HOME") + "/.config/overworld/gamemode"
    property var config: ({})
    property bool loaded: false

    readonly property var defaults: ({
        sounds: true,
        gui_scale: 2,
        sound_volume: { master: 100, ui: 100, toasts: 100, blocks: 100, ambient: 100 },
        animations: true,
        reduced_motion: false,
        particles: "all",
        weather_effects: true,
        daycycle: "auto",
        difficulty: "normal",
        widgets: { opacity: 0.72 },
        death_screen: true,
        hud: { bossbar_media: "playing" },
        notifications: { timeout: { low: 4000, normal: 7000 } },
        nowplaying: { layer: "overlay", autoHideSec: 20, maxVideoMin: 20, hideWhenSourceFullscreen: true, width: 360, cacheMB: 400,
                      port: 47833, video: true }
    })

    readonly property bool sounds: config.sounds !== false
    readonly property bool animations: config.animations !== false
    readonly property bool reducedMotion: config.reduced_motion === true || config.animations === false
    readonly property int timeoutLow: get("notifications.timeout.low")
    readonly property int timeoutNormal: get("notifications.timeout.normal")
    readonly property string particles: get("particles")
    readonly property bool weatherEffects: get("weather_effects") !== false
    readonly property string daycycle: String(get("daycycle"))
    readonly property string difficulty: String(get("difficulty"))
    readonly property var guiScale: get("gui_scale")
    function soundVolume(category) { return Number(get("sound_volume." + category)); }

    function _walk(obj, parts) {
        let cur = obj;
        for (let i = 0; i < parts.length; i++) {
            if (cur === null || typeof cur !== "object" || !(parts[i] in cur)) return undefined;
            cur = cur[parts[i]];
        }
        return cur;
    }
    function get(dotted, fallback) {
        const parts = dotted.split(".");
        const v = _walk(root.config, parts);
        if (v !== undefined) return v;
        return fallback !== undefined ? fallback : _walk(root.defaults, parts);
    }

    // ---------------------------------------------------------------- writes: one at a time, in place (never a rename, FileView keeps watching the inode)
    property var _writes: []
    function set(dotted, value) {
        if (Quickshell.env("OW_PREVIEW") === "1" && !Quickshell.env("OW_CONFIG")) {   // a preview never writes the real file
            console.warn("DRYRUN config", dotted, JSON.stringify(value));
            return;
        }
        _writes = _writes.concat([{ key: dotted, value: JSON.stringify(value) }]);
        _nextWrite();
    }
    function _nextWrite() {
        if (writer.running || !_writes.length) return;
        const w = _writes[0];
        _writes = _writes.slice(1);
        writer.command = ["sh", "-c",
            'f="$1"; mkdir -p "$(dirname "$f")"; [ -s "$f" ] || printf "{}" > "$f"; ' +
            'out="$(jq --arg k "$2" --argjson v "$3" \'setpath($k | split("."); $v)\' "$f")" && printf "%s\\n" "$out" > "$f"',
            "overworld-config", root.path, w.key, w.value];
        writer.running = true;
    }
    Process {
        id: writer
        stderr: StdioCollector { onStreamFinished: if (text.length) console.warn("ConfigService: write failed:", text) }
        onExited: root._nextWrite()
    }

    function parse(t) {
        try {
            const obj = JSON.parse(t || "{}");
            root.config = (obj && typeof obj === "object") ? obj : {};
        } catch (e) {
            console.warn("ConfigService: config.json parse error:", e);
            root.config = {};
        }
        root.loaded = true;
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
        onLoadFailed: error => { root.config = {}; root.loaded = true; poll.running = true }
    }
    Timer {   // file missing: look again every 5 s so a later `overworld` install is picked up
        id: poll
        interval: 5000; repeat: true; running: false
        onTriggered: file.reload()
    }
    Component.onCompleted: { parse(file.text()); applyGamemode(gamemodeFile.text()); }

    // ---------------------------------------------------------------- game mode (written by qs-features / `overworld gamemode`)
    property string gamemode: {
        const pin = Quickshell.env("OW_GAMEMODE") || "";   // previews only
        return pin.length ? pin : "survival";
    }
    readonly property bool isCreative: gamemode === "creative"
    readonly property bool isSpectator: gamemode === "spectator"
    function applyGamemode(t) {
        if ((Quickshell.env("OW_GAMEMODE") || "").length) return;
        const m = (t || "").trim();
        root.gamemode = ["survival", "creative", "adventure", "spectator"].indexOf(m) >= 0 ? m : "survival";
    }
    FileView {
        id: gamemodeFile
        path: root.gamemodePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: { gamemodePoll.running = false; root.applyGamemode(text()); }
        onFileChanged: reload()
        onLoadFailed: error => { root.applyGamemode(""); gamemodePoll.running = true }
    }
    Timer {
        id: gamemodePoll
        interval: 3000; repeat: true; running: false
        onTriggered: gamemodeFile.reload()
    }
}
