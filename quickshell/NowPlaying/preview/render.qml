//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import Quickshell
import qs.Common
import qs.NowPlaying

/*  Offscreen render of the mini-player with a mock model (nothing live is read or touched):
 *    OW_NP_CASE=landscape|portrait|spotify|hover|paused|fetching|live|nothing|narrow  OW_MODE=light|dark  OW_RENDER_OUT=<png>
 *      TikTok buttons (hovered, logged in): tt-off|tt-on|tt-busy|tt-unknown|tt-error|tt-min (portrait at the smallest size)|tt-wide
 *      (a landscape clip at the smallest size)
 *      Several sources (hovered): src-chip (3 sources, Auto) | src-list (the list open, pinned to 2) | src-one (1 source: no chip) |
 *      src-min-chip / src-min-list (a TikTok portrait clip at the smallest size) | src-wide-list (a landscape clip at the smallest size)
 *    OW_NP_STILL=<png> (a frame of a real cached video, the stand-in for the VideoOutput, which offscreen grabs cannot capture)
 *    OW_NP_THUMB=<img>  OW_RENDER_BG=<wallpaper>  QT_QPA_PLATFORM=offscreen qs -p quickshell/NowPlaying/preview/render.qml
 */
ShellRoot {
    id: shell
    readonly property string kase: Quickshell.env("OW_NP_CASE") || "landscape"
    readonly property bool tt: kase.indexOf("tt-") === 0
    readonly property bool src: kase.indexOf("src-") === 0
    readonly property bool srcPortrait: kase === "src-min-chip" || kase === "src-min-list"
    QtObject {
        id: mock
        property real aspect: shell.kase === "tt-wide" ? 16 / 9 : shell.tt || shell.srcPortrait || shell.kase === "portrait" ? 9 / 16 : shell.kase === "spotify" || shell.kase === "nothing" ? 1 : 16 / 9
        property bool hasMedia: shell.kase !== "nothing"
        property bool paused: shell.kase === "paused" || !hasMedia
        property string title: shell.tt ? "pov: you finally beat the ender dragon 🐉 #minecraft #speedrun" : ({ portrait: "pov: you finally beat the ender dragon 🐉 #minecraft #speedrun",
                                  spotify: "Pigstep (Stereo Mix)", live: "Lofi beats to mine and craft to - 24/7 radio",
                                  nothing: "Pigstep (Stereo Mix)" })[shell.kase] || "Me at the zoo"
        property string artist: shell.tt ? "blocky.builds" : ({ portrait: "blocky.builds", spotify: "Lena Raine", live: "Chill Biome", nothing: "Lena Raine" })[shell.kase] || "jawed"
        property string site: shell.tt || shell.srcPortrait ? "tiktok" : ({ portrait: "tiktok", spotify: "spotify", nothing: "spotify" })[shell.kase] || "youtube"
        property string sourceLabel: ({ youtube: "YouTube", tiktok: "TikTok", spotify: "Spotify" })[site]
        property string artUrl: shell.kase === "spotify" || shell.kase === "nothing" ? Theme.tex("painting/kebab")
                                : Quickshell.env("OW_NP_THUMB") ? "file://" + Quickshell.env("OW_NP_THUMB") : ""
        property string videoFile: ""
        property string videoStatus: shell.kase === "fetching" ? "fetching" : "ready"
        property bool isVideo: site !== "spotify"
        property bool live: shell.kase === "live"
        property bool ad: false
        property real duration: shell.kase === "live" ? 0 : shell.kase === "portrait" || shell.tt ? 34 : shell.kase === "spotify" ? 148 : 19
        property var clock: ({ valid: true, position: 7, ts: Date.now(), paused: paused, rate: 1, duration: duration })
        property bool canFocus: true
        property bool canToggle: true
        property bool canNext: site !== "tiktok"
        property bool canPrevious: site !== "tiktok"
        function positionNow() { return shell.kase === "spotify" ? 61 : shell.kase === "portrait" || shell.tt ? 12 : 7 }
        // TikTok like / repost / save
        property bool canLike: shell.tt
        property var liked: ({ "tt-on": true, "tt-busy": true, "tt-unknown": null, "tt-error": true })[shell.kase] ?? false
        property var saved: ({ "tt-on": true, "tt-busy": false, "tt-unknown": null, "tt-error": true })[shell.kase] ?? false
        property var reposted: ({ "tt-on": true, "tt-off": false, "tt-busy": false, "tt-min": false, "tt-wide": true })[shell.kase] ?? null
        property string busy: shell.kase === "tt-busy" ? "save" : ""
        property string actionError: shell.kase === "tt-error" ? "saved to Favorites only: no collection named \"Edits\"" : ""
        property string actionErrorFor: actionError.length ? "save" : ""
        property bool actionErrorFresh: actionError.length > 0
        property string tiktokCollection: "Edits"
        // several sources
        property var sources: shell.kase === "src-one" ? [{ id: "tab:a", kind: "bridge", site: "youtube", label: "YouTube", title: "Me at the zoo", artist: "jawed", paused: false }]
            : !shell.src ? [] : [
            { id: "tab:a", kind: "bridge", site: "youtube", label: "YouTube", title: "Me at the zoo", artist: "jawed", paused: false },
            { id: "tab:b", kind: "bridge", site: "tiktok", label: "TikTok", title: "pov: you finally beat the ender dragon 🐉 #minecraft #speedrun", artist: "blocky.builds", paused: true },
            { id: "mpris:spotify", kind: "mpris", site: "spotify", label: "Spotify", title: "Pigstep (Stereo Mix)", artist: "Lena Raine", paused: true }]
        property int sourceCount: sources.length
        property string pinnedId: shell.kase === "src-list" || shell.kase === "src-wide-list" ? "tab:a" : shell.srcPortrait ? "tab:b" : ""
        property bool auto: pinnedId === ""
        property string shownId: shell.srcPortrait ? "tab:b" : "tab:a"
        property int shownIndex: shell.srcPortrait ? 2 : 1
        property string route: "mpris"
        property string controlsNote: ""
        function choose(id) { console.warn("mock choose", id); return true }
        function pick(w) { console.warn("mock pick", w); return "" }
        function act(what) { console.warn("mock act", what) }
        function fmt(s) { s = Math.floor(s); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
        function focusSource() { console.warn("mock focus") }
        function togglePlaying() {} function next() {} function previous() {}
    }
    Window {
        id: win
        width: 560; height: shell.kase === "portrait" || shell.srcPortrait || (shell.tt && shell.kase !== "tt-wide") ? 520 : 420
        visible: true
        color: "#4E6B45"
        Item {
            id: stage
            anchors.fill: parent
            Image {
                anchors.fill: parent
                source: Quickshell.env("OW_RENDER_BG") ? "file://" + Quickshell.env("OW_RENDER_BG") : ""
                fillMode: Image.PreserveAspectCrop
            }
            NowPlayingView {
                id: view
                np: mock
                x: 40; y: 30
                boxW: shell.kase === "narrow" ? 220 : shell.kase === "tt-min" || shell.kase === "tt-wide" || shell.srcPortrait || shell.kase === "src-wide-list" ? 200 : 360
                mirrorEnabled: false
                frameStill: shell.src ? (Quickshell.env(shell.srcPortrait ? "OW_NP_STILL916" : "OW_NP_STILL169") || "") : shell.kase === "tt-wide" ? (Quickshell.env("OW_NP_STILL169") || "") : shell.kase === "fetching" || shell.kase === "spotify" || shell.kase === "nothing" ? "" : (Quickshell.env("OW_NP_STILL") || "")
                forceHover: shell.kase === "hover" || shell.tt || shell.src
                forceList: shell.kase === "src-list" || shell.kase === "src-min-list" || shell.kase === "src-wide-list"
            }
        }
        Timer {
            interval: 1500; running: true
            onTriggered: stage.grabToImage(r => {
                const out = Quickshell.env("OW_RENDER_OUT") || "/tmp/np-render.png";
                console.warn("render: saved", r.saveToFile(out), out, "view", view.width + "x" + view.height);
                Qt.quit();
            })
        }
    }
}
