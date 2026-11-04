import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  WeatherCard — 天气 · WEATHER (460 × 300).  Data: WeatherService (Open-Meteo).
 *  Top-left: glyph + big temperature · top-right: city, local time, condition.
 *  Three mono lines (precipitation %, humidity %, wind km/h) and a 24-bar hourly temperature strip
 *  (hover a bar → "14:00 · 26°").  Error state: "Weather unavailable · 雲" + Retry.
 */
WidgetCard {
    id: card
    title: "天气"
    subtitle: "Weather"
    sealGlyph: "印"
    width: 460
    height: 300

    readonly property var svc: WeatherService
    readonly property bool hasData: svc.ok

    Item {
        anchors.fill: parent
        visible: card.hasData

        // ---- top row
        Row {
            id: topLeft
            anchors.left: parent.left; anchors.top: parent.top
            spacing: Theme.space.md
            Text {
                text: card.svc.glyph
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 44
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                InkText {
                    role: "weather_temp"
                    text: isNaN(card.svc.temp) ? "—" : Math.round(card.svc.temp).toString()
                    anchors.verticalCenter: parent.verticalCenter
                }
                InkText {
                    role: "title"
                    text: card.svc.tempUnit
                    muted: true
                    anchors.top: parent.top
                    anchors.topMargin: 10
                }
            }
        }
        Column {
            id: topRight
            anchors.right: parent.right; anchors.top: parent.top
            anchors.topMargin: 2
            spacing: 2
            InkText {
                role: "title"
                text: card.svc.city
                font.pixelSize: 24
                anchors.right: parent.right
                horizontalAlignment: Text.AlignRight
                width: Math.min(implicitWidth, 230)
            }
            Text {
                text: card.svc.localTime + (card.svc.stale ? "  · cached" : "")
                color: Theme.textMuted
                font.family: Theme.fontSerif
                font.pixelSize: 17
                font.weight: 600
                anchors.right: parent.right
                renderType: Text.NativeRendering
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
            InkText {
                role: "body"
                text: card.svc.condition
                color: Theme.accent
                anchors.right: parent.right
            }
        }

        // ---- three facts (mono, like the reference)
        Column {
            id: facts
            anchors.left: parent.left
            anchors.top: topLeft.bottom
            anchors.topMargin: Theme.space.sm
            spacing: 1
            Repeater {
                model: [
                    { k: "Precipitation", v: card.svc.precipProb + "%" },
                    { k: "Humidity", v: card.svc.humidity + "%" },
                    { k: "Wind", v: Math.round(card.svc.wind) + " km/h" }
                ]
                delegate: Row {
                    required property var modelData
                    spacing: 6
                    InkText { role: "mono"; text: modelData.k + ":"; font.pixelSize: 12; muted: true }
                    InkText { role: "mono"; text: modelData.v; font.pixelSize: 12 }
                }
            }
        }
        InkText {
            anchors.right: parent.right
            anchors.bottom: facts.bottom
            role: "small"
            muted: true
            text: isNaN(card.svc.apparent) ? "" : ("feels " + Math.round(card.svc.apparent) + "°")
        }

        // ---- 24-bar hourly strip
        Item {
            id: strip
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.topMargin: Theme.space.md
            height: 78
            readonly property var hours: card.svc.hours
            readonly property int n: 24
            readonly property real gap: 3
            readonly property real barW: (width - gap * (n - 1)) / n
            readonly property real lo: card.svc.minTemp
            readonly property real hi: Math.max(card.svc.maxTemp, lo + 1)
            property int hoverIndex: -1

            Rectangle {   // baseline hairline
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1; color: Theme.hairline
            }
            Repeater {
                model: strip.hours.length
                delegate: Rectangle {
                    required property int index
                    readonly property var h: strip.hours[index]
                    readonly property bool hot: strip.hoverIndex === index
                    x: index * (strip.barW + strip.gap)
                    width: strip.barW
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    height: 10 + (strip.height - 26) * ((h.temp - strip.lo) / (strip.hi - strip.lo))
                    radius: 2
                    color: hot ? Theme.seal : Theme.text
                    opacity: hot ? 1 : (h.hour === 0 ? 0.55 : 0.85)
                    Behavior on height { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: mouse => strip.hoverIndex = Math.max(0, Math.min(strip.hours.length - 1, Math.floor(mouse.x / (strip.barW + strip.gap))))
                onExited: strip.hoverIndex = -1
                acceptedButtons: Qt.NoButton
            }
            // hover readout (top-right of the strip; the default shows the span of the day)
            InkText {
                anchors.right: parent.right; anchors.top: parent.top
                role: "small"
                muted: strip.hoverIndex < 0
                color: strip.hoverIndex < 0 ? Theme.textMuted : Theme.seal
                text: strip.hoverIndex < 0 || !strip.hours[strip.hoverIndex]
                      ? ("next 24 h · " + Math.round(strip.lo) + "° – " + Math.round(strip.hi) + "°")
                      : (strip.hours[strip.hoverIndex].label + " · " + Math.round(strip.hours[strip.hoverIndex].temp) + "°"
                         + (strip.hours[strip.hoverIndex].prob > 0 ? " · " + strip.hours[strip.hoverIndex].prob + "% rain" : ""))
            }
            InkText {
                anchors.left: parent.left; anchors.top: parent.top
                role: "small"; muted: true
                text: strip.hours.length ? strip.hours[0].label : ""
            }
        }
    }

    // ---- error / loading state
    Column {
        anchors.centerIn: parent
        spacing: Theme.space.md
        visible: !card.hasData
        InkText {
            role: "body"
            text: card.svc.loading && !card.svc.error ? "Reading the sky…" : "Weather unavailable · 雲"
            font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
        }
        InkText {
            role: "small"; muted: true
            text: card.svc.error
            width: 380
            wrapMode: Text.Wrap
            maximumLineCount: 2
            visible: card.svc.error.length > 0
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
        InkButton {
            text: "Retry"
            icon: "󰑐"
            enabled: !card.svc.loading
            onClicked: card.svc.refresh()
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
