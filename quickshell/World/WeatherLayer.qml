import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

/*  WeatherLayer — the weather overlay: Minecraft's rain.png / snow.png tiled over the wallpaper.
 *
 *  Layer `overworld-weather`, level Background: above the wallpaper (awww) and below the widget layer (bottom) and every window.
 *  Click-through (empty input region). Unmapped while the weather is clear / paused, so it costs nothing then.
 *
 *  How it moves: each depth layer is ONE tiled Image (64x256 texture, drawn at an integer scale so the texels stay square) that is
 *  shifted by whole texels once per tick of the 20 TPS clock in WeatherState. Three layers at different scale and speed give the
 *  parallax; the nearest ones are drawn bigger and fall faster. The scene graph redraws 20 times a second, not at 165 Hz.
 *  Thunder = a darker sky + an occasional white flash (WeatherState.flash).
 */
Scope {
    id: root
    readonly property string kind: WeatherState.kind
    readonly property bool raining: kind === "rain" || kind === "thunder"
    readonly property bool snowing: kind === "snow"

    // fade levels (the only thing that animates at the display rate, and only for 1.5 s per change)
    property real rainLevel: WeatherState.wanted && raining ? 1 : 0
    property real snowLevel: WeatherState.wanted && snowing ? 1 : 0
    property real dim: kind === "thunder" ? 0.24 : (kind === "rain" ? 0.12 : 0.03)
    Behavior on rainLevel { NumberAnimation { duration: Theme.reducedMotion ? 0 : 1500 } }
    Behavior on snowLevel { NumberAnimation { duration: Theme.reducedMotion ? 0 : 1500 } }
    Behavior on dim { NumberAnimation { duration: 1500 } }
    readonly property bool drawing: rainLevel > 0 || snowLevel > 0 || WeatherState.flash > 0
    Binding { target: WeatherState; property: "fadingOut"; value: root.drawing && !WeatherState.wanted }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "overworld-weather"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}
            visible: root.drawing

            // ---- rain: three depth layers (texels per tick are whole numbers, so every step lands on a texel)
            Item {
                anchors.fill: parent
                visible: root.rainLevel > 0
                opacity: root.rainLevel
                Rectangle { anchors.fill: parent; color: "#000000"; opacity: root.dim }
                Repeater {
                    model: [
                        { s: Theme.gui,     speed: 6, alpha: 0.55, dx: 11 },
                        { s: Theme.gui + 1, speed: 7, alpha: 0.80, dx: 37 },
                        { s: Theme.gui + 2, speed: 8, alpha: 1.00, dx: 23 }
                    ]
                    TileLayer {
                        required property int index
                        required property var modelData
                        visible: index < WeatherState.layersWanted
                        source: Theme.tex("environment/rain")
                        texScale: modelData.s
                        texelsPerTick: modelData.speed
                        phaseX: modelData.dx
                        angle: 8
                        opacity: modelData.alpha
                        frame: WeatherState.frame
                    }
                }
            }

            // ---- snow: slower, with a sideways sway
            Item {
                anchors.fill: parent
                visible: root.snowLevel > 0
                opacity: root.snowLevel
                Rectangle { anchors.fill: parent; color: "#10202f"; opacity: root.dim }
                Repeater {
                    model: [
                        { s: Theme.gui,     speed: 1, sway: 5, alpha: 0.70, dx: 5 },
                        { s: Theme.gui + 1, speed: 2, sway: 7, alpha: 0.85, dx: 29 },
                        { s: Theme.gui + 2, speed: 2, sway: 9, alpha: 1.00, dx: 53 }
                    ]
                    TileLayer {
                        required property int index
                        required property var modelData
                        visible: index < Math.max(2, WeatherState.layersWanted)
                        source: Theme.tex("environment/snow")
                        texScale: modelData.s
                        texelsPerTick: modelData.speed
                        phaseX: modelData.dx
                        swayTexels: modelData.sway
                        opacity: modelData.alpha
                        frame: WeatherState.frame
                    }
                }
            }

            // ---- lightning
            Rectangle {
                anchors.fill: parent
                color: "#ffffff"
                opacity: WeatherState.flash
                visible: WeatherState.flash > 0
            }
        }
    }

    // One tiled, scaled, optionally slanted layer
    component TileLayer: Item {
        id: tl
        property url source
        property int texScale: 2
        property int texelsPerTick: 6
        property int phaseX: 0
        property real angle: 0
        property int swayTexels: 0
        property int frame: 0
        readonly property int tw: 64
        readonly property int th: 256
        anchors.fill: parent
        rotation: angle
        Item {
            x: -parent.width * 0.35
            y: -parent.height * 0.35
            width: parent.width * 1.7
            height: parent.height * 1.7
            Item {
                id: scaler
                scale: tl.texScale
                transformOrigin: Item.TopLeft
                Image {
                    source: tl.source
                    fillMode: Image.Tile
                    smooth: tl.angle !== 0
                    mipmap: false
                    cache: true
                    asynchronous: false
                    width: (parent.parent.width / tl.texScale) + 2 * tl.tw
                    height: (parent.parent.height / tl.texScale) + 2 * tl.th
                    x: -tl.tw + ((tl.phaseX + (tl.swayTexels > 0 ? Math.round(Math.sin(tl.frame / 14) * tl.swayTexels) : 0)) % tl.tw)
                    y: -tl.th + ((tl.frame * tl.texelsPerTick) % tl.th)
                }
            }
        }
    }
}
