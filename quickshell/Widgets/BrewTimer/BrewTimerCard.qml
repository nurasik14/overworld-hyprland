import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  BrewTimerCard — 煎 · BREW (300 × 160): "Brewing medicine" focus timer.
 *  Ink progress ring around mm:ss, label 煎药 · BREWING, Start / Pause / Reset / Set.  Logic in BrewTimer.
 *  Setting the lengths: click the clock or Set → brew dialog (any duration); while idle, scroll on the clock = brew
 *  ±1 min and on the "brew · rest" line = rest ±1 min (Shift: ±5 min), saved to config.json after a short pause.
 */
WidgetCard {
    id: card
    title: "煎"
    subtitle: "Brew"
    sealGlyph: "药"
    width: 300
    height: 160
    padding: 12

    readonly property var t: BrewTimer
    readonly property int ringSize: 88
    readonly property color ringColor: t.phase === "breaking" ? Theme.accent : Theme.seal

    // ---- ring
    Item {
        id: ring
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        width: card.ringSize; height: card.ringSize
        Shape {
            anchors.fill: parent
            antialiasing: true
            layer.enabled: true; layer.samples: 4
            ShapePath {   // track
                strokeColor: Theme.hairline; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.width / 2 - 4; radiusY: ring.height / 2 - 4; startAngle: -90; sweepAngle: 360 }
            }
            ShapePath {   // ink progress
                strokeColor: card.ringColor; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.width / 2 - 4; radiusY: ring.height / 2 - 4
                    startAngle: -90
                    sweepAngle: card.t.active ? Math.max(0.01, 360 * card.t.progress) : 0
                    Behavior on sweepAngle { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: card.t.mmss
            color: Theme.text
            font.family: Theme.fontSerif
            font.pixelSize: text.length > 5 ? 18 : 24       // h:mm:ss for brews of an hour or more
            font.weight: 600
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: Theme.durTheme } }
        }
        MouseArea {   // click: brew dialog · wheel (idle): brew length ±1 min, Shift ±5
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.t.openDialog()
            onWheel: wheel => card.wheelNudge("work", wheel)
        }
    }

    function wheelNudge(which, wheel) {
        if (card.t.active) return;
        const dir = wheel.angleDelta.y > 0 ? 1 : (wheel.angleDelta.y < 0 ? -1 : 0);
        if (dir) card.t.nudge(which, dir * ((wheel.modifiers & Qt.ShiftModifier) ? 300 : 60));
    }

    // ---- label + controls
    Column {
        anchors.left: ring.right; anchors.leftMargin: Theme.space.lg
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Row {
            spacing: Theme.space.sm
            Text {
                text: "煎药"
                color: Theme.text
                font.family: Theme.fontDisplay
                font.pixelSize: 26
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.durTheme } }
            }
            InkText {
                role: "subtitle"
                text: card.t.phase === "breaking" ? "RESTING" : "BREWING"
                font.capitalization: Font.AllUppercase
                muted: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        InkText {
            width: parent.width
            role: "small"; muted: true
            text: card.t.state === "idle"
                  ? (card.t.short(card.t.workSeconds) + " brew · " + (card.t.breakSeconds > 0 ? card.t.short(card.t.breakSeconds) + " rest" : "no rest")
                     + (card.t.sessions ? " · " + card.t.sessions + " brewed" : ""))
                  : (card.t.label + (card.t.state === "paused" ? "" : " · " + Math.ceil(card.t.remaining / 60) + " min left"))
            MouseArea {   // wheel (idle): rest length ±1 min, Shift ±5 · click: brew dialog
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.t.openDialog()
                onWheel: wheel => card.wheelNudge("break", wheel)
            }
        }
        Row {
            spacing: Theme.space.sm
            InkButton {
                text: card.t.state === "idle" ? "Start" : card.t.state === "paused" ? "Resume" : "Pause"
                icon: card.t.running ? "󰏤" : "󰐊"
                primary: card.t.state === "idle"
                implicitHeight: 28
                onClicked: card.t.toggle()
            }
            InkButton { icon: "󰜉"; quiet: true; implicitHeight: 28; horizontalPadding: 7; tooltip: "Reset"; enabled: card.t.active; onClicked: card.t.reset() }
            InkButton { icon: "󰏫"; quiet: true; implicitHeight: 28; horizontalPadding: 7; tooltip: "Set brew / rest time"; onClicked: card.t.openDialog() }
        }
    }
}
