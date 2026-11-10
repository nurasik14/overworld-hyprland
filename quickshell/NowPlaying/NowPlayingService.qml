pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets.Services

/*  NowPlayingService — what the floating Now Playing mini-player shows (NowPlayingPip.qml), merged from two sources:
 *    MPRIS     MusicService's chosen player (Spotify first, else the playing one): title, artist, art, play state, controls.
 *              Zen's MPRIS also carries `xesam:url`, so a YouTube tab works even without the userscript (id from the URL).
 *    bridge    $XDG_RUNTIME_DIR/hypr-nowplaying/state.json, written by scripts/hypr-nowplaying (the shared daemon) from the Zen
 *              userscript apps/zen/nowplaying-bridge.user.js: video id, exact position / paused / rate, thumbnail, picture size,
 *              and the silent mirror video once it is cached (`videos[key]`).
 *  Choice: a playing browser report beats everything (it has the picture); else the MPRIS player (merged with the bridge when it is
 *  the browser and the titles match); else a paused report. A playing report goes stale after 3.5 s without news (then MPRIS only).
 *  The daemon runs as a child process ONLY while the PiP is on (stdin control: `want` a YouTube id, `active` key; EOF = it exits).
 *
 *  State: ~/.config/overworld/nowplaying.json {"on": false, "positions": {"<screen>": {"ax","ay","dx","dy","w"}}} (starts OFF).
 *  Config (config.json, ConfigService): nowplaying.{layer "overlay"|"top", autoHideSec 20, maxVideoMin 20, hideWhenSourceFullscreen true,
 *          width 360, cacheMB 400, port 47833, video true, tiktokCollection "Edits"}.
 *  TikTok like / repost / save (the view's second hover row): only for a TikTok tab whose userscript (bridge 1.3.0+) reports the
 *  logged-in action bar for the shown clip (`canLike`). `act("like"|"repost"|"save")` writes {"cmd":"action", tab, key, action,
 *  collection} to the daemon's stdin; the daemon hands it to that tab, which clicks TikTok's own button for that clip only. State
 *  comes back in the bridge report (`tt`: liked / saved / reposted, null = unknown) and the daemon's `action` record (busy, error).
 *  Tests: OW_NOWPLAYING_STATE=<file> · OW_NOWPLAYING_NODAEMON=1 · OW_NOWPLAYING_NOMPRIS=1 (ignore MPRIS) · HYPR_NOWPLAYING_RUNTIME=<dir> · OW_PREVIEW=1 (controls and focus are
 *  only logged, nothing is persisted unless OW_NOWPLAYING_STATE is set).
 */
Singleton {
    id: root

    // ------------------------------------------------------------------ on / off, positions
    readonly property string statePath: Quickshell.env("OW_NOWPLAYING_STATE") || (Quickshell.env("HOME") + "/.config/overworld/nowplaying.json")
    readonly property bool dryRun: ShellState.preview && !Quickshell.env("OW_NOWPLAYING_STATE")
    property bool on: false
    property var positions: ({})
    property bool loaded: false
    signal layoutReset(string screenName)

    FileView { id: stFile; path: root.statePath; blockLoading: true; printErrors: false }
    Component.onCompleted: {
        try {
            const j = JSON.parse(stFile.text() || "{}");
            root.on = j.on === true;
            root.positions = (j.positions && typeof j.positions === "object") ? j.positions : {};
        } catch (e) { root.on = false; root.positions = {}; }
        root.loaded = true;
        pickScreen();
    }
    Process {
        id: stWriter
        property string value: "{}"
        property bool again: false
        command: ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "overworld-nowplaying", root.statePath, value]
        onExited: if (again) { again = false; root.persist(); }
    }
    function persist() {
        if (!root.loaded) return;
        if (root.dryRun) { console.warn("DRYRUN nowplaying state", JSON.stringify({ on: root.on, positions: root.positions })); return; }
        if (stWriter.running) { stWriter.again = true; return; }
        stWriter.value = JSON.stringify({ on: root.on, positions: root.positions });
        stWriter.running = true;
    }
    function setOn(v) { if (root.on === !!v) return; root.on = !!v; if (root.on) root.revealUntil = Date.now() + 4000; persist(); }
    function toggle() { setOn(!root.on) }

    function posFor(screenName) { return root.positions[screenName] || null }
    // {ax: "left"|"right", ay: "top"|"bottom", dx, dy, w}: distances from the nearest screen edges, so a size change grows away from them
    function savePos(screenName, p) {
        if (!screenName) return;
        const n = Object.assign({}, root.positions);
        n[screenName] = { ax: p.ax === "left" ? "left" : "right", ay: p.ay === "top" ? "top" : "bottom",
                          dx: Math.round(p.dx), dy: Math.round(p.dy), w: Math.round(p.w) };
        root.positions = n; persist();
    }
    function resetPos(screenName) {
        const n = Object.assign({}, root.positions);
        if (screenName) delete n[screenName]; else for (const k in n) delete n[k];
        root.positions = n; persist(); root.layoutReset(screenName || "");
    }

    // the monitor it is on: the focused one when it appears (and on `reveal`)
    property string screenName: ""
    function pickScreen() {
        const f = Hyprland.focusedMonitor;
        const list = Quickshell.screens;
        let s = null;
        for (let i = 0; i < list.length; i++) if (f && list[i].name === f.name) s = list[i];
        s = s || (list.length ? list[0] : null);
        root.screenName = s ? s.name : "";
    }

    // ------------------------------------------------------------------ config
    readonly property string layerName: String(ConfigService.get("nowplaying.layer", "overlay")) === "top" ? "top" : "overlay"
    readonly property int autoHideSec: Math.max(0, Number(ConfigService.get("nowplaying.autoHideSec", 20)) || 0)
    readonly property real maxVideoMin: Math.max(1, Number(ConfigService.get("nowplaying.maxVideoMin", 20)) || 20)
    readonly property bool hideWhenSourceFullscreen: ConfigService.get("nowplaying.hideWhenSourceFullscreen", true) !== false
    readonly property int defaultWidth: Math.max(200, Math.min(960, Number(ConfigService.get("nowplaying.width", 360)) || 360))
    readonly property int cacheMB: Math.max(50, Number(ConfigService.get("nowplaying.cacheMB", 400)) || 400)
    readonly property int port: Number(ConfigService.get("nowplaying.port", 47833)) || 47833
    readonly property bool videoEnabled: ConfigService.get("nowplaying.video", true) !== false

    // ------------------------------------------------------------------ the shared daemon (child process, only while on)
    readonly property string cli: Theme.repoDir + "/scripts/hypr-nowplaying"
    readonly property bool noDaemon: Quickshell.env("OW_NOWPLAYING_NODAEMON") === "1"
    readonly property bool daemonWanted: root.on && !root.noDaemon
    readonly property var daemonCommand: [root.cli, "serve", "--stdin", "--port", String(root.port), "--cache-mb", String(root.cacheMB),
                                          "--max-min", String(root.maxVideoMin)]
    property int daemonExit: 0
    property bool daemonNoted: false
    property int busyExits: 0          // exit 3 in a row: another instance holds the lock (a restart overlapping the old one, or another theme)
    Process {
        id: daemon
        command: root.daemonCommand
        stdinEnabled: true
        stderr: SplitParser {
            onRead: line => { if (!root.daemonNoted) console.warn("hypr-nowplaying:", line); if (line.indexOf("already running") >= 0) root.daemonNoted = true; }
        }
        onRunningChanged: if (running) { root.daemonNoted = false; root._wanted = ""; root._active = ""; root.recompute(); }
        onExited: (code, status) => {
            root.daemonExit = code;
            root.busyExits = code === 3 ? root.busyExits + 1 : 0;
            if (root.daemonWanted) { restart.interval = code === 3 ? (root.busyExits <= 2 ? 2000 : 30000) : 10000; restart.restart(); }
        }
    }
    Timer { id: restart; onTriggered: if (root.daemonWanted && !daemon.running) daemon.running = true }
    onDaemonWantedChanged: { restart.stop(); daemon.running = daemonWanted; }
    onDaemonCommandChanged: if (daemon.running) { daemon.running = false; restart.interval = 300; restart.restart(); }
    readonly property bool daemonRunning: daemon.running
    function send(obj) { if (daemon.running) daemon.write(JSON.stringify(obj) + "\n") }

    // ------------------------------------------------------------------ the bridge state file
    readonly property string runtimeDir: Quickshell.env("HYPR_NOWPLAYING_RUNTIME") || ((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr-nowplaying")
    property var daemonState: null
    FileView {
        id: bridgeFile
        path: root.on ? root.runtimeDir + "/state.json" : ""
        watchChanges: true
        printErrors: false
        onLoaded: { bridgePoll.running = false; root.parseBridge(text()); }
        onFileChanged: reload()
        onLoadFailed: error => { root.daemonState = null; bridgePoll.running = root.on; }
    }
    Timer { id: bridgePoll; interval: 2000; repeat: true; onTriggered: bridgeFile.reload() }
    function parseBridge(t) {
        if (!t || !t.trim().length) return;
        try { root.daemonState = JSON.parse(t); } catch (e) { return; }   // torn read: the next change notification brings the whole file
        root.recompute();
    }

    // ------------------------------------------------------------------ the clock and the merge
    property real now: Date.now()
    Timer {
        interval: 1000; repeat: true
        running: root.on
        onTriggered: { root.now = Date.now(); root.recompute(); }
    }
    Connections { target: MusicService; function onPlayerChanged() { root.recompute() } function onTitleChanged() { root.recompute() } function onPlayingChanged() { root.recompute() } }
    onOnChanged: { root.now = Date.now(); recompute(); }

    readonly property var browserRe: /firefox|zen|librewolf|floorp|waterfox|chrom|brave|vivaldi|opera|edge/i
    function isBrowserPlayer(p) { return !!p && (browserRe.test(p.dbusName || "") || browserRe.test(p.identity || "") || browserRe.test(p.desktopEntry || "")) }
    function norm(s) { return String(s || "").toLowerCase().replace(/[^0-9a-z\u00c0-\u024f\u0370-\u03ff\u0400-\u04ff\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af]+/g, " ").trim() }
    function sameTitle(a, b) {
        const x = norm(a), y = norm(b);
        if (!x.length || !y.length) return false;
        return x === y || (x.length > 6 && y.indexOf(x) >= 0) || (y.length > 6 && x.indexOf(y) >= 0);
    }
    readonly property bool noMpris: Quickshell.env("OW_NOWPLAYING_NOMPRIS") === "1"   // tests: the bridge alone
    function browserPlayer(title) {
        if (root.noMpris) return null;
        const list = MusicService.players.filter(p => isBrowserPlayer(p));
        return list.find(p => sameTitle(p.trackTitle, title)) || list.find(p => p.isPlaying) || list[0] || null;
    }
    function mprisUrl(p) {
        try { const m = p ? p.metadata : null; return m ? String(m["xesam:url"] || "") : ""; } catch (e) { return ""; }
    }
    function youtubeFromUrl(u) {
        const m = String(u || "").match(/^https:\/\/(www\.|m\.|music\.)?youtube\.com\/(watch\?(?:.*&)?v=|shorts\/)([A-Za-z0-9_-]{11})/);
        return m ? { id: m[3], site: m[1] === "music." ? "ytmusic" : "youtube", shorts: m[2] === "shorts/" } : null;
    }
    function siteOfPlayer(p) {
        const s = ((p && (p.identity + " " + p.dbusName + " " + p.desktopEntry)) || "").toLowerCase();
        if (s.indexOf("spotify") >= 0) return "spotify";
        return "other";
    }

    // `cur` — one plain object the view reads; rebuilt on every change and once a second.
    //   kind none|bridge|mpris · site youtube|ytmusic|tiktok|spotify|other · key · title · artist · artUrl · isVideo · live · ad · paused
    //   position (s, sampled at ts ms) · rate · duration · width · height · shorts · player (MprisPlayer for controls) · browser
    property var cur: ({ kind: "none" })
    property var last: ({ kind: "none" })       // the last thing shown: kept on screen while lingering after the music stopped
    function bridgeFresh(b, now) {
        if (!b || !root.daemonState || !root.daemonState.server) return false;
        return (now - (b.received || 0)) < (b.paused ? 1800000 : 3500);
    }
    function recompute() {
        if (!root.on) { root.cur = { kind: "none" }; return; }
        const now = Date.now();
        const ds = root.daemonState;
        const b = ds && ds.bridge ? ds.bridge : null;
        const fresh = bridgeFresh(b, now);
        const mp = root.noMpris ? null : MusicService.player;
        const mpPlaying = !!mp && mp.isPlaying;
        let c = { kind: "none" };
        const fromBridge = (bb, p) => ({
            kind: "bridge", site: bb.site, key: bb.key || "", title: bb.title || (p ? p.trackTitle : "") || "",
            artist: bb.author || (p ? p.trackArtist : "") || "", artUrl: bb.thumbnail || (p ? p.trackArtUrl : "") || "",
            isVideo: !!bb.isVideo, live: !!bb.live, ad: !!bb.ad, paused: !!bb.paused, buffering: !!bb.buffering && !bb.paused,
            position: Number(bb.position) || 0,
            ts: Math.min(Number(bb.ts) || Number(bb.received) || now, now), rate: Number(bb.rate) || 1, duration: Number(bb.duration) || 0,
            width: bb.width || 0, height: bb.height || 0, shorts: /\/shorts\//.test(bb.pageUrl || ""), player: p, browser: true,
            tab: bb.tab || "", tt: bb.tt || null
        });
        if (fresh && !b.paused) {
            c = fromBridge(b, browserPlayer(b.title));
        } else if (mp && (mpPlaying || !(fresh && b.paused))) {
            const browser = isBrowserPlayer(mp);
            if (browser && b && sameTitle(mp.trackTitle, b.title)) {
                // the browser's own report, merged: static fields from the bridge, the live clock from MPRIS when the report is old
                c = fromBridge(b, mp);
                if (!fresh || (!mp.isPlaying) !== c.paused) {
                    c.paused = !mp.isPlaying;
                    c.buffering = false;
                    c.position = mp.positionSupported ? mp.position : c.position;
                    c.ts = now;
                    c.rate = mp.rate || 1;
                }
            } else {
                const yt = browser ? youtubeFromUrl(mprisUrl(mp)) : null;
                c = {
                    kind: "mpris", site: yt ? yt.site : (browser ? "other" : siteOfPlayer(mp)), key: yt ? "youtube-" + yt.id : "",
                    title: mp.trackTitle || mp.identity || "", artist: mp.trackArtist || "", artUrl: mp.trackArtUrl || "",
                    isVideo: !!yt && yt.site === "youtube", live: false, ad: false, paused: !mp.isPlaying,
                    position: mp.positionSupported ? mp.position : 0, ts: now, rate: mp.rate || 1,
                    duration: mp.lengthSupported ? mp.length : 0, width: 0, height: 0, shorts: !!yt && yt.shorts, player: mp, browser: browser,
                    youtubeId: yt ? yt.id : ""
                };
                if (!mp.isPlaying && mp.playbackState === MprisPlaybackState.Stopped) c = { kind: "none" };
            }
        } else if (fresh && (root.noMpris || MusicService.players.some(p => isBrowserPlayer(p)))) {
            // a paused report only while the browser still has a media session (a quit / crashed browser sends no "gone")
            c = fromBridge(b, browserPlayer(b.title));
        }
        if (c.kind !== "none" && !c.title.length && !c.artUrl.length && !c.key.length) c = { kind: "none" };
        // the mirror video for this key
        const v = c.key && ds && ds.videos ? ds.videos[c.key] : null;
        c.videoStatus = c.kind === "none" ? "none" : (v ? v.status : (c.key && b && b.key === c.key ? (ds.videoStatus || "none") : "none"));
        c.videoFile = root.videoEnabled && v && v.status === "ready" && v.file ? v.file : "";
        if (v && v.width > 0 && v.height > 0) { c.width = v.width; c.height = v.height; c.isVideo = true; }
        if (c.kind === "mpris" && c.key && v && v.duration > 0 && !c.duration) c.duration = v.duration;
        root.cur = c;
        if (c.kind !== "none") root.last = c;
        // ask the daemon for a YouTube video the userscript does not report (MPRIS only), and tell it what is on screen
        if (c.kind === "mpris" && c.youtubeId && c.isVideo && !v && root._wanted !== c.key && daemon.running && root.videoEnabled) {
            root._wanted = c.key;
            send({ cmd: "want", site: "youtube", id: c.youtubeId, duration: c.duration || 0 });
        }
        if (c.key && c.key !== root._active && daemon.running) { root._active = c.key; send({ cmd: "active", key: c.key }); }
    }
    property string _wanted: ""
    property string _active: ""

    // ------------------------------------------------------------------ what the view binds to
    readonly property bool hasMedia: cur.kind !== "none"
    readonly property var view: hasMedia ? cur : last
    readonly property string title: view.title || ""
    readonly property string artist: view.artist || ""
    readonly property string site: view.site || "other"
    readonly property string artUrl: view.artUrl || ""
    readonly property string videoFile: view.videoFile || ""
    readonly property string videoStatus: view.videoStatus || "none"
    readonly property bool isVideo: !!view.isVideo
    readonly property bool live: !!view.live
    readonly property bool ad: !!view.ad
    readonly property bool paused: !hasMedia || !!view.paused
    readonly property real rate: view.rate || 1
    readonly property real duration: view.duration || 0
    readonly property string key: view.key || ""
    readonly property real aspect: {
        const v = view;
        if (v.width > 0 && v.height > 0) return v.width / v.height;
        if (v.site === "tiktok" || v.shorts) return 9 / 16;
        if (v.isVideo || v.site === "youtube") return 16 / 9;
        return 1;
    }
    readonly property string sourceLabel: ({ youtube: "YouTube", ytmusic: "YouTube Music", tiktok: "TikTok", spotify: "Spotify" })[site]
                                          || (view.player ? (view.player.identity || "Music") : "Music")
    // the clock the mirror steers by: {valid, position, ts, paused, rate, duration}; a buffering browser stands still, so does the mirror
    readonly property bool buffering: hasMedia && !!view.buffering
    readonly property var clock: ({ valid: hasMedia && !ad, position: view.position || 0, ts: view.ts || now, paused: paused || buffering,
                                    rate: rate, duration: duration })
    function positionNow() {
        const c = root.clock;
        if (!c.valid) return 0;
        const p = c.paused ? c.position : c.position + Math.max(0, (Date.now() - c.ts) / 1000) * c.rate;
        return c.duration > 0 ? Math.min(c.duration, p) : p;
    }

    // ------------------------------------------------------------------ visibility
    property bool lingering: false
    property real revealUntil: 0
    onHasMediaChanged: {
        if (!hasMedia && on && last.kind !== "none") { lingering = true; linger.interval = Math.max(1, autoHideSec) * 1000; linger.restart(); }
        else if (hasMedia) { lingering = false; linger.stop(); }
    }
    Timer { id: linger; onTriggered: root.lingering = false }
    readonly property var activeTl: Hyprland.activeToplevel
    function clsOf(t) {
        if (!t) return "";
        const o = t.lastIpcObject || {};
        return String(o["class"] || o.initialClass || (t.wayland ? t.wayland.appId : "") || "");
    }
    function matchesSource(cls) {
        if (!cls.length || !hasMedia) return false;
        if (view.browser) return browserRe.test(cls);
        const p = view.player;
        if (!p) return false;
        const want = ((p.desktopEntry || "") + " " + (p.identity || "") + " " + (p.dbusName || "")).toLowerCase();
        return want.indexOf(cls.toLowerCase().replace(/^.*\./, "")) >= 0;
    }
    readonly property bool sourceFullscreen: {
        const t = activeTl;
        if (!t) return false;
        const fs = (t.wayland && t.wayland.fullscreen) || ((t.lastIpcObject || {}).fullscreen || 0) > 0;
        return fs && matchesSource(clsOf(t));
    }
    readonly property bool hiddenByFullscreen: hideWhenSourceFullscreen && sourceFullscreen
    readonly property bool revealed: now < revealUntil
    readonly property bool shown: on && !hiddenByFullscreen && (hasMedia || lingering || revealed)
    function reveal() { pickScreen(); if (!on) setOn(true); root.now = Date.now(); root.revealUntil = Date.now() + Math.max(4, autoHideSec) * 1000; }

    // ------------------------------------------------------------------ controls (the source player's MPRIS) and focus
    readonly property var controlPlayer: hasMedia ? (view.player || null) : null
    readonly property bool canToggle: !!controlPlayer && controlPlayer.canTogglePlaying
    readonly property bool canNext: !!controlPlayer && controlPlayer.canGoNext
    readonly property bool canPrevious: !!controlPlayer && controlPlayer.canGoPrevious
    function act(what) {
        if (what === "like" || what === "repost" || what === "save") return tiktokAct(what);
        const p = controlPlayer;
        if (!p) return;
        if (ShellState.preview || Quickshell.env("OW_NOWPLAYING_DRYRUN") === "1") { console.warn("DRYRUN nowplaying", what); return; }
        if (what === "toggle" && p.canTogglePlaying) p.togglePlaying();
        else if (what === "next" && p.canGoNext) p.next();
        else if (what === "previous" && p.canGoPrevious) p.previous();
    }
    function togglePlaying() { act("toggle") }
    function next() { act("next") }
    function previous() { act("previous") }
    function sourceWindow() {
        const list = Hyprland.toplevels.values.filter(t => matchesSource(clsOf(t)));
        if (!list.length) return null;
        const head = norm(title).slice(0, 24);
        return list.find(t => head.length > 3 && norm(t.title).indexOf(head) >= 0) || list.find(t => t.activated) || list[0];
    }
    function focusSource() {
        const t = sourceWindow();
        if (!t) return false;
        const addr = "0x" + String(t.address).replace(/^0x/, "");
        if (ShellState.preview || Quickshell.env("OW_NOWPLAYING_DRYRUN") === "1") { console.warn("DRYRUN focuswindow address:" + addr); return true; }
        Hyprland.dispatch("focuswindow address:" + addr);
        return true;
    }
    readonly property bool canFocus: hasMedia && sourceWindow() !== null

    // ------------------------------------------------------------------ TikTok: like / repost / save (the userscript clicks TikTok's buttons)
    readonly property string tiktokCollection: String(ConfigService.get("nowplaying.tiktokCollection", "Edits") || "").trim() || "Edits"
    // the userscript's report for the clip on screen: {bar, clip, liked, saved, reposted, busy, last}, or null (no buttons)
    readonly property var tt: {
        const v = view;
        if (!hasMedia || v.kind !== "bridge" || v.site !== "tiktok" || !v.tab || !v.tt || v.tt.bar !== true) return null;
        return v.tt.clip && "tiktok-" + v.tt.clip === v.key ? v.tt : null;
    }
    readonly property bool canLike: tt !== null && daemonRunning
    // the daemon's newest command record for this clip: {id, tab, key, action, status queued|sent|done|failed|expired|refused, error, t}
    readonly property var actionRecord: {
        const a = daemonState ? daemonState.action : null;
        return a && key.length && a.key === key ? a : null;
    }
    readonly property string busy: !canLike ? "" : actionRecord && (actionRecord.status === "queued" || actionRecord.status === "sent")
                                   ? String(actionRecord.action || "") : String(tt.busy || "")
    readonly property var liked: tt ? tt.liked : null           // true / false / null (unknown)
    readonly property var saved: tt ? tt.saved : null
    readonly property var reposted: tt ? tt.reposted : null
    readonly property string actionError: actionRecord && actionRecord.status !== "queued" && actionRecord.status !== "sent" ? String(actionRecord.error || "") : ""
    readonly property string actionErrorFor: actionError.length ? String(actionRecord.action || "") : ""
    readonly property bool actionErrorFresh: actionError.length > 0 && now - (Number(actionRecord.t) || 0) < 8000   // shown on the picture for a few s
    function tiktokAct(what) {
        if (!root.canLike || root.busy.length) return false;   // one at a time; the buttons are disabled meanwhile anyway
        const cmd = { cmd: "action", tab: root.view.tab, key: root.key, action: what, collection: root.tiktokCollection };
        if (root.dryRun) { console.warn("DRYRUN nowplaying action", JSON.stringify(cmd)); return true; }
        send(cmd);
        root.now = Date.now();
        return true;
    }

    function fmt(s) { return MusicService.fmt(s) }
    function statusLine() {
        const parts = [on ? "on" : "off"];
        if (on) parts.push(shown ? "shown" : (hiddenByFullscreen ? "hidden (source fullscreen)" : "hidden (nothing playing)"));
        parts.push("daemon " + (daemon.running ? "running" : (noDaemon ? "disabled" : "stopped")));
        if (hasMedia) {
            parts.push(sourceLabel + (paused ? " paused" : " playing") + ": " + (title.length > 60 ? title.slice(0, 59) + "…" : title));
            parts.push("video " + (videoFile.length ? "ready" : videoStatus));
            if (canLike) parts.push("TikTok " + [["liked", liked], ["saved", saved], ["reposted", reposted]]
                                   .map(x => (x[1] === true ? "" : x[1] === false ? "not " : "? ") + x[0]).join(" ") + (busy.length ? " (" + busy + "…)" : ""));
        } else parts.push("nothing playing");
        return parts.join(", ");
    }
}
