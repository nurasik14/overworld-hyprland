import QtQuick
import QtQuick.Effects
import qs.Common
import qs.NowPlaying

/*  NowPlayingView — the mini-player itself: a painting on a GUI panel.
 *    ┌ McPanel (see-through like the widget cards, Day / Night skin) ─────────┐
 *    │ ┌ oak frame ┐  the picture: the silent mirror video (opaque) over the   │
 *    │ │  video    │  thumbnail (fit, with a blurred copy behind for the bars)  │
 *    │ └───────────┘  hover: ⏮ ⏯ ⏭ at the bottom, focus + ✕ top right;         │
 *    │                TikTok (logged in): ♥ ⟲ 🔖 (like / repost / save) above ⏮ ⏯ ⏭  │
 *    │ ▬▬▬▬▬▬ XP-bar progress ▬▬▬▬▬▬                                           │
 *    │ Title (one line)                                                       │
 *    │ 󰗃 Channel / artist                                      1:23 / 4:56 ◢│  ◢ = resize grip (hover)
 *    └────────────────────────────────────────────────────────────────────────┘
 *  Size: `boxW` (screen px) is the width of a 16:9 picture; 9:16 sources get a portrait picture 0.9 × boxW tall, square art
 *  (music) a 0.6 × boxW square. Everything snaps to the GUI scale.
 *  Paused / stopped: the whole thing dims to 72 % (full on hover). Drag anywhere but the buttons; double-click the strip = reset.
 *    np: NowPlayingService or a mock with the same properties (renders)
 *    frameStill: an image shown as the "video" in offscreen renders (VideoOutput cannot be captured offscreen)
 */
Item {
    id: root
    property var np: NowPlayingService
    property int boxW: 360
    property bool forceHover: false
    property string frameStill: ""
    property bool mirrorEnabled: true
    readonly property bool hovered: hover.hovered || forceHover || dragH.active || grip.active
    readonly property bool interacting: dragH.active || grip.active
    signal dragFinished()
    signal resizeFinished(int newBoxW)
    signal resetRequested()
    signal closeRequested()

    readonly property int g: Theme.gui
    function snap(v) { return Math.max(g, Math.round(v / g) * g) }
    readonly property real aspect: Math.max(0.5, Math.min(2.4, np.aspect || 1))
    readonly property string shape: aspect >= 1.2 ? "landscape" : aspect <= 0.85 ? "portrait" : "square"
    readonly property int portraitW: Math.max(Theme.px(70), snap(boxW * 0.9 * aspect))
    readonly property int vidW: shape === "landscape" ? snap(boxW) : shape === "portrait" ? portraitW : snap(boxW * 0.6)
    readonly property int vidH: shape === "landscape" ? snap(boxW / aspect) : shape === "portrait" ? snap(portraitW / aspect) : snap(boxW * 0.6)
    readonly property int pad: Theme.px(4)
    readonly property int frameB: Theme.px(3)
    readonly property int stripH: Theme.px(3 + 5 + 3 + 10 + 10)
    width: vidW + 2 * frameB + 2 * pad
    height: pad + vidH + 2 * frameB + stripH + pad

    readonly property bool dim: (np.paused || !np.hasMedia) && !hovered
    opacity: 1
    property real contentOpacity: dim ? 0.72 : 1
    Behavior on contentOpacity { NumberAnimation { duration: Theme.ms(250); easing.type: Easing.OutQuad } }

    // position clock for the time / progress (the mirror steers itself)
    property real posNow: 0
    Timer {
        interval: 500; repeat: true; triggeredOnStart: true
        running: root.visible && root.np.hasMedia
        onTriggered: root.posNow = root.np.positionNow()
    }
    Connections { target: root.np; ignoreUnknownSignals: true; function onClockChanged() { root.posNow = root.np.positionNow() } }

    HoverHandler { id: hover }
    DragHandler {   // move it (anywhere but the buttons and the grip)
        id: dragH
        target: root
        dragThreshold: 3
        xAxis.minimum: 0
        xAxis.maximum: (root.parent ? root.parent.width : 1920) - root.width
        yAxis.minimum: 0
        yAxis.maximum: (root.parent ? root.parent.height : 1080) - root.height
        onActiveChanged: if (!active) root.dragFinished()
    }

    Item {
        anchors.fill: parent
        opacity: root.contentOpacity

        McPanel {
            id: panel
            anchors.fill: parent
            padding: root.pad
            fillOpacity: Math.max(0.2, Math.min(1, Theme.widgetOpacity))
        }

        // ---------------------------------------------------------------- the painting: oak frame + picture
        Item {
            id: frame
            x: root.pad; y: root.pad
            width: root.vidW + 2 * root.frameB
            height: root.vidH + 2 * root.frameB
            Rectangle { anchors.fill: parent; color: "#2A1B0D" }                         // 1 px dark outline
            Rectangle { anchors.fill: parent; anchors.margins: root.g; color: "#9C7F4E" } // planks fallback
            McNineSlice {
                x: root.g; y: root.g
                width: parent.width - 2 * root.g; height: parent.height - 2 * root.g
                source: Theme.tex("block/oak_planks")
                scaling: ({ type: "tile", width: 16, height: 16 })
                visible: Theme.tex("block/oak_planks").toString() !== Theme.missingTexture
            }
            Rectangle {   // the inner bevel: dark top-left, light bottom-right, like a slot
                x: root.frameB - root.g; y: root.frameB - root.g
                width: root.vidW + 2 * root.g; height: root.vidH + 2 * root.g
                color: "#5A3E1E"
                Rectangle { x: root.g; y: root.g; width: parent.width - root.g; height: parent.height - root.g; color: "#C9A86A" }
            }

            Item {
                id: picture
                x: root.frameB; y: root.frameB
                width: root.vidW; height: root.vidH
                clip: true
                Rectangle { anchors.fill: parent; color: "#101010" }

                // thumbnail: a blurred, cropped copy fills the bars; the picture itself fits (or crops when it is a letterboxed 4:3)
                Image {
                    id: thumbBg
                    anchors.fill: parent
                    source: thumb.source
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(96, 96)
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: thumbBg
                    visible: thumb.status === Image.Ready && thumb.fillMode !== Image.PreserveAspectCrop
                    blurEnabled: true; blur: 1.0; blurMax: 40
                    brightness: -0.3; saturation: -0.2
                }
                Image {
                    id: thumb
                    anchors.fill: parent
                    source: root.frameStill.length ? "file://" + root.frameStill : (root.np.artUrl || "")
                    asynchronous: true
                    readonly property bool pixelArt: /\/assets\/(mc|gen)\/textures\//.test(String(source))   // a game texture as cover (demo): keep it crisp
                    mipmap: !pixelArt
                    smooth: !pixelArt
                    sourceSize: pixelArt ? Qt.size(-1, -1) : Qt.size(Math.max(320, root.vidW * 2), Math.max(320, root.vidH * 2))
                    readonly property real ia: implicitHeight > 0 ? implicitWidth / implicitHeight : 0
                    // YouTube's hqdefault.jpg is 4:3 with the 16:9 picture letterboxed inside: crop that; else crop only near-matches
                    fillMode: root.frameStill.length || (ia > 0 && (Math.abs(ia - root.aspect) < 0.2
                              || (Math.abs(ia - 4 / 3) < 0.02 && root.aspect > 1.6 && root.np.site !== "ytmusic")))
                              ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                }
                McItemIcon {   // no picture at all: the record
                    anchors.centerIn: parent
                    visible: thumb.status !== Image.Ready
                    size: 32
                    name: "jukebox"
                }

                VideoMirror {
                    id: mirror
                    anchors.fill: parent
                    active: root.mirrorEnabled && root.visible && root.np.videoFile.length > 0 && !root.np.ad
                    source: active ? root.np.videoFile : ""
                    clock: root.np.clock
                    opacity: ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(250) } }
                }

                // badges
                Rectangle {
                    visible: root.np.live || root.np.ad
                    x: Theme.px(3); y: Theme.px(3)
                    width: badge.implicitWidth + Theme.px(4); height: Theme.px(11)
                    color: root.np.ad ? "#C0A000" : "#C01010"
                    McText { id: badge; x: Theme.px(2); y: Theme.px(1); text: root.np.ad ? "Ad" : "LIVE"; color: "#FFFFFF" }
                }
                McText {   // a TikTok like / repost / save just failed: say why for a few seconds (also in the button's tooltip)
                    id: actErrText
                    visible: root.np.actionErrorFresh === true && root.np.canLike === true
                    x: Theme.px(3); width: parent.width - Theme.px(6)
                    anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(35)   // just above the like / repost / save row
                    codes: "§c! §f" + String(root.np.actionError || "")
                    darkGround: true
                    color: "#FFFFFF"
                    shadow: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    z: 1
                }
                McText {   // the mirror video is still on its way
                    visible: !root.hovered && !mirror.ready && root.np.videoStatus === "fetching" && root.np.hasMedia
                    x: Theme.px(3); anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(2)
                    text: "Fetching video…"
                    color: "#E0E0E0"
                    shadow: true
                }
                Item {   // paused / stopped
                    anchors.fill: parent
                    visible: (root.np.paused || !root.np.hasMedia) && !root.hovered
                    Rectangle { anchors.fill: parent; color: "#55000000" }
                    McText {
                        anchors.centerIn: parent
                        text: root.np.hasMedia ? "Paused" : "Stopped"
                        color: "#FFFFFF"
                        units: root.vidW >= Theme.px(150) ? 2 : 1
                    }
                }

                // ---------------------------------------------------------------- hover controls
                Item {
                    anchors.fill: parent
                    opacity: root.hovered ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(150) } }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: ttRow.visible ? Theme.px(40) : Theme.px(24)
                        gradient: Gradient { GradientStop { position: 0; color: "#00000000" } GradientStop { position: 1; color: "#B0000000" } }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: Theme.px(20)
                        gradient: Gradient { GradientStop { position: 0; color: "#90000000" } GradientStop { position: 1; color: "#00000000" } }
                    }
                    Row {
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Theme.px(2)
                        spacing: Theme.px(1)
                        McButton {
                            width: Theme.px(14); height: Theme.px(14); glyph: "󰏌"
                            tooltip: "Show the source window"
                            enabled: root.np.canFocus
                            onClicked: root.np.focusSource()
                        }
                        McButton {
                            width: Theme.px(14); height: Theme.px(14); glyph: "󰅖"
                            tooltip: "Close (turn the PiP off)"
                            onClicked: root.closeRequested()
                        }
                    }
                    Row {   // TikTok, logged in: like / repost / save the clip on screen (the userscript clicks TikTok's own buttons)
                        id: ttRow
                        objectName: "tiktokRow"
                        visible: root.np.canLike === true
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: transport.top; anchors.bottomMargin: Theme.px(2)
                        spacing: Theme.px(2)
                        TtButton {
                            act: "like"; isOn: root.np.liked
                            glyphOff: "󰋕"; glyphOn: "󰋑"; onColor: "#FF5555"
                            nameOff: "Like"; nameOn: "Unlike"; stateOff: "Not liked"; stateOn: "Liked"; stateUnknown: "Like state unknown"
                        }
                        TtButton {
                            act: "repost"; isOn: root.np.reposted
                            glyphOff: "󰕇"; glyphOn: "󰕇"; onColor: "#55FF55"
                            nameOff: "Repost"; nameOn: "Remove repost"; stateOff: "Not reposted"; stateOn: "Reposted"
                            stateUnknown: "Repost state unknown until you use it"
                        }
                        TtButton {
                            act: "save"; isOn: root.np.saved
                            glyphOff: "󰃃"; glyphOn: "󰃀"; onColor: "#FFAA00"
                            readonly property string coll: String(root.np.tiktokCollection || "Edits")
                            nameOff: "Save to " + coll; nameOn: "Un-save"
                            stateOff: "Not saved"; stateOn: "In Favorites. Un-saving removes it from Favorites and every collection"
                            stateUnknown: "Save state unknown"
                        }
                    }
                    Row {
                        id: transport
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(2)
                        spacing: Theme.px(2)
                        readonly property int bw: root.vidW >= Theme.px(90) ? Theme.px(22) : Theme.px(16)
                        McButton { width: parent.bw; height: Theme.px(14); glyph: "󰒮"; tooltip: "Previous"; enabled: root.np.canPrevious; onClicked: root.np.previous() }
                        McButton {
                            width: parent.bw; height: Theme.px(14)
                            glyph: root.np.paused ? "󰐊" : "󰏤"
                            tooltip: root.np.paused ? "Play" : "Pause"
                            enabled: root.np.canToggle
                            onClicked: root.np.togglePlaying()
                        }
                        McButton { width: parent.bw; height: Theme.px(14); glyph: "󰒭"; tooltip: "Next"; enabled: root.np.canNext; onClicked: root.np.next() }
                    }
                }
            }
        }

        // ---------------------------------------------------------------- the strip
        Item {
            id: strip
            x: root.pad; y: frame.y + frame.height + Theme.px(3)
            width: frame.width; height: Theme.px(5 + 3 + 10 + 10)
            McProgressBar {
                id: bar
                width: parent.width
                value: root.np.duration > 0 ? Math.max(0, Math.min(1, root.posNow / root.np.duration)) : 0
                opacity: root.np.duration > 0 && !root.np.live ? 1 : 0.35
            }
            McText {
                id: titleText
                y: Theme.px(8)
                width: parent.width
                text: root.np.title.length ? root.np.title : (root.np.hasMedia ? root.np.sourceLabel : "Nothing playing")
                color: Theme.guiText
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            Item {
                y: Theme.px(18)
                width: parent.width; height: Theme.px(10)
                McText {
                    id: glyphText
                    mono: true
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({ youtube: "󰗃", ytmusic: "󰗃", tiktok: "󰝚", spotify: "󰓇" })[root.np.site] || "󰝚"
                    color: ({ youtube: "#E01010", ytmusic: "#E01010", spotify: "#1DB954",
                              tiktok: Theme.isDark ? "#25F4EE" : "#D0103A" })[root.np.site] || Theme.textMuted
                    shadow: Theme.isDark
                }
                McText {
                    x: glyphText.width + Theme.px(3)
                    width: parent.width - x - (timeText.visible ? timeText.implicitWidth + Theme.px(4) : 0) - (grip.visible ? Theme.px(6) : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.np.artist.length ? root.np.artist : root.np.sourceLabel
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
                McText {
                    id: timeText
                    anchors.right: parent.right; anchors.rightMargin: root.hovered ? Theme.px(6) : 0
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.np.hasMedia && root.width >= Theme.px(150)
                    text: root.np.live ? "LIVE" : root.np.fmt(root.posNow) + (root.np.duration > 0 ? " / " + root.np.fmt(root.np.duration) : "")
                    color: Theme.textMuted
                }
            }
            TapHandler {   // double-click = reset: two taps within 400 ms (tapCount is unreliable)
                property real lastTap: 0
                onTapped: {
                    const t = Date.now();
                    if (t - lastTap < 400) { lastTap = 0; root.resetRequested(); } else lastTap = t;
                }
            }
        }
    }

    // ---------------------------------------------------------------- resize grip (bottom-right corner, keeps the aspect)
    Item {
        id: gripArea
        objectName: "grip"
        width: Theme.px(8); height: Theme.px(8)
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: Theme.px(2)
        visible: root.hovered
        Repeater {   // a stepped triangle, three pixels per step
            model: 3
            Rectangle {
                required property int index
                x: (2 - index) * Theme.px(2) + Theme.px(2); y: index * Theme.px(2) + Theme.px(2)
                width: (index + 1) * Theme.px(2); height: Theme.px(2)
                color: Theme.isDark ? "#E0E0E0" : "#404040"
            }
        }
        HoverHandler { cursorShape: Qt.SizeFDiagCursor }
        DragHandler {
            id: grip
            target: null
            // the view's own DragHandler (same type) would otherwise keep the grab and move the PiP instead of resizing it
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            dragThreshold: 1
            property int startBox: 0
            property real startW: 1
            property real startH: 1
            onActiveChanged: {
                if (active) { startBox = root.boxW; startW = Math.max(1, root.vidW); startH = Math.max(1, root.vidH); }   // only the picture scales
                else root.resizeFinished(root.boxW);
            }
            onTranslationChanged: {
                if (!active) return;
                const fx = (startW + translation.x) / startW, fy = (startH + translation.y) / startH;
                const f = Math.abs(fx - 1) > Math.abs(fy - 1) ? fx : fy;
                root.boxW = Math.round(root.clampBox(startBox * f));
            }
        }
    }
    readonly property alias gripActive: grip.active

    // a TikTok toggle: filled glyph in the game's colour code when on (+ a line under it), outline when off, plain when unknown;
    // while any command runs all three are disabled and the running one shows the hourglass
    component TtButton: McButton {
        id: tb
        property string act: ""
        property var isOn: null            // true / false / null (unknown)
        property string glyphOn: ""
        property string glyphOff: ""
        property color onColor: "#FFFFFF"
        property string nameOn: ""
        property string nameOff: ""
        property string stateOn: ""
        property string stateOff: ""
        property string stateUnknown: ""
        readonly property string busyWith: String(root.np.busy || "")
        readonly property bool running: busyWith === act
        readonly property string err: String(root.np.actionErrorFor || "") === act ? String(root.np.actionError || "") : ""
        width: transport.bw; height: Theme.px(14)
        enabled: busyWith.length === 0
        opacity: busyWith.length > 0 && !running ? 0.6 : 1
        glyph: running ? "󰔟" : isOn === true ? glyphOn : glyphOff
        labelColor: !enabled ? Theme.buttonTextDisabled : isOn === true ? onColor : Theme.buttonText
        tooltip: isOn === true ? nameOn : nameOff
        tooltipDescription: (isOn === true ? stateOn : isOn === false ? stateOff : stateUnknown) + (err.length ? "\n! " + err : "")
        tooltipCategory: "TikTok"
        onClicked: root.np.act(act)
        Rectangle {   // "on": a line in the colour under the glyph
            visible: tb.isOn === true && !tb.running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(1)
            width: Theme.px(8); height: Theme.gui
            color: tb.onColor
        }
    }
    // min 200, max 960, and never larger than the screen allows from the current corner
    function clampBox(b) {
        const pw = root.parent ? root.parent.width : 1920, ph = root.parent ? root.parent.height : 1080;
        let hi = 960;
        for (let i = 0; i < 4; i++) {   // the panel scales roughly linearly with boxW: shrink the bound until it fits
            const sc = hi / Math.max(1, root.boxW);
            if (root.x + root.width * sc <= pw && root.y + root.height * sc <= ph) break;
            hi = Math.max(200, hi * Math.min((pw - root.x) / Math.max(1, root.width * sc), (ph - root.y) / Math.max(1, root.height * sc)));
        }
        return Math.max(200, Math.min(hi, b));
    }
}
