import QtQuick
import qs.Common
import qs.Widgets
import qs.Widgets.Services

/*  BrewTimerCard — the brewing stand (190 × 84 GUI px): the focus timer from BrewTimer as the game's brewing GUI.
 *  Blaze powder is the fuel (its bar burns down with the phase), bubbles rise while a brew runs, the arrow fills as time
 *  passes (the real container/brewing_stand sprites), and the three bottle slots fill with potions as sessions complete
 *  (a stack count past three).  Brewing and resting both run it; the bar of the finished phase empties.
 *  Features kept from Apothecary: any lengths (25 · 50m · 1h30 · 90s · 1:30), rest 0 = none, pencil / click the clock →
 *  brew dialog, scroll on the clock = brew ±1 min and on the "brew · rest" line = rest ±1 min (Shift ±5) while idle,
 *  sessions count, sounds `brew.done` / `brew.drink`, events brew.start / brew.done / rest.done (BrewTimer).
 */
WidgetCard {
    id: card
    title: "Brewing Stand"
    guiW: 190
    guiH: 84

    readonly property var t: BrewTimer
    readonly property bool going: t.running
    readonly property real fuel: t.active ? Math.max(0, 1 - t.progress) : 1

    function wheelNudge(which, wheel) {
        if (card.t.active) return;
        const dir = wheel.angleDelta.y > 0 ? 1 : (wheel.angleDelta.y < 0 ? -1 : 0);
        if (dir) card.t.nudge(which, dir * ((wheel.modifiers & Qt.ShiftModifier) ? 300 : 60));
    }

    // bubbles: the game's heights {29, 24, 20, 16, 11, 6, 0}, one step every 2 ticks while brewing
    readonly property var bubbleHeights: [29, 24, 20, 16, 11, 6, 0]
    property int bubbleStep: 0
    McTicker { active: card.visible && card.going && !Theme.reducedMotion; onTicked: n => card.bubbleStep = Math.floor(n / 2) % 7 }
    readonly property int bubbleH: going ? (Theme.reducedMotion ? 20 : bubbleHeights[bubbleStep]) : 0

    // ---- fuel: blaze powder slot + burn bar
    McSlot { x: 0; y: 0; item: "blaze_powder"; tooltip: "Blaze Powder"; tooltipDescription: "Fuel. Burns down with the phase." }
    Item {
        x: 0; y: Theme.px(20); width: Theme.px(18); height: Theme.px(4)
        Rectangle { anchors.fill: parent; color: Theme.slotDark }
        Item {
            width: parent.width * card.fuel; height: parent.height; clip: true
            McSprite { sprite: "container/brewing_stand/fuel_length"; width: Theme.px(18); height: Theme.px(4) }
        }
    }

    // ---- the well: bubbles + arrow
    Rectangle {
        x: Theme.px(24); y: 0; width: Theme.px(40); height: Theme.px(34)
        color: Theme.slotDark
        Rectangle { width: parent.width; height: Theme.gui; y: parent.height - Theme.gui; color: Theme.slotLight }
        Item {   // bubbles, growing from the bottom
            x: Theme.px(5); y: Theme.px(3); width: Theme.px(12); height: Theme.px(29)
            Item {
                y: parent.height - Theme.px(card.bubbleH); width: parent.width; height: Theme.px(card.bubbleH); clip: true
                McSprite { y: -(Theme.px(29) - Theme.px(card.bubbleH)); width: Theme.px(12); height: Theme.px(29); sprite: "container/brewing_stand/bubbles" }
            }
        }
        Item {   // arrow, filling downwards as the phase progresses (a faint one underneath is the empty arrow of the GUI)
            x: Theme.px(24); y: Theme.px(3); width: Theme.px(9); height: Theme.px(28)
            McSprite { width: Theme.px(9); height: Theme.px(28); sprite: "container/brewing_stand/brew_progress"; opacity: 0.22 }
            Item {
                width: parent.width; height: Math.round(28 * (card.t.active ? card.t.progress : 0)) * Theme.gui; clip: true
                McSprite { width: Theme.px(9); height: Theme.px(28); sprite: "container/brewing_stand/brew_progress" }
            }
        }
    }

    // ---- clock + summary
    McText {
        id: clockText
        x: Theme.px(70); y: Theme.px(1)
        units: text.length > 5 ? 1 : 2
        text: card.t.mmss
        color: card.t.state === "idle" ? Theme.guiText : (card.t.phase === "breaking" ? Theme.chatReadable("3") : Theme.guiText)
        MouseArea {   // click: brew dialog · wheel (idle): brew length ±1 min, Shift ±5
            anchors.fill: parent
            anchors.margins: -Theme.px(2)
            cursorShape: Qt.PointingHandCursor
            onClicked: card.t.openDialog()
            onWheel: wheel => card.wheelNudge("work", wheel)
        }
    }
    McText {
        id: summary
        x: Theme.px(70); y: Theme.px(21); width: Theme.px(106)
        color: Theme.textMuted
        elide: Text.ElideRight
        text: card.t.state === "idle"
              ? card.t.short(card.t.workSeconds) + " brew · " + (card.t.breakSeconds > 0 ? card.t.short(card.t.breakSeconds) + " rest" : "no rest")
              : (card.t.label + (card.t.state === "paused" ? "" : " · " + Math.ceil(card.t.remaining / 60) + " min left"))
        MouseArea {   // wheel (idle): rest length ±1 min, Shift ±5 · click: brew dialog
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.t.openDialog()
            onWheel: wheel => card.wheelNudge("break", wheel)
        }
    }

    // ---- controls
    Row {
        x: 0; y: Theme.px(38)
        spacing: Theme.px(2)
        McButton {
            width: Theme.px(58); height: Theme.px(18)
            text: card.t.state === "idle" ? "Start" : card.t.state === "paused" ? "Resume" : "Pause"
            glyph: card.t.running ? "󰏤" : "󰐊"
            onClicked: card.t.toggle()
        }
        McButton { width: Theme.px(22); height: Theme.px(18); glyph: "󰜉"; tooltip: "Reset"; enabled: card.t.active; onClicked: card.t.reset() }
        McButton { width: Theme.px(22); height: Theme.px(18); glyph: "󰏫"; tooltip: "Set brew / rest time"; onClicked: card.t.openDialog() }
    }

    // ---- three bottle slots: potions for finished brews (a stack count past three)
    Row {
        x: Theme.px(176 - 54); y: Theme.px(38)
        spacing: 0
        Repeater {
            model: 3
            McSlot {
                required property int index
                readonly property bool full: card.t.sessions > index
                item: full ? "potion" : "glass_bottle"
                count: index === 2 && card.t.sessions > 3 ? card.t.sessions - 2 : 1
                glint: full && !Theme.reducedMotion
                tooltip: full ? "Brew complete" : "Empty bottle"
                tooltipDescription: card.t.sessions + (card.t.sessions === 1 ? " brew" : " brews") + " finished since startup"
            }
        }
    }
}
