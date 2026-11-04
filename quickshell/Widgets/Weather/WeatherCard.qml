import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  WeatherCard — the sky window (190 × 140 GUI px).  Data: WeatherService (Open-Meteo, cached, see docs/WIDGETS.md).
 *  Left: SkyWindow (sun/moon on their arc, clouds, rain/snow, lightning) and the place + local time.
 *  Right: the big temperature, the condition with a pixel icon, precipitation / humidity / wind.
 *  Bottom: the next 24 hours as columns of stacked blocks — column height = temperature, block = condition
 *  (sand sunny, lapis clear night, wool clouds, water rain, snow block, ice sleet, gold storm, stone fog).
 *  Hover a column for "14:00 · 26° · 40% rain".  Error state: "Weather unavailable" + Retry.
 */
WidgetCard {
    id: card
    title: "Weather"
    guiW: 190
    guiH: 150

    readonly property var svc: WeatherService
    readonly property bool hasData: svc.ok

    Item {
        anchors.fill: parent
        visible: card.hasData

        SkyWindow { width: Theme.px(84); height: Theme.px(54) }
        McText {
            y: Theme.px(57); width: Theme.px(84)
            text: card.svc.city + "  " + card.svc.localTime
            elide: Text.ElideRight
            color: Theme.guiText
        }

        McText {
            x: Theme.px(90); y: Theme.px(-2)
            units: 3
            text: isNaN(card.svc.temp) ? "—" : Math.round(card.svc.temp) + card.svc.tempUnit
            color: Theme.guiText
        }
        Row {
            x: Theme.px(90); y: Theme.px(26)
            spacing: Theme.px(3)
            Image {
                width: Theme.px(16); height: Theme.px(16)
                source: Qt.resolvedUrl("../assets/weather/" + card.svc.icon + ".png")
                smooth: false
            }
            McText { anchors.verticalCenter: parent.verticalCenter; text: card.svc.condition; width: Theme.px(66); elide: Text.ElideRight; color: Theme.guiText }
        }
        Column {
            x: Theme.px(90); y: Theme.px(44)
            Repeater {
                model: [
                    { k: "Rain", v: card.svc.precipProb + "%" },
                    { k: "Humidity", v: card.svc.humidity + "%" },
                    { k: "Wind", v: Math.round(card.svc.wind) + " km/h" }
                ]
                delegate: Row {
                    required property var modelData
                    spacing: Theme.px(4)
                    McText { text: modelData.k + ":"; color: Theme.textMuted }
                    McText { text: modelData.v; color: Theme.guiText }
                }
            }
        }
        // ---- 24 h columns
        Item {
            id: strip
            y: Theme.px(78); width: Theme.px(176); height: Theme.px(46)
            readonly property var hours: card.svc.hours
            readonly property int pitch: 7                    // GUI px per column
            readonly property real lo: card.svc.minTemp
            readonly property real hi: Math.max(card.svc.maxTemp, lo + 1)
            property int hoverIndex: -1
            readonly property var hov: hoverIndex >= 0 && hoverIndex < hours.length ? hours[hoverIndex] : null

            McText {
                width: parent.width
                color: strip.hov ? Theme.guiText : Theme.textMuted
                elide: Text.ElideRight
                text: strip.hov
                      ? strip.hov.label + " · " + Math.round(strip.hov.temp) + "° · " + card.svc.wordFor(strip.hov.code) + (strip.hov.prob > 0 ? " · " + strip.hov.prob + "%" : "")
                      : "Next 24 h · " + Math.round(strip.lo) + "° to " + Math.round(strip.hi) + "°" + (card.svc.stale ? " · cached" : "")
            }
            Repeater {
                model: strip.hours.length
                delegate: Column {
                    id: col
                    required property int index
                    readonly property var h: strip.hours[index]
                    readonly property int n: 1 + Math.round(5 * (h.temp - strip.lo) / (strip.hi - strip.lo))      // 1…6 blocks
                    x: index * Theme.px(strip.pitch)
                    y: parent.height - height
                    Repeater {
                        model: col.n
                        BlockPatch {
                            required property int index
                            texture: "block/" + col.h.block
                            fallback: card.svc.blockColor(col.h.block)
                            tint: col.h.block === "water_still" ? Theme.water : "transparent"
                            u: 5; v: 5
                            // a lighter cap on the top block, a dark cap row for the hovered column
                            Rectangle { anchors.fill: parent; color: "white"; opacity: strip.hoverIndex === col.index ? 0.35 : 0; z: 2 }
                            Rectangle { visible: index === 0; width: parent.width; height: Theme.gui; color: "white"; opacity: 0.25 }
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onPositionChanged: mouse => strip.hoverIndex = Math.max(0, Math.min(strip.hours.length - 1, Math.floor(mouse.x / Theme.px(strip.pitch))))
                onExited: strip.hoverIndex = -1
            }
        }
    }

    // ---- error / loading
    Column {
        anchors.centerIn: parent
        spacing: Theme.px(4)
        visible: !card.hasData
        McText { anchors.horizontalCenter: parent.horizontalCenter; color: Theme.guiText; text: card.svc.loading && !card.svc.error ? "Checking the sky…" : "Weather unavailable" }
        McText {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.textMuted; text: card.svc.error
            width: Theme.px(150); wrapMode: Text.Wrap; maximumLineCount: 2; horizontalAlignment: Text.AlignHCenter
            visible: card.svc.error.length > 0
        }
        McButton { anchors.horizontalCenter: parent.horizontalCenter; small: true; text: "Retry"; enabled: !card.svc.loading; onClicked: card.svc.refresh() }
    }
}
