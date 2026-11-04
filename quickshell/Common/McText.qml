import QtQuick
import qs.Common

/*  McText — Minecraft text. It IS a Text (anchors, width, elide, wrapMode, font.*, contentWidth… all work) with:
 *    hard drop shadow    offset 1 GUI px, colour = text colour × 0.25, like the game
 *    shadow: bool        default: only for light text (dark #404040 panel titles have none in the game)
 *    shadowColor: color  default: Theme.shadowOf(color); set Theme.guiTextShadow (#3F3F3F) for HUD white
 *    units: int          size in multiples of the 8 px font unit × GUI scale; default 1. Keep it whole or the bitmap font blurs
 *    mono: bool          Monocraft instead of Mojangles (F3, sysinfo, Nerd glyphs)
 *    guiTitle: bool      GUI title style: Theme.guiTitle (#404040 Day, white with shadow Night)
 *    codes: string       text with §-codes: §0-§f colours, §l bold, §o italic, §n underline, §m strike, §r reset
 *    darkGround: bool    §-colours are literal; false (default on Day) swaps them for Theme.chatReadable so they pass contrast
 *    rainbow: bool       cycles the whole string's hue on the tick clock, like the game's "Now Playing" line
 *
 *    McText { text: "Inventory"; guiTitle: true }
 *    McText { codes: "§aHP §c7.5§r / 10"; darkGround: true }
 *    McText { text: "Now Playing: Sweden"; rainbow: true }
 */
Text {
    id: root
    property int units: 1
    property bool mono: false
    property bool guiTitle: false
    property string codes: ""
    property bool darkGround: Theme.isDark
    property bool rainbow: false
    readonly property int shadowOffset: Theme.gui * units
    readonly property real _lum: { const q = Qt.color(color); return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b; }
    property bool shadow: _lum > 0.4
    property color shadowColor: Theme.shadowOf(color)
    readonly property real _rainbowHue: rainbowClock.tick / 50.0 % 1.0

    McTicker { id: rainbowClock; active: root.rainbow && root.visible && !Theme.reducedMotion }

    color: rainbow ? Qt.hsva(_rainbowHue, 0.7, 0.95, 1) : (guiTitle ? Theme.guiTitle : Theme.guiText)
    font.family: mono ? Theme.fontMono : Theme.fontUi
    font.pixelSize: mono ? Theme.monoPx(units) : Theme.fontPx(units)
    // Monocraft's line box is 1.49 em; the game's line pitch is 10 GUI px per unit.
    lineHeightMode: mono ? Text.FixedHeight : Text.ProportionalHeight
    lineHeight: mono ? Theme.px(10) * units : 1
    font.hintingPreference: Font.PreferNoHinting
    renderType: Text.NativeRendering
    antialiasing: false
    textFormat: codes.length ? Text.StyledText : Text.PlainText
    text: codes.length ? _render(codes, false) : ""

    // §-string → StyledText. forShadow renders every colour × 0.25, keeping the layout identical.
    function _esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\n/g, "<br>"); }
    function _render(src, forShadow) {
        let out = "", cur = "", colour = null, bold = false, italic = false, under = false, strike = false;
        const flush = () => {
            if (!cur.length) return;
            let s = _esc(cur);
            if (bold) s = "<b>" + s + "</b>";
            if (italic) s = "<i>" + s + "</i>";
            if (under) s = "<u>" + s + "</u>";
            if (strike) s = "<s>" + s + "</s>";
            if (colour !== null) {
                const c = forShadow ? Theme.shadowOf(colour) : Qt.color(colour);
                s = '<font color="' + c.toString() + '">' + s + "</font>";
            }
            out += s;
            cur = "";
        };
        for (let i = 0; i < src.length; i++) {
            if (src[i] === "§" && i + 1 < src.length) {
                const code = src[++i].toLowerCase();
                flush();
                if (Theme.chat[code] !== undefined) {
                    colour = root.darkGround ? Theme.chat[code] : Theme.chatReadable(code);
                    bold = italic = under = strike = false;
                } else if (code === "l") bold = true;
                else if (code === "o") italic = true;
                else if (code === "n") under = true;
                else if (code === "m") strike = true;
                else if (code === "r") { colour = null; bold = italic = under = strike = false; }
            } else cur += src[i];
        }
        flush();
        return out;
    }

    Text {
        id: shadowLayer
        z: -1
        x: root.shadowOffset
        y: root.shadowOffset
        visible: root.shadow && root.text.length > 0
        width: root.width
        height: root.height
        text: root.codes.length ? root._render(root.codes, true) : root.text
        textFormat: root.textFormat
        color: root.shadowColor
        font: root.font
        renderType: root.renderType
        antialiasing: false
        wrapMode: root.wrapMode
        elide: root.elide
        maximumLineCount: root.maximumLineCount
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        lineHeight: root.lineHeight
        lineHeightMode: root.lineHeightMode
    }
}
