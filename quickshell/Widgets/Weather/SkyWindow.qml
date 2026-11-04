import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  SkyWindow — a window onto the sky at the weather's location: wooden frame, sky colour by condition and hour, the sun
 *  (environment/celestial/sun) or the moon (the real phase) travelling its arc, pixel clouds drifting, rain / snow
 *  textures falling in tick steps, lightning flashes for thunder, fog bands, and a grass (or snow) strip at the bottom.
 *  Everything steps on the 20 TPS clock; reduced motion freezes the scene on its first frame.
 *  Size it in GUI px (the card uses 84 × 54).
 */
Item {
    id: root
    readonly property var svc: WeatherService
    // overridable so a preview can show every condition side by side; they follow the service by default
    property string kind: svc.kind
    property bool day: svc.isDay
    property int code: svc.code
    property real hourOverride: -1
    readonly property int frameW: 3                       // frame thickness, GUI px
    property int tickN: clock.tick
    McTicker { id: clock; active: root.visible && !Theme.reducedMotion }

    // ---- sky colour
    readonly property color skyColor: {
        const d = {
            clear: "#78A7FF", cloudy: "#8FA6CC", rain: "#6C7C96", thunder: "#4D566C", snow: "#B4C2D6", fog: "#BCC4CC"
        };
        const n = {
            clear: "#0B0E2A", cloudy: "#1A2040", rain: "#151B2E", thunder: "#10111F", snow: "#2B3556", fog: "#2C313C"
        };
        return (day ? d : n)[kind] || (day ? "#78A7FF" : "#0B0E2A");
    }
    readonly property bool overcast: code === 3 || kind === "rain" || kind === "thunder" || kind === "snow"
    readonly property real hourNow: {
        if (hourOverride >= 0) return hourOverride;
        const p = svc.localTime.split(":");
        return p.length === 2 ? parseInt(p[0]) + parseInt(p[1]) / 60 : 12;
    }
    // the real moon phase (synodic month from the new moon of 2000-01-06 18:14 UTC)
    readonly property string moonFile: {
        const names = ["new_moon", "waxing_crescent", "first_quarter", "waxing_gibbous", "full_moon", "waning_gibbous", "third_quarter", "waning_crescent"];
        const syn = 29.530588853;
        const days = svc.now.getTime() / 86400000 - 10957.76;
        const age = ((days % syn) + syn) % syn;
        return names[Math.floor(age / syn * 8 + 0.5) % 8];
    }

    // ---- frame (planks, 1 GUI px dark outline) and the glass inset
    Rectangle { anchors.fill: parent; color: "#3A2A16" }
    Rectangle { x: Theme.gui; y: Theme.gui; width: parent.width - 2 * Theme.gui; height: parent.height - 2 * Theme.gui; color: "#A07F4A" }   // fallback oak
    Image {
        x: Theme.gui; y: Theme.gui; width: parent.width - 2 * Theme.gui; height: parent.height - 2 * Theme.gui
        source: Theme.tex("block/oak_planks"); fillMode: Image.Tile; smooth: false
        visible: source.toString() !== Theme.missingTexture
    }
    Item {
        id: pane
        x: Theme.px(root.frameW); y: Theme.px(root.frameW)
        width: root.width - Theme.px(2 * root.frameW); height: root.height - Theme.px(2 * root.frameW)
        clip: true

        Rectangle { anchors.fill: parent; color: root.skyColor }

        // stars (clear nights, and thin cloud)
        Repeater {
            model: !root.day && (root.kind === "clear" || root.code === 2) ? 14 : 0
            Rectangle {
                required property int index
                readonly property int tw: (root.tickN + index * 7) % 60
                x: ((index * 37 + 11) % 73) * Theme.gui; y: ((index * 23 + 5) % 30) * Theme.gui
                width: Theme.gui; height: Theme.gui
                color: "white"; opacity: tw < 4 ? 0.35 : 0.9
            }
        }

        // sun / moon on their arcs
        KeyedSprite {
            id: body
            readonly property real frac: root.day ? Math.max(0, Math.min(1, (root.hourNow - 6) / 12)) : ((root.hourNow >= 18 ? root.hourNow - 18 : root.hourNow + 6) / 12)
            width: Theme.px(32) / 2 * Math.max(1, Math.floor(Theme.gui / 2)) * 2; height: width        // 1 texel = 1 screen px at GUI 2
            x: Math.round((pane.width - width) * (0.04 + 0.92 * frac) / Theme.gui) * Theme.gui
            // centre on the horizon (the grass line) at dawn / dusk, high at noon / midnight
            y: Math.round((pane.height - Theme.px(8) - Math.sin(frac * Math.PI) * (pane.height - Theme.px(30)) - height / 2) / Theme.gui) * Theme.gui
            file: Theme.tex(root.day ? "environment/celestial/sun" : "environment/celestial/moon/" + root.moonFile)
            opacity: root.kind === "thunder" ? 0.35 : root.overcast ? 0.55 : 1
        }

        // clouds: my pixel cloud, 2 GUI px per texel, drifting left a texel every few ticks
        Repeater {
            model: root.kind === "clear" ? (root.code === 1 ? 1 : 0) : root.code === 2 ? 2 : (root.kind === "fog" ? 1 : 4)
            Image {
                required property int index
                readonly property real speed: 5 + index * 3                     // ticks per texel step
                readonly property int span: pane.width + width
                source: Qt.resolvedUrl("../assets/weather/cloud.png")
                width: Theme.px(24 + (index % 2) * 8); height: width
                smooth: false
                x: pane.width - ((Math.floor(root.tickN / speed) * Theme.gui + index * 61 * Theme.gui) % span)
                y: Theme.px(2 + (index * 11) % 20)
                opacity: root.day ? 0.95 : 0.35
                layer.enabled: false
            }
        }

        // rain / snow: the game's own textures scrolled in tick steps (two offset layers for density)
        Item {
            visible: root.kind === "rain" || root.kind === "thunder"
            anchors.fill: parent
            clip: true
            Repeater {
                model: 2
                Image {
                    required property int index
                    x: -Theme.px(index * 23)
                    y: -Theme.px(256) + (root.tickN * Theme.px(index === 0 ? 9 : 6) + index * Theme.px(97)) % Theme.px(256)
                    width: pane.width + Theme.px(64); height: pane.height + Theme.px(256)
                    source: Theme.tex("environment/rain"); fillMode: Image.Tile; smooth: false
                    opacity: index === 0 ? 0.95 : 0.7
                }
            }
        }
        Item {
            visible: root.kind === "snow"
            anchors.fill: parent
            clip: true
            Repeater {
                model: 2
                Image {
                    required property int index
                    x: -Theme.px(index * 17) + Math.round(Math.sin((root.tickN + index * 20) / 14) * 3) * Theme.gui
                    y: -Theme.px(256) + (root.tickN * Theme.px(index === 0 ? 2 : 1) + index * Theme.px(113)) % Theme.px(256)
                    width: pane.width + Theme.px(64); height: pane.height + Theme.px(256)
                    source: Theme.tex("environment/snow"); fillMode: Image.Tile; smooth: false
                    opacity: index === 0 ? 1 : 0.7
                }
            }
        }
        // fog: soft translucent bands (hard-edged, in 2 px steps)
        Repeater {
            model: root.kind === "fog" ? 4 : 0
            Rectangle {
                required property int index
                x: -Theme.px(10) + (Math.floor(root.tickN / (6 + index)) % 20) * Theme.gui * (index % 2 ? -1 : 1)
                y: Theme.px(8 + index * 9); width: pane.width + Theme.px(20); height: Theme.px(5)
                color: root.day ? "#E6EAEE" : "#6B7280"; opacity: 0.55
            }
        }
        // lightning: two quick white flashes every ~6 s
        Rectangle {
            anchors.fill: parent; color: "white"
            readonly property int t: root.tickN % 130
            visible: root.kind === "thunder"
            opacity: (t === 0 || t === 1) ? 0.85 : (t === 4 || t === 5) ? 0.5 : 0
        }

        // ground: grass (snow-capped when it snows) over dirt
        Item {
            width: pane.width; height: Theme.px(7); y: pane.height - height
            Rectangle { anchors.fill: parent; color: "#866043" }
            Image { anchors.fill: parent; source: Theme.tex("block/dirt"); fillMode: Image.Tile; smooth: false; visible: source.toString() !== Theme.missingTexture }
            Rectangle { width: parent.width; height: Theme.px(2); color: root.kind === "snow" ? "#F4F8FF" : (root.day ? "#6FAF52" : "#3C6B33") }
            Rectangle { width: parent.width; height: Theme.px(1); y: Theme.px(2); color: root.kind === "snow" ? "#C9D6E8" : (root.day ? "#58913F" : "#2F5528") }
        }
        // night shade over the whole pane's ground keeps the scene readable
        Rectangle { anchors.fill: parent; color: "#000020"; opacity: root.day ? 0 : 0.12 }
    }
    // glass edge: dark shadow top/left, light bottom/right like an inventory inset
    Rectangle { x: Theme.px(root.frameW); y: Theme.px(root.frameW); width: pane.width; height: Theme.gui; color: "#26000000" }
    Rectangle { x: Theme.px(root.frameW); y: Theme.px(root.frameW); width: Theme.gui; height: pane.height; color: "#26000000" }
}
