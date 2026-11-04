pragma Singleton
import QtQuick
import Quickshell
import qs.Services

/*  Stats — lifetime and per-session counters of shell/Hyprland events (never keystrokes). Persisted to stats.json.
 *    Stats.total(key) · Stats.session(key) · Stats.apps (per window class: {opened, mined}) · Stats.workspaces (per id)
 *    Stats.playSeconds / sessionSeconds · Stats.revision (bumps on every change; bind to it)
 *  Keys: windowsOpened windowsClosed windowsMined workspaceSwitches distance notifications urgentNotifications brewsStarted
 *        brewsDone restsDone screenshots launches commands advancements wallpapers worlds deaths levels connections modeSwitches
 *        gamemodeSwitches
 */
Singleton {
    id: root
    readonly property string statePath: GameCore.statePath("stats.json")
    property var totals: ({})
    property var sess: ({})
    property var apps: ({})
    property var workspaces: ({})
    property double firstRun: 0
    property double lastTick: Date.now()
    property double playSeconds: 0
    property double sessionSeconds: 0
    property int sessions: 0
    property int lastWorkspace: 0
    property int revision: 0
    readonly property var eventKey: ({
        "window.open": "windowsOpened", "window.close": "windowsClosed", "window.kill": "windowsMined",
        "notify": "notifications", "brew.start": "brewsStarted", "brew.done": "brewsDone", "rest.done": "restsDone",
        "screenshot": "screenshots", "launcher.launch": "launches", "chat.command": "commands", "advancement": "advancements",
        "wallpaper.set": "wallpapers", "world.created": "worlds", "death": "deaths", "xp.levelup": "levels",
        "net.connect": "connections", "mode": "modeSwitches", "gamemode": "gamemodeSwitches"
    })

    function total(key) { return revision >= 0 ? (totals[key] || 0) : 0; }
    function session(key) { return revision >= 0 ? (sess[key] || 0) : 0; }

    function bump(key, n) {
        n = n || 1;
        totals[key] = (totals[key] || 0) + n;
        sess[key] = (sess[key] || 0) + n;
    }
    function bumpApp(cls, field) {
        cls = String(cls || "unknown").toLowerCase();
        const e = apps[cls] || { opened: 0, mined: 0 };
        e[field] = (e[field] || 0) + 1;
        apps[cls] = e;
    }
    function record(name, data) {
        data = data || {};
        const key = eventKey[name];
        let hit = false;
        if (key) { bump(key); hit = true; }
        if (name === "window.open") bumpApp(data.cls, "opened");
        else if (name === "window.kill") bumpApp(data.cls, "mined");
        else if (name === "notify" && (data.urgency === "critical" || data.urgency === 2)) bump("urgentNotifications");
        else if (name === "workspace") {
            const id = parseInt(data.id);
            if (id > 0) {
                bump("workspaceSwitches");
                if (lastWorkspace > 0) bump("distance", Math.abs(id - lastWorkspace));
                lastWorkspace = id;
                workspaces[id] = (workspaces[id] || 0) + 1;
                hit = true;
            }
        }
        if (hit) { root.revision++; dirty = true; }
    }
    property bool dirty: false

    function persist() {
        dirty = false;
        store.data = { version: 1, first: firstRun, sessions: sessions, playSeconds: playSeconds, totals: totals,
                       apps: apps, workspaces: workspaces, lastWorkspace: lastWorkspace };
        store.saveNow();
    }

    JsonStore {
        id: store
        path: root.statePath
        onLoadedFile: {
            const d = store.data;
            root.totals = d.totals || ({}); root.apps = d.apps || ({}); root.workspaces = d.workspaces || ({});
            root.firstRun = d.first || Date.now(); root.playSeconds = d.playSeconds || 0;
            root.sessions = (d.sessions || 0) + 1; root.lastWorkspace = d.lastWorkspace || 0;
            root.lastTick = Date.now(); root.revision++; root.dirty = true;
        }
    }

    Connections {
        target: GameEvents
        function onEvent(name, data) { root.record(name, data); }
    }
    Timer {   // time played: real elapsed time per beat, capped so a suspend does not count as play
        interval: 10000; running: true; repeat: true
        onTriggered: {
            const now = Date.now();
            const dt = Math.min(30, (now - root.lastTick) / 1000);
            root.lastTick = now;
            root.playSeconds += dt; root.sessionSeconds += dt; root.revision++; root.dirty = true;
        }
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: if (root.dirty) root.persist() }
    Component.onDestruction: if (dirty) persist()
}
