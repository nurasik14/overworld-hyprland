import QtQuick
import qs.Common

/*  McToast — one toast, drawn with the real toast/* frames. Stacking and queueing belong to the owner (Notifications).
 *    kind: "advancement"|"goal"|"challenge"|"recipe"|"tutorial"|"system"|"now_playing"
 *        advancement, goal, challenge: dark frame, yellow title (challenge: purple #FF88FF), default titles from the game
 *        recipe, tutorial: light frame, dark text; system: the blue frame with its "!"; now_playing: dark, rainbow title
 *    title, description: string   description wraps; the frame grows by whole lines
 *    icon: string          item name, or "" for no icon (system has none by default)
 *    iconSprite: string    GUI sprite instead of an item ("toast/tree")
 *    iconSource: url       explicit image (a notification's app icon)
 *    maxWidth: int         GUI px; the frame stays 160 unless the text needs more, then grows up to this. Default 240
 *    Animation:
 *      reveal()            slide in from the right (Theme.toastSlide, the game's squared easing), plays the toast sound
 *      dismiss()           slide out, then signal dismissed()
 *      autoHideMs: int     after reveal, dismiss on its own. Default Theme.toastHold; 0 stays until dismiss()
 *      shown: bool         set true at creation for a toast with no entrance (previews, history)
 *      silent: bool        no sounds
 *    signals dismissed(), clicked()
 *  The root keeps the toast's full size while the frame slides, so a Column of toasts does not jump.
 *
 *    McToast { id: t; kind: "challenge"; description: "Battery: 100 windows mined"; icon: "diamond_pickaxe"
 *              Component.onCompleted: reveal(); onDismissed: destroy() }
 */
Item {
    id: root
    property string kind: "advancement"
    property string title: ({ advancement: "Advancement Made!", goal: "Goal Reached!", challenge: "Challenge Complete!" })[kind] || ""
    property string description: ""
    property string icon: ""
    property string iconSprite: ""
    property url iconSource: ""
    property int maxWidth: 240
    property int autoHideMs: Theme.toastHold
    property bool shown: false
    property bool silent: false
    signal dismissed()
    signal clicked()

    readonly property bool isSystem: kind === "system"
    readonly property bool isLight: kind === "recipe" || kind === "tutorial"
    readonly property bool hasIcon: icon.length > 0 || iconSprite.length > 0 || iconSource.toString().length > 0
    readonly property string frameSprite: isSystem ? "toast/system" : isLight ? "toast/" + kind : kind === "now_playing" ? "toast/now_playing" : "toast/advancement"
    // Fixed frames have no mcmeta: cut them with their 4 px border so they can grow.
    readonly property var frameScaling: isSystem || kind === "now_playing" || kind === "tutorial" ? null
        : ({ type: "nine_slice", width: 160, height: 32, border: 4 })
    readonly property int textX: Theme.px(hasIcon ? 30 : (isSystem ? 18 : 10))
    readonly property int contentWidthMax: Theme.px(maxWidth) - textX - Theme.px(6)
    readonly property int bodyLines: desc.visible ? Math.max(1, Math.round(desc.implicitHeight / Theme.px(10))) : 0

    implicitWidth: Math.max(Theme.px(160), textX + Theme.px(6) + Math.min(contentWidthMax, Math.max(titleText.implicitWidth, measure.implicitWidth)))
    implicitHeight: Math.max(Theme.px(32), Theme.px(bodyLines > 0 ? 17 + bodyLines * 10 + 4 : 28))
    clip: false

    property real _slide: shown ? 0 : 1      // 1 = fully off to the right, 0 = in place

    NumberAnimation {
        id: slideIn
        target: root; property: "_slide"; to: 0
        duration: Theme.toastSlide
        easing.type: Theme.easeToast
    }
    SequentialAnimation {
        id: slideOut
        NumberAnimation { target: root; property: "_slide"; to: 1; duration: Theme.toastSlide; easing.type: Easing.OutQuad }
        ScriptAction { script: root.dismissed() }
    }
    Timer {
        id: hold
        interval: Math.max(1, root.autoHideMs)
        onTriggered: root.dismiss()
    }
    function reveal() {
        slideOut.stop();
        shown = true;
        slideIn.start();
        if (!silent) Theme.playSound(kind === "challenge" ? "ui.toast.challenge" : "ui.toast.in");
        if (autoHideMs > 0) hold.restart();
    }
    function dismiss() {
        if (slideOut.running) return;
        hold.stop();
        slideIn.stop();
        if (!silent) Theme.playSound("ui.toast.out");
        slideOut.start();
    }

    Text { id: measure; visible: false; text: root.description; font: desc.font }

    Item {
        id: frame
        width: root.width
        height: root.height
        x: Math.round(root._slide * root.width / Theme.gui) * Theme.gui

        McNineSlice {
            anchors.fill: parent
            sprite: root.frameSprite
            scaling: root.frameScaling
        }
        McItemIcon {
            visible: root.icon.length > 0 || root.iconSource.toString().length > 0
            x: Theme.px(8); y: Theme.px(8)
            name: root.icon
            source: root.iconSource
        }
        McSprite {
            visible: root.iconSprite.length > 0
            x: Theme.px(6); y: Theme.px(6)
            sprite: root.iconSprite
        }
        McText {
            id: titleText
            x: root.textX
            y: Theme.px(root.description.length ? 6 : 11)
            width: root.width - root.textX - Theme.px(6)
            text: root.title
            rainbow: root.kind === "now_playing"
            color: rainbow ? Qt.hsva(_rainbowHue, 0.7, 0.95, 1)
                 : root.isLight ? Theme.toastLightTitle
                 : root.kind === "challenge" ? Theme.toastChallenge : Theme.toastTitle
            shadow: !root.isLight
            elide: Text.ElideRight
        }
        McText {
            id: desc
            visible: root.description.length > 0
            x: root.textX
            y: Theme.px(17)
            width: root.width - root.textX - Theme.px(6)
            text: root.description
            color: root.isLight ? Theme.toastLightText : Theme.toastText
            shadow: !root.isLight
            wrapMode: Text.Wrap
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.clicked()
        }
    }
}
