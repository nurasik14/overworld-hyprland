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
 *  Several sources (`sources`, the view's chip + list, IPC `sources` / `pick`): every fresh bridge tab (YouTube / YT Music / TikTok)
 *  and every MPRIS player not already listed as a tab (Spotify, mpv, Chrome, the browser's own player on a site the userscript does
 *  not cover; a browser player whose title matches a listed tab is that tab). Ids `tab:<tab>` / `mpris:<dbusName>`, rows in order of
 *  appearance. Choice: Auto (the rule above) or a PINNED source (`choose(id)`, `pick(n|next|prev|auto)`); the pin survives a shell
 *  reload (PersistentProperties in NowPlayingIpc), not a logout, and is released when its source has been gone for 3 s (20 s after the daemon
 *  started: a reload restarts it and the tabs report again within seconds). A pinned tab is also pinned in
 *  the daemon (stdin `pin`, so its video is fetched). Controls act on the SHOWN source: MPRIS when the source is a player or the
 *  browser's player follows the tab (same title), else that tab's own player through the daemon (stdin `action` play / pause / next /
 *  previous, bridge 1.4.0+; a pinned tab with an older bridge has no controls).
 *
 *  State: ~/.config/overworld/nowplaying.json {"on": false, "positions": {"<screen>": {"ax","ay","dx","dy","w"}}} (starts OFF).
 *  Config (config.json, ConfigService): nowplaying.{layer "overlay"|"top", autoHideSec 20, maxVideoMin 20, hideWhenSourceFullscreen true,
 *          width 360, cacheMB 400, port 47833, video true, tiktokCollection "Edits", partFirstMin 5, partMin 40, partAheadMin 5, partHeight 360}.
 *  Long videos (YouTube, longer than maxVideoMin, not live) come in PARTS around the position (the daemon plans them; videos[key]
 *  {mode "parts", parts [{start, dur, file, status}]}); `mirrorParts` is what MirrorStack plays: the ready parts, or the whole file as
 *  one part {start 0, dur 0}. An MPRIS-only long video sends its position with `want` every 5 s (and at once on a seek / pause).
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

    // the chosen source ("" = Auto). Kept across shell reloads by NowPlayingIpc's PersistentProperties (they do not work in a
    // singleton), not across a logout
    property string pinnedId: ""
    readonly property bool auto: pinnedId === ""
    function restorePin(id) { if (String(id || "") !== root.pinnedId) { root.pinnedId = String(id || ""); root._pinMissingSince = 0; } }

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
    // long videos in parts (the daemon's --part-* options)
    function cfgNum(k, d, lo, hi) { const v = Number(ConfigService.get("nowplaying." + k, d)); return Math.max(lo, Math.min(hi, isFinite(v) && v > 0 ? v : d)) }
    readonly property real partFirstMin: cfgNum("partFirstMin", 5, 0.5, 60)
    readonly property real partMin: cfgNum("partMin", 40, 1, 240)
    readonly property real partAheadMin: cfgNum("partAheadMin", 5, 0.5, 60)
    readonly property int partHeight: Math.round(cfgNum("partHeight", 360, 144, 1080))

    // ------------------------------------------------------------------ the shared daemon (child process, only while on)
    readonly property string cli: Theme.repoDir + "/scripts/hypr-nowplaying"
    readonly property bool noDaemon: Quickshell.env("OW_NOWPLAYING_NODAEMON") === "1"
    readonly property bool daemonWanted: root.on && !root.noDaemon
    readonly property var daemonCommand: [root.cli, "serve", "--stdin", "--port", String(root.port), "--cache-mb", String(root.cacheMB),
                                          "--max-min", String(root.maxVideoMin), "--part-first-min", String(root.partFirstMin),
                                          "--part-min", String(root.partMin), "--part-ahead-min", String(root.partAheadMin),
                                          "--part-height", String(root.partHeight)]
    property int daemonExit: 0
    property bool daemonNoted: false
    property real daemonSince: Date.now()   // the daemon (re)started / stopped: its tab list refills over the next seconds
    property int busyExits: 0          // exit 3 in a row: another instance holds the lock (a restart overlapping the old one, or another theme)
    Process {
        id: daemon
        command: root.daemonCommand
        stdinEnabled: true
        stderr: SplitParser {
            onRead: line => { if (!root.daemonNoted) console.warn("hypr-nowplaying:", line); if (line.indexOf("already running") >= 0) root.daemonNoted = true; }
        }
        onRunningChanged: if (running) { root.daemonNoted = false; root._wanted = ""; root._active = ""; root._sentPin = "?"; root.daemonSince = Date.now(); root.recompute(); }
        onExited: (code, status) => {
            root.daemonExit = code;
            root.daemonSince = Date.now();
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
    function siteLabel(site, p) {
        return ({ youtube: "YouTube", ytmusic: "YouTube Music", tiktok: "TikTok", spotify: "Spotify" })[site]
               || (p ? (p.identity || "Music") : "Music");
    }
    function versionAtLeast(v, want) {   // "1.4.0" >= "1.4.0"
        const a = String(v || "").split(".").map(Number), b = String(want).split(".").map(Number);
        if (a.length !== 3 || a.some(x => !(x >= 0))) return false;
        for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] > b[i];
        return true;
    }
    function playerId(p) { return "mpris:" + String((p && (p.dbusName || p.identity)) || "") }

    // ------------------------------------------------------------------ the sources the PiP can show (see the header)
    //   {id, kind bridge|mpris, site, label, title, artist, paused, tab, data (the daemon's tab), player}
    property var sources: []
    property var _order: []          // ids in order of first appearance: stable rows and numbers
    function buildSources(ds, now, players) {   // players: MusicService.players (tests pass stand-ins)
        const out = [];
        const tabs = ds && Array.isArray(ds.tabs) ? ds.tabs : (ds && ds.bridge ? [ds.bridge] : []);   // an older daemon: its one tab
        const list = players || [];
        const browserAlive = (root.noMpris && !players) || list.some(p => isBrowserPlayer(p));
        for (const t of tabs) {
            if (!t || !t.tab || !bridgeFresh(t, now)) continue;
            if (t.paused && !browserAlive) continue;   // a paused report only while the browser still has a media session
            if (!(t.title || "").length && !(t.thumbnail || "").length && !(t.key || "").length) continue;
            out.push({ id: "tab:" + t.tab, kind: "bridge", site: t.site, label: siteLabel(t.site, null), title: t.title || "",
                       artist: t.author || "", paused: !!t.paused, tab: t.tab, data: t, player: null });
        }
        for (const p of list) {
            if (!p || (!p.isPlaying && p.playbackState === MprisPlaybackState.Stopped)) continue;
            const title = p.trackTitle || "";
            if (!title.length && !(p.trackArtUrl || "").length) continue;
            const browser = isBrowserPlayer(p);
            if (browser && out.some(x => x.kind === "bridge" && sameTitle(x.title, title))) continue;   // that tab is listed already
            const yt = browser ? youtubeFromUrl(mprisUrl(p)) : null;
            const site = yt ? yt.site : (browser ? "other" : siteOfPlayer(p));
            out.push({ id: playerId(p), kind: "mpris", site: site, label: siteLabel(site, p), title: title, artist: p.trackArtist || "",
                       paused: !p.isPlaying, tab: "", data: null, player: p });
        }
        const ids = out.map(x => x.id);
        const order = root._order.filter(id => ids.indexOf(id) >= 0);
        for (const id of ids) if (order.indexOf(id) < 0) order.push(id);
        if (order.join("\n") !== root._order.join("\n")) root._order = order;
        out.sort((a, b) => order.indexOf(a.id) - order.indexOf(b.id));
        return out;
    }
    readonly property int sourceCount: sources.length
    readonly property string shownId: hasMedia ? (cur.sourceId || "") : ""
    readonly property int shownIndex: { const id = shownId; for (let i = 0; i < sources.length; i++) if (sources[i].id === id) return i + 1; return 0; }
    readonly property int bridgeTabCount: sources.filter(x => x.kind === "bridge").length
    property real _pinMissingSince: 0
    property string _sentPin: "?"
    // choose a source by id ("" = Auto); false when there is no such source
    function choose(id) {
        id = String(id || "");
        if (id.length && !root.sources.some(x => x.id === id)) return false;
        root.pinnedId = id;
        root._pinMissingSince = 0;
        root.now = Date.now();
        recompute();
        return true;
    }
    // pick(n | "next" | "prev" | "auto"): n = the row number (0 = Auto); next / prev cycle Auto → 1 → … → n → Auto (the chip's wheel)
    function pick(which) {
        const w = String(which || "").trim().toLowerCase();
        if (!root.on) return "the PiP is off (nowplaying on)";
        const ids = [""].concat(root.sources.map(x => x.id));
        let i = -1;
        if (w === "auto" || w === "0" || w === "a") i = 0;
        else if (w === "next" || w === "prev" || w === "previous") {
            let at = ids.indexOf(root.pinnedId);
            if (at < 0) at = 0;
            i = (at + (w === "next" ? 1 : ids.length - 1)) % ids.length;
        } else if (/^[0-9]+$/.test(w)) i = Number(w);
        if (i < 0 || i >= ids.length) return "no source " + which + " (" + root.sources.length + " sources; nowplaying sources)";
        const chosen = i > 0 ? root.sources[i - 1] : null, n = root.sources.length;
        choose(ids[i]);
        return !chosen ? "auto" + (root.hasMedia ? ": " + root.sourceLabel + " " + root.shownIndex + "/" + root.sources.length : "")
                       : "pinned " + i + "/" + n + ": " + chosen.label + " " + chosen.title;
    }
    function sourcesText() {
        if (!root.on) return "the PiP is off (nowplaying on)";
        const lines = [(root.auto ? "* " : "  ") + "0 auto" + (root.auto && root.hasMedia ? "   showing " + (root.shownIndex || "?") + ": " + root.sourceLabel : "")];
        root.sources.forEach((x, k) => lines.push((x.id === root.pinnedId ? "* " : "  ") + (k + 1) + " " + x.label + "  "
            + (x.paused ? "paused " : "playing") + "  " + (x.title.length > 60 ? x.title.slice(0, 59) + "…" : x.title)
            + (x.artist.length ? " — " + x.artist : "") + (x.id === root.shownId ? "  [shown]" : "")));
        if (!root.sources.length) lines.push("  (nothing plays)");
        return lines.join("\n");
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
        if (!root.on) { root.cur = { kind: "none" }; if (root.sources.length) root.sources = []; return; }
        const now = Date.now();
        const ds = root.daemonState;
        const srcs = buildSources(ds, now, root.noMpris ? null : MusicService.players);
        root.sources = srcs;
        // the pinned source; released when it has been gone for 3 s (a reload starts with an empty list: give it time)
        let pin = null;
        if (root.pinnedId.length) {
            pin = srcs.find(x => x.id === root.pinnedId) || null;
            if (pin) root._pinMissingSince = 0;
            else if (!root._pinMissingSince) root._pinMissingSince = now;
            else if (now - root._pinMissingSince > 3000 && (root.noDaemon || now - root.daemonSince > 20000)) { console.info("nowplaying: source gone, back to Auto:", root.pinnedId); root.pinnedId = ""; root._pinMissingSince = 0; }
        }
        const b = pin && pin.kind === "bridge" ? pin.data : (ds && ds.bridge ? ds.bridge : null);
        const fresh = bridgeFresh(b, now);
        const mp = root.noMpris ? null : (pin && pin.kind === "mpris" ? pin.player : MusicService.player);
        const mpPlaying = !!mp && mp.isPlaying;
        let c = { kind: "none" };
        const fromBridge = (bb, p) => ({
            kind: "bridge", site: bb.site, key: bb.key || "", title: bb.title || (p ? p.trackTitle : "") || "",
            artist: bb.author || (p ? p.trackArtist : "") || "", artUrl: bb.thumbnail || (p ? p.trackArtUrl : "") || "",
            isVideo: !!bb.isVideo, live: !!bb.live, ad: !!bb.ad, paused: !!bb.paused, buffering: !!bb.buffering && !bb.paused,
            position: Number(bb.position) || 0,
            ts: Math.min(Number(bb.ts) || Number(bb.received) || now, now), rate: Number(bb.rate) || 1, duration: Number(bb.duration) || 0,
            width: bb.width || 0, height: bb.height || 0, shorts: /\/shorts\//.test(bb.pageUrl || ""), player: p, browser: true,
            tab: bb.tab || "", tt: bb.tt || null, bv: bb.bv || "", sourceId: "tab:" + (bb.tab || "")
        });
        if (pin && pin.kind === "bridge") {
            // the pinned tab: the browser's player only when it follows this tab (same title), its clock only when the report is old
            const p = root.noMpris ? null : (MusicService.players.filter(x => isBrowserPlayer(x)).find(x => sameTitle(x.trackTitle, b.title)) || null);
            c = fromBridge(b, p);
            if (p && now - (b.received || 0) > 3500 && (!p.isPlaying) !== c.paused) {
                c.paused = !p.isPlaying; c.buffering = false; c.ts = now; c.rate = p.rate || 1;
                c.position = p.positionSupported ? p.position : c.position;
            }
        } else if (pin && pin.kind === "mpris") {
            c = fromMpris(mp, now);
        } else if (fresh && !b.paused) {
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
                c = fromMpris(mp, now);
            }
        } else if (fresh && (root.noMpris || MusicService.players.some(p => isBrowserPlayer(p)))) {
            // a paused report only while the browser still has a media session (a quit / crashed browser sends no "gone")
            c = fromBridge(b, browserPlayer(b.title));
        }
        if (c.kind !== "none" && !c.title.length && !c.artUrl.length && !c.key.length) c = { kind: "none" };
        // the mirror video for this key
        const v = c.key && ds && ds.videos ? ds.videos[c.key] : null;
        c.videoStatus = c.kind === "none" ? "none" : (v ? v.status : (c.key && b && b.key === c.key ? (ds.videoStatus || "none") : "none"));
        c.videoFile = root.videoEnabled && v && v.status === "ready" && v.file && v.mode !== "parts" ? v.file : "";
        // the ready parts of a long video (sorted by start), or the whole file as one part: what the mirror plays
        c.videoMode = v && v.mode === "parts" ? "parts" : "whole";
        c.videoParts = c.videoMode === "parts" && Array.isArray(v.parts) ? v.parts : [];
        const readyParts = root.videoEnabled ? c.videoParts.filter(x => x && x.status === "ready" && x.file && x.dur > 0)
                                                     .map(x => ({ start: Number(x.start) || 0, dur: Number(x.dur) || 0, file: String(x.file) }))
                                                     .sort((a, b) => a.start - b.start) : [];
        c.mirrorParts = c.videoFile.length ? [{ start: 0, dur: 0, file: c.videoFile }] : readyParts;
        if (v && v.width > 0 && v.height > 0) { c.width = v.width; c.height = v.height; c.isVideo = true; }
        if (c.kind === "mpris" && c.key && v && v.duration > 0 && !c.duration) c.duration = v.duration;
        root.cur = c;
        if (c.kind !== "none") root.last = c;
        // ask the daemon for a YouTube video the userscript does not report (MPRIS only), and tell it what is on screen
        if (c.kind === "mpris" && c.youtubeId && c.isVideo && daemon.running && root.videoEnabled) {
            if (c.duration > root.maxVideoMin * 60) {
                const w = longWant(c, now);
                if (w) send(w);
            } else if (!v && root._wanted !== c.key) {
                root._wanted = c.key;
                send({ cmd: "want", site: "youtube", id: c.youtubeId, duration: c.duration || 0 });
            }
        }
        if (c.key && c.key !== root._active && daemon.running) { root._active = c.key; send({ cmd: "active", key: c.key }); }
        // a pinned tab is pinned in the daemon too (its video gets fetched); anything else = the daemon's own choice
        const wantPin = root.pinnedId.indexOf("tab:") === 0 ? root.pinnedId.slice(4) : "";
        if (wantPin !== root._sentPin && daemon.running) { root._sentPin = wantPin; send({ cmd: "pin", tab: wantPin.length ? wantPin : null }); }
    }
    // a long MPRIS-only YouTube video is fetched in parts around its position, which only the shell knows: `want` with the position,
    // again every 5 s and at once on a pause / play or a jump of more than 3 s (null = nothing to send now)
    function longWant(c, now) {
        const pos = c.paused ? c.position : c.position + Math.max(0, (now - c.ts) / 1000) * c.rate;
        const predicted = root._wantPaused ? root._wantPos : root._wantPos + (now - root._wantAt) / 1000 * root._wantRate;
        if (root._wanted === c.key && now - root._wantAt < 5000 && root._wantPaused === c.paused && Math.abs(pos - predicted) <= 3) return null;
        root._wanted = c.key; root._wantAt = now; root._wantPos = pos; root._wantPaused = c.paused; root._wantRate = c.rate;
        return { cmd: "want", site: "youtube", id: c.youtubeId, duration: c.duration, position: Math.round(pos * 10) / 10,
                 paused: c.paused, rate: c.rate };
    }
    property string _wanted: ""
    property real _wantAt: 0
    property real _wantPos: 0
    property bool _wantPaused: false
    property real _wantRate: 1
    property string _active: ""
    function fromMpris(mp, now) {
        const browser = isBrowserPlayer(mp);
        const yt = browser ? youtubeFromUrl(mprisUrl(mp)) : null;
        if (!mp.isPlaying && mp.playbackState === MprisPlaybackState.Stopped) return { kind: "none" };
        return {
            kind: "mpris", site: yt ? yt.site : (browser ? "other" : siteOfPlayer(mp)), key: yt ? "youtube-" + yt.id : "",
            title: mp.trackTitle || mp.identity || "", artist: mp.trackArtist || "", artUrl: mp.trackArtUrl || "",
            isVideo: !!yt && yt.site === "youtube", live: false, ad: false, paused: !mp.isPlaying,
            position: mp.positionSupported ? mp.position : 0, ts: now, rate: mp.rate || 1,
            duration: mp.lengthSupported ? mp.length : 0, width: 0, height: 0, shorts: !!yt && yt.shorts, player: mp, browser: browser,
            youtubeId: yt ? yt.id : "", sourceId: playerId(mp)
        };
    }

    // ------------------------------------------------------------------ what the view binds to
    readonly property bool hasMedia: cur.kind !== "none"
    readonly property var view: hasMedia ? cur : last
    readonly property string title: view.title || ""
    readonly property string artist: view.artist || ""
    readonly property string site: view.site || "other"
    readonly property string artUrl: view.artUrl || ""
    readonly property string videoFile: view.videoFile || ""
    readonly property string videoStatus: view.videoStatus || "none"
    readonly property var mirrorParts: view.mirrorParts || []
    readonly property bool videoInParts: view.videoMode === "parts"
    // "parts 2/3 ready": parts on disk / all (incl. the one being fetched), and whether one covers the position
    readonly property string partsText: {
        if (!videoInParts) return "";
        const all = view.videoParts || [];
        return "parts " + all.filter(x => x.status === "ready").length + "/" + all.length + " " + videoStatus;
    }
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
    readonly property string sourceLabel: siteLabel(site, view.player || null)
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
    property var testToplevel: null   // tests: a stand-in for the active window {lastIpcObject: {class, fullscreen}, wayland: {fullscreen}}
    readonly property var activeTl: testToplevel || Hyprland.activeToplevel
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
        // Hyprland's fullscreen mode is a bit field: 1 = maximized, 2 = fullscreen. A maximized browser is not "fullscreen",
        // so only bit 2 counts (`> 0` hid the mini-player whenever the source window was merely maximized).
        const fs = (t.wayland && t.wayland.fullscreen) || ((Number((t.lastIpcObject || {}).fullscreen) || 0) & 2) !== 0;
        return fs && matchesSource(clsOf(t));
    }
    readonly property bool hiddenByFullscreen: hideWhenSourceFullscreen && sourceFullscreen
    // lastIpcObject is a snapshot: Quickshell re-reads it only on refreshToplevels(), and nothing refreshes it on a fullscreen
    // change, so leaving a fullscreen video kept the PiP hidden (seen with Chrome: fs=0 live, still "source fullscreen").
    // Re-read the toplevels when fullscreen toggles or focus moves (debounced; refreshToplevels answers asynchronously).
    Timer { id: fsRefresh; interval: 150; onTriggered: Hyprland.refreshToplevels() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "fullscreen" || n === "activewindowv2") fsRefresh.restart();
        }
    }
    readonly property bool revealed: now < revealUntil
    readonly property bool shown: on && !hiddenByFullscreen && (hasMedia || lingering || revealed)
    function reveal() { pickScreen(); if (!on) setOn(true); root.now = Date.now(); root.revealUntil = Date.now() + Math.max(4, autoHideSec) * 1000; }

    // ------------------------------------------------------------------ controls (on the SHOWN source) and focus
    // route: "mpris" = the source's MPRIS player (a player source, or the browser's player follows this tab: same title);
    //        "tab"   = that tab's own player through the daemon (a pinned tab, or Auto with several tabs, that the browser's player
    //                  does not follow; bridge 1.4.0+); "none" = no controls (a pinned tab with an older bridge)
    readonly property bool mprisFollows: hasMedia && !!view.player && (view.kind === "mpris" || sameTitle(view.player.trackTitle, view.title))
    readonly property bool tabControls: hasMedia && view.kind === "bridge" && !!view.tab && versionAtLeast(view.bv, "1.4.0")
    readonly property string route: !hasMedia ? "none" : mprisFollows ? "mpris"
                                    : tabControls && (!auto || bridgeTabCount > 1 || !view.player) ? "tab"
                                    : auto && view.player ? "mpris" : "none"
    readonly property var controlPlayer: route === "mpris" ? view.player : null
    readonly property bool canToggle: route === "tab" ? daemonRunning : !!controlPlayer && controlPlayer.canTogglePlaying
    readonly property bool canNext: route === "tab" ? daemonRunning : !!controlPlayer && controlPlayer.canGoNext
    readonly property bool canPrevious: route === "tab" ? daemonRunning : !!controlPlayer && controlPlayer.canGoPrevious
    readonly property string controlsNote: route === "none" && hasMedia && view.kind === "bridge" && !auto
                                           ? "This tab needs the bridge userscript 1.4.0 for its buttons (overworld nowplaying userscript --serve)" : ""
    function act(what) {
        if (what === "like" || what === "repost" || what === "save") return tiktokAct(what);
        if (root.route === "tab") return tabMedia(what === "toggle" ? (root.paused ? "play" : "pause") : what);
        const p = controlPlayer;
        if (!p) return;
        if (ShellState.preview || Quickshell.env("OW_NOWPLAYING_DRYRUN") === "1") { console.warn("DRYRUN nowplaying", what); return; }
        if (what === "toggle" && p.canTogglePlaying) p.togglePlaying();
        else if (what === "next" && p.canGoNext) p.next();
        else if (what === "previous" && p.canGoPrevious) p.previous();
    }
    function tabMedia(what) {   // play / pause / next / previous on the shown tab's own player (the daemon hands it over)
        if (!root.canToggle || ["play", "pause", "next", "previous"].indexOf(what) < 0) return false;
        const cmd = { cmd: "action", tab: root.view.tab, key: root.key, action: what };
        if (root.dryRun) { console.warn("DRYRUN nowplaying action", JSON.stringify(cmd)); return true; }
        send(cmd);
        root.now = Date.now();
        return true;
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
            parts.push("video " + (videoInParts ? partsText : videoFile.length ? "ready" : videoStatus));
            if (sources.length > 1 || !auto) parts.push("source " + (auto ? "auto " : "pinned ") + (shownIndex || "?") + "/" + sources.length);
            if (canLike) parts.push("TikTok " + [["liked", liked], ["saved", saved], ["reposted", reposted]]
                                   .map(x => (x[1] === true ? "" : x[1] === false ? "not " : "? ") + x[0]).join(" ") + (busy.length ? " (" + busy + "…)" : ""));
        } else parts.push("nothing playing");
        return parts.join(", ");
    }
}
