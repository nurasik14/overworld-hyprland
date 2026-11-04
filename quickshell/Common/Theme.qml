pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/*  Theme — the Overworld design-token singleton (full reference: docs/DESIGN.md).
 *
 *  import qs.Common
 *
 *  Mode      Theme.mode "light"(Day) | "dark"(Night), isDark, setMode(m), toggleMode()   (watches ~/.config/overworld/mode)
 *  Colours   Theme.panel, slot, guiTitle, text, accent …  typed colours that cross-fade on mode change
 *            Theme.col("role"), Theme.c (raw object), Theme.ansi[0..15]
 *            Theme.chat["a"] literal §-colours, Theme.chatReadable("a") same colour made legible on every ground
 *  GUI scale Theme.gui (int, config gui_scale 1-4|"auto", default 2), Theme.px(n) = n * gui, Theme.fontPx(units), Theme.monoPx(units)
 *  Textures  Theme.tex("gui/sprites/hud/heart/full") -> file URL (assets/mc → assets/gen → missing texture)
 *            Theme.gs("hud/heart/full") same, rooted at gui/sprites
 *            Theme.spriteMeta(path) -> { scaling:{type,width,height,border{left,top,right,bottom},stretchInner}, animation }
 *            Theme.iconUrl("compass"), Theme.itemFor("kitty", windowTitle) -> item name from tokens/items.json
 *  Clock     Theme.tick (20 TPS counter), Theme.tickAcquire()/tickRelease(); prefer the McTicker helper, which ref-counts
 *  Sound     Theme.playSound("ui.click") runs scripts/ow-sound <id> detached (it honours config sounds, volumes, OW_SOUND_DRYRUN)
 *  Motion    Theme.ms(n) (0 when reducedMotion), ticksMs(n), reducedMotion, guiFade, toastSlide, toastHold, easeGui, easeToast, easeBlock
 *  Fonts     Theme.fontUi, fontMono, fontFor(role) -> { family, pixelSize, weight, italic, letterSpacing }
 *  Legacy    durFast/durBase/durSlow/durTheme, easeInk/easeBrush/easeDrift, radius/space/border/sizes/opacity,
 *            fontDisplay…, texture(name), sealImage(glyph) all keep working until phase 2 ports the modules.
 *
 *  Previews: OW_MODE=light|dark pins the mode and never writes the mode file; OW_GUI=1-4|auto pins the GUI scale; OW_REDUCED_MOTION=1 forces reduced motion;
 *            OW_NO_MOJANG=1 pretends assets/mc and assets/icons/mc are absent (tests the assets/gen fallback).
 */
Singleton {
    id: root

    // ------------------------------------------------------------ locations
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.config/overworld"
    readonly property string modePath: stateDir + "/mode"
    readonly property string configPath: stateDir + "/config.json"

    // Repo root candidates, tried in order until tokens.json loads:
    //   shellDir/..            config root is <repo>/quickshell (qs -c overworld with a real dir or a resolved symlink)
    //   shellDir/../../..      config root is <repo>/quickshell/Common/preview
    //   $OVERWORLD_DIR        explicit override
    //   ~/.config/overworld/repo   symlink that scripts/install.sh may create
    //   ~/Projects/overworld-hyprland   this machine's checkout
    readonly property var repoCandidates: [
        Quickshell.shellDir + "/..",
        Quickshell.shellDir + "/../../..",
        Quickshell.env("OVERWORLD_DIR") || "",
        stateDir + "/repo",
        home + "/Projects/overworld-hyprland"
    ].filter(p => p !== "")
    property int repoIndex: 0
    readonly property string repoDir: repoCandidates[Math.min(repoIndex, repoCandidates.length - 1)]
    readonly property string assetsDir: repoDir + "/assets"
    readonly property string commonDir: repoDir + "/quickshell/Common"
    property bool ready: false

    // ------------------------------------------------------------ tokens.json
    property var tokens: ({})
    FileView {
        id: tokensFile
        path: root.repoDir + "/tokens/tokens.json"
        blockLoading: true          // first read is synchronous: palette is right before the first frame
        watchChanges: true          // live-edit tokens.json while developing
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parseTokens(text())
    }
    function parseTokens(t) {
        if (!t || !t.length) return false;
        try {
            root.tokens = JSON.parse(t);
            root.ready = true;
            return true;
        } catch (e) {
            console.error("Theme: tokens.json parse error:", e);
            return false;
        }
    }
    Component.onCompleted: {
        // Resolve the repo synchronously by trying each candidate (blocking reads, ~µs each).
        for (let i = 0; i < repoCandidates.length; i++) {
            root.repoIndex = i;
            if (parseTokens(tokensFile.text())) break;
        }
        if (!root.ready) console.error("Theme: tokens.json not found; tried", JSON.stringify(repoCandidates));
        if (modeOverride.length) root.mode = modeOverride;
        else applyModeText(modeFile.text());
        parseConfig(configFile.text());
        parseItems(itemsFile.text());
    }

    // ------------------------------------------------------------ mode file
    readonly property string modeOverride: {
        const m = Quickshell.env("OW_MODE") || "";
        return m === "light" || m === "dark" ? m : "";
    }
    property string mode: "light"
    readonly property bool isDark: mode === "dark"
    FileView {
        id: modeFile
        path: root.modePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.applyModeText(text())
        onFileChanged: reload()
        onLoadFailed: error => { modePoll.running = true }   // file missing: poll until it appears
    }
    Timer {
        id: modePoll
        interval: 2000; repeat: true; running: false
        onTriggered: modeFile.reload()
    }
    function applyModeText(t) {
        if (modeOverride.length) { modePoll.running = false; return; }
        const m = (t || "").trim();
        if (m === "dark" || m === "light") {
            root.mode = m;
            modePoll.running = false;
        }
    }
    Process {
        id: modeWriter
        property string wanted: "light"
        command: ["sh", "-c",
            "m=\"$1\"; if command -v overworld >/dev/null 2>&1; then overworld \"$m\"; " +
            "else mkdir -p \"$HOME/.config/overworld\" && printf '%s' \"$m\" > \"$HOME/.config/overworld/mode\"; fi",
            "overworld-mode", wanted]
    }
    function setMode(m) {
        if (m !== "light" && m !== "dark") return;
        root.mode = m;                 // optimistic: cross-fade immediately
        if (modeOverride.length) return;
        modeWriter.wanted = m;
        modeWriter.running = true;
    }
    function toggleMode() { setMode(isDark ? "light" : "dark") }

    // ------------------------------------------------------------ sound (§4.5): one player for everything
    // Components call this rather than SoundService so Common keeps no dependency on Services and previews need no Services link.
    function playSound(id) {
        if (!id || (config.sounds === false && !Quickshell.env("OW_SOUND_DRYRUN"))) return;
        Quickshell.execDetached([repoDir + "/scripts/ow-sound", id]);
    }

    // ------------------------------------------------------------ config.json (only what the design system needs)
    property var config: ({})
    FileView {
        id: configFile
        path: root.configPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parseConfig(text())
        onFileChanged: reload()
    }
    function parseConfig(t) {
        try { root.config = JSON.parse(t || "{}") || {}; } catch (e) { root.config = {}; }
    }

    // ------------------------------------------------------------ GUI scale
    // "auto": floor(min(w/960, h/540)), clamped 1..4 → 1920×1080 = 2. The game's own Auto would be 4 here, too big for a shell.
    readonly property int gui: {
        const pinned = Quickshell.env("OW_GUI") || "";   // previews only
        const v = pinned === "auto" ? "auto" : pinned.length ? parseInt(pinned) : config.gui_scale;
        if (typeof v === "number" && v >= 1) return Math.min(4, Math.max(1, Math.round(v)));
        if (v === "auto") {
            const s = Quickshell.screens[0];
            if (s) return Math.min(4, Math.max(1, Math.floor(Math.min(s.width / 960, s.height / 540))));
        }
        return (shared.gui || {}).default_scale || 2;
    }
    function px(n) { return n * gui; }
    function fontPx(units) { return 8 * gui * (units === undefined ? 1 : units); }
    // Monocraft's grid is 9 px per em (upem 1080, one font pixel = 120 units), so it needs its own crisp size.
    function monoPx(units) { return 9 * gui * (units === undefined ? 1 : units); }

    // ------------------------------------------------------------ shared tokens
    readonly property var shared: tokens.shared || ({})
    readonly property var radius: shared.radius || ({ xs: 0, sm: 0, md: 0, lg: 0, pill: 0 })
    readonly property var space: shared.space || ({ xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, gutter: 16, margin: 24 })
    readonly property var border: shared.border || ({ hairline: 2, frame: 2, focus: 2 })
    readonly property var sizes: shared.sizes || ({})
    readonly property var type: shared.type || ({ families: {}, roles: {} })
    readonly property var motion: shared.motion || ({ tick_ms: 50, duration: { fast: 150, base: 250, slow: 500, theme_fade: 500, stagger: 40 }, ticks: {} })
    readonly property var opacity: shared.opacity || ({})
    readonly property var shadowSpec: shared.shadow || ({})

    // ------------------------------------------------------------ motion (§4.8)
    readonly property bool reducedMotion: Quickshell.env("OW_REDUCED_MOTION") === "1" || config.reduced_motion === true || config.animations === false
    function ms(n) { return reducedMotion ? 0 : n; }
    function ticksMs(n) { return reducedMotion ? 0 : n * 50; }
    readonly property var ticks: motion.ticks || ({})

    readonly property int durFast: ms(motion.duration ? motion.duration.fast : 150)
    readonly property int durBase: ms(motion.duration ? motion.duration.base : 250)
    readonly property int durSlow: ms(motion.duration ? motion.duration.slow : 500)
    readonly property int durTheme: reducedMotion ? 150 : (motion.duration ? motion.duration.theme_fade : 500)
    readonly property int stagger: ms(motion.duration ? motion.duration.stagger : 40)
    readonly property int guiFade: ms(motion.duration ? motion.duration.gui_fade : 150)
    readonly property int toastSlide: ms(motion.duration ? motion.duration.toast_slide : 500)
    readonly property int toastHold: motion.duration ? motion.duration.toast_hold : 5000
    // QML easing equivalents of the Hyprland beziers (see tokens.shared.motion.easing)
    readonly property int easeInk: Easing.OutQuint
    readonly property int easeBrush: Easing.InOutCubic
    readonly property int easeDrift: Easing.OutCubic
    readonly property int easeGui: Easing.OutQuad
    readonly property int easeToast: Easing.InQuad      // the game squares its toast progress
    readonly property int easeBlock: Easing.OutBack

    // ------------------------------------------------------------ tick clock: 20 TPS, sleeps while nobody holds a reference
    property int tick: 0
    property int _tickUsers: 0
    function tickAcquire() { _tickUsers++; }
    function tickRelease() { _tickUsers = Math.max(0, _tickUsers - 1); }
    Timer {
        interval: 50; repeat: true; running: root._tickUsers > 0
        onTriggered: root.tick++
    }

    // ------------------------------------------------------------ fonts: first family present in Qt.fontFamilies()
    readonly property var families: type.families || ({})
    readonly property var _installedFonts: Qt.fontFamilies()
    function _firstFont(candidates) {
        for (let i = 0; i < candidates.length; i++)
            if (candidates[i] && _installedFonts.indexOf(candidates[i]) >= 0) return candidates[i];
        return candidates[candidates.length - 1];
    }
    readonly property string fontUi: _firstFont([families.ui, families.ui_fallback, "Monocraft"])
    readonly property string fontMono: _firstFont([families.mono, "Monocraft"])
    // legacy family names: all Minecraft now
    readonly property string fontDisplay: fontUi
    readonly property string fontTitle: fontUi
    readonly property string fontBody: fontUi
    readonly property string fontSerif: fontUi
    readonly property string fontSerifBody: fontUi
    readonly property string fontJp: fontUi

    function fontFor(role) {
        const r = (type.roles || {})[role] || { units: 1, weight: 400 };
        const isMono = r.family === families.mono;
        return {
            family: isMono ? fontMono : fontUi,
            pixelSize: isMono ? monoPx(r.units || 1) : fontPx(r.units || 1),
            weight: r.weight || 400,
            italic: !!r.italic,
            letterSpacing: r.letter_spacing || 0
        };
    }
    function brushFamilyFor(text) { return fontUi; }

    // ------------------------------------------------------------ colours
    readonly property var modes: tokens.modes || ({})
    readonly property var c: modes[mode] || modes.light || ({})
    // tokens.json uses CSS-style #rrggbbaa; Qt parses 8-digit strings as #aarrggbb, so swap when needed.
    function qtColor(v) {
        if (typeof v === "string" && v.length === 9 && v[0] === "#") return "#" + v.substr(7, 2) + v.substr(1, 6);
        return v;
    }
    function col(role, fallback) { const v = c[role]; return qtColor(v !== undefined ? v : (fallback || "#ff00ff")); }
    // a role from a specific mode, for fixed-skin surfaces (McPanel skin: "day"|"night")
    function colOf(modeName, role, fallback) {
        const m = modes[modeName] || {};
        return qtColor(m[role] !== undefined ? m[role] : (fallback || "#ff00ff"));
    }
    function withAlpha(colour, a) { const q = Qt.color(colour); return Qt.rgba(q.r, q.g, q.b, a); }
    // the game's text shadow: RGB × 0.25, same alpha
    function shadowOf(colour) { const q = Qt.color(colour); return Qt.rgba(q.r * 0.25, q.g * 0.25, q.b * 0.25, q.a); }

    // §-colours, literal (use on dark grounds: tooltips, chat, HUD, screens).
    readonly property var chat: ({
        "0": "#000000", "1": "#0000AA", "2": "#00AA00", "3": "#00AAAA", "4": "#AA0000", "5": "#AA00AA", "6": "#FFAA00", "7": "#AAAAAA",
        "8": "#555555", "9": "#5555FF", "a": "#55FF55", "b": "#55FFFF", "c": "#FF5555", "d": "#FF55FF", "e": "#FFFF55", "f": "#FFFFFF"
    })
    // §-code → ANSI slot: the ANSI palette passes WCAG 4.5 on every ground in both modes.
    readonly property var _chatAnsi: ({ "0": 0, "1": 4, "2": 2, "3": 6, "4": 1, "5": 5, "6": 3, "7": 7, "8": 8, "9": 12, "a": 10, "b": 14, "c": 9, "d": 13, "e": 11, "f": 15 })
    function chatReadable(code) {
        if (code === "0" && isDark) return ansi[7] || "#CFCFCF";
        const i = _chatAnsi[code];
        return i === undefined ? text : (ansi[i] || chat[code]);
    }

    property color bg0:           col("bg0", "#c6c6c6")
    property color bg1:           col("bg1", "#cecece")
    property color bg2:           col("bg2", "#d6d6d6")
    property color surface:       col("surface", "#c6c6c6")
    property color surfaceAlt:    col("surfaceAlt", "#bdbdbd")
    property color frame:         col("frame", "#373737")
    property color hairline:      col("hairline", "#8b8b8b")
    property color titlebar:      col("titlebar", "#373737")
    property color titlebarText:  col("titlebarText", "#ffffff")
    property color text:          col("text", "#373737")
    property color textMuted:     col("textMuted", "#4a4a4a")
    property color textOnAccent:  col("textOnAccent", "#ffffff")
    property color textOnSeal:    col("textOnSeal", "#ffffff")
    property color accent:        col("accent", "#245018")
    property color accentSoft:    col("accentSoft", "#7cbd6b")
    property color accent2:       col("accent2", "#5e3f1c")
    property color gold:          col("gold", "#ffaa00")
    property color seal:          col("seal", "#8f1313")
    property color success:       col("success", "#175112")
    property color herb:          col("herb", "#5d8c3e")
    property color warning:       col("warning", "#654400")
    property color error:         col("error", "#8f1313")
    property color info:          col("info", "#17358c")
    property color plum:          col("plum", "#6c1a9c")
    property color jade:          col("jade", "#024c50")
    property color indigo:        col("indigo", "#26308f")
    property color wood:          col("wood", "#a2824e")
    property color woodDark:      col("woodDark", "#5c4426")
    property color shadow:        col("shadow", "#00000040")
    property color shadowStrong:  col("shadowStrong", "#00000066")
    property color overlay:       col("overlay", "#00000059")
    property color inkWash:       col("inkWash", "#ffffff40")
    property color inkWashStrong: col("inkWashStrong", "#ffffff80")
    property color sealWash:      col("sealWash", "#aa00001f")
    property color selection:     col("selection", "#24501840")
    property color cursor:        col("cursor", "#373737")
    property color link:          col("link", "#17358c")
    property color focusRing:     col("focusRing", "#ffffff")
    // GUI roles (mode dependent, cross-fading)
    property color panel:         col("panel", "#c6c6c6")
    property color panelLight:    col("panelLight", "#ffffff")
    property color panelShadow:   col("panelShadow", "#555555")
    property color panelOutline:  col("panelOutline", "#000000")
    property color slot:          col("slot", "#8b8b8b")
    property color slotDark:      col("slotDark", "#373737")
    property color slotLight:     col("slotLight", "#ffffff")
    property color guiTitle:      col("guiTitle", "#404040")
    property color guiText:       col("guiText", "#404040")
    // GUI roles fixed in both modes
    readonly property color guiTextShadow:      col("guiTextShadow", "#3f3f3f")
    readonly property color slotHover:          col("slotHover", "#ffffff80")
    readonly property color buttonText:         col("buttonText", "#ffffff")
    readonly property color buttonTextDisabled: col("buttonTextDisabled", "#a0a0a0")
    readonly property color fieldText:          col("fieldText", "#e0e0e0")
    readonly property color fieldTextDisabled:  col("fieldTextDisabled", "#707070")
    readonly property color fieldPlaceholder:   col("fieldPlaceholder", "#707070")
    readonly property color fieldSelection:     col("fieldSelection", "#0000ff")
    readonly property color tooltipFill:        col("tooltipFill", "#100010f0")
    readonly property color tooltipBorderTop:   col("tooltipBorderTop", "#5000ff50")
    readonly property color tooltipBorderBottom: col("tooltipBorderBottom", "#28007f50")
    readonly property color tooltipTitle:       col("tooltipTitle", "#ffffff")
    readonly property color tooltipDesc:        col("tooltipDesc", "#aaaaaa")
    readonly property color tooltipCategory:    col("tooltipCategory", "#5555ff")
    readonly property color toastTitle:         col("toastTitle", "#ffff00")
    readonly property color toastChallenge:     col("toastChallenge", "#ff88ff")
    readonly property color toastText:          col("toastText", "#ffffff")
    readonly property color toastLightTitle:    col("toastLightTitle", "#500050")
    readonly property color toastLightText:     col("toastLightText", "#000000")
    readonly property color menuGradientTop:    col("menuGradientTop", "#101010c0")
    readonly property color menuGradientBottom: col("menuGradientBottom", "#101010d0")
    readonly property color hudText:            col("hudText", "#ffffff")
    readonly property color xp:                 col("xp", "#80ff20")
    readonly property color enchant:            col("enchant", "#8040cc")
    readonly property color enchantGlint:       col("enchantGlint", "#a970ff")
    readonly property color splash:             col("splash", "#ffff00")
    readonly property color grass:              col("grass", "#7cbd6b")
    readonly property color sky:                col("sky", "#78a7ff")
    readonly property color water:              col("water", "#3f76e4")
    readonly property color lava:               col("lava", "#e8721c")
    readonly property color nether:             col("nether", "#7b1e1e")
    readonly property color netherPortal:       col("netherPortal", "#6a1fbf")
    readonly property color endStone:           col("end", "#dbde9e")
    readonly property color diamond:            col("diamond", "#4aedd9")
    readonly property color emerald:            col("emerald", "#17dd62")
    readonly property color redstone:           col("redstone", "#ff0000")
    readonly property color lapis:              col("lapis", "#1d47a8")
    readonly property var ansi:   c.ansi || []
    readonly property var ink:    c.ink || []
    readonly property var paper:  c.paper || []

    // Every mode-dependent typed colour cross-fades on mode change
    Behavior on bg0 { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on bg1 { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on bg2 { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on surface { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on surfaceAlt { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on frame { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on hairline { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on titlebar { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on titlebarText { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on text { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on textMuted { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on textOnAccent { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on textOnSeal { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on accentSoft { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on accent2 { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on gold { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on seal { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on success { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on herb { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on warning { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on error { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on info { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on plum { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on jade { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on indigo { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on wood { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on woodDark { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on shadow { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on shadowStrong { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on overlay { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on inkWash { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on inkWashStrong { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on sealWash { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on selection { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on cursor { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on link { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on focusRing { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on panel { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on panelLight { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on panelShadow { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on panelOutline { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on slot { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on slotDark { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on slotLight { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on guiTitle { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }
    Behavior on guiText { ColorAnimation { duration: root.durTheme; easing.type: Easing.OutCubic } }

    // ------------------------------------------------------------ textures (§4.3)
    // One blocking reader shared by every lookup; every result is cached, so each path is read at most once.
    FileView {
        id: probe
        blockLoading: true
        printErrors: false
    }
    // FileView.text() reads a notifying property, so calling it from a binding would capture it and loop on the next read.
    // A signal handler runs outside the caller's property capture, and the result travels in a box that never notifies.
    signal _readRequested(string path)
    readonly property var _readBox: ({ text: "" })
    on_ReadRequested: path => {
        probe.path = "";               // a failed load keeps the previous file's text: clear it first
        probe.path = path;
        _readBox.text = probe.text() || "";
    }
    function _read(path) {
        root._readRequested(path);
        return _readBox.text;
    }
    readonly property string mcTexDir: assetsDir + "/mc/textures"
    readonly property string genTexDir: assetsDir + "/gen/textures"
    readonly property string missingTexture: "file://" + commonDir + "/assets/missing.png"
    // Mojang assets are detected once, through a marker sprite.
    readonly property bool _noMojang: Quickshell.env("OW_NO_MOJANG") === "1"
    readonly property bool hasMojangAssets: ready && !_noMojang && _read(mcTexDir + "/gui/sprites/widget/button.png").length > 0

    property var _texCache: ({})      // texture path → absolute file path, "" when missing
    function _texFile(path) {
        const hit = _texCache[path];
        if (hit !== undefined) return hit;
        let file = "";
        const mc = mcTexDir + "/" + path + ".png";
        const gen = genTexDir + "/" + path + ".png";
        if (hasMojangAssets && _read(mc).length > 0) file = mc;
        else if (_read(gen).length > 0) file = gen;
        _texCache[path] = file;
        return file;
    }
    // tex("gui/sprites/hud/heart/full") → file URL: Mojang asset, else asset-forge's original, else the missing texture
    function tex(path) {
        if (!ready) return missingTexture;
        const f = _texFile(path);
        return f.length ? "file://" + f : missingTexture;
    }
    readonly property var _textureRoots: ["gui/", "block/", "item/", "misc/", "environment/", "particle/", "entity/", "font/", "mob_effect/", "painting/", "map/", "colormap/", "trims/", "models/", "effect/", "gen/"]
    // Component `sprite:` paths are rooted at gui/sprites unless they start with a texture folder.
    function spritePath(p) {
        for (let i = 0; i < _textureRoots.length; i++)
            if (p.indexOf(_textureRoots[i]) === 0) return p;
        return "gui/sprites/" + p;
    }
    function gs(p) { return tex("gui/sprites/" + p); }

    // Used when a sprite has no readable .mcmeta (asset-forge's originals may ship without one).
    readonly property var _builtinScaling: ({
        "gui/sprites/widget/button": { type: "nine_slice", width: 200, height: 20, border: 3 },
        "gui/sprites/widget/button_highlighted": { type: "nine_slice", width: 200, height: 20, border: 3 },
        "gui/sprites/widget/button_disabled": { type: "nine_slice", width: 200, height: 20, border: 1 },
        "gui/sprites/widget/slider": { type: "nine_slice", width: 200, height: 20, border: 1 },
        "gui/sprites/widget/slider_highlighted": { type: "nine_slice", width: 200, height: 20, border: 1 },
        "gui/sprites/widget/slider_handle": { type: "nine_slice", width: 8, height: 20, border: { left: 2, top: 2, right: 2, bottom: 3 } },
        "gui/sprites/widget/slider_handle_highlighted": { type: "nine_slice", width: 8, height: 20, border: { left: 2, top: 2, right: 2, bottom: 3 } },
        "gui/sprites/widget/text_field": { type: "nine_slice", width: 200, height: 20, border: 1 },
        "gui/sprites/widget/text_field_highlighted": { type: "nine_slice", width: 200, height: 20, border: 1 },
        "gui/sprites/widget/scroller": { type: "nine_slice", width: 6, height: 32, border: 1 },
        "gui/sprites/widget/scroller_background": { type: "nine_slice", width: 6, height: 32, border: 1 },
        "gui/sprites/tooltip/background": { type: "nine_slice", width: 100, height: 100, border: 9 },
        "gui/sprites/tooltip/frame": { type: "nine_slice", width: 100, height: 100, border: 10, stretch_inner: true },
        "gui/sprites/toast/system": { type: "nine_slice", width: 160, height: 64, border: { left: 17, top: 30, right: 4, bottom: 4 } },
        "gui/sprites/toast/now_playing": { type: "nine_slice", width: 160, height: 32, border: 4 },
        "gui/sprites/toast/tutorial": { type: "nine_slice", width: 160, height: 32, border: 3 }
    })
    function _normScaling(s) {
        if (!s || !s.type) return { type: "stretch", width: 0, height: 0, border: { left: 0, top: 0, right: 0, bottom: 0 }, stretchInner: false };
        const b = s.border;
        const border = typeof b === "number" ? { left: b, top: b, right: b, bottom: b }
                     : b ? { left: b.left || 0, top: b.top || 0, right: b.right || 0, bottom: b.bottom || 0 }
                         : { left: 0, top: 0, right: 0, bottom: 0 };
        return { type: s.type, width: s.width || 0, height: s.height || 0, border: border, stretchInner: !!s.stretch_inner };
    }
    property var _metaCache: ({})
    // spriteMeta("widget/button" | "block/water_still") → { scaling, animation|null }
    function spriteMeta(path) {
        const full = spritePath(path);
        const hit = _metaCache[full];
        if (hit !== undefined) return hit;
        if (!ready) return { scaling: _normScaling(_builtinScaling[full]), animation: null };
        let parsed = {};
        const file = _texFile(full);
        if (file.length) {
            const t = _read(file + ".mcmeta");
            if (t.length) { try { parsed = JSON.parse(t) || {}; } catch (e) { parsed = {}; } }
        }
        const scaling = parsed.gui && parsed.gui.scaling ? parsed.gui.scaling : _builtinScaling[full];
        const meta = { scaling: _normScaling(scaling), animation: parsed.animation || null };
        _metaCache[full] = meta;
        return meta;
    }

    // ------------------------------------------------------------ items (§4.3): app class → item name → icon
    property var items: ({})
    FileView {
        id: itemsFile
        path: root.repoDir + "/tokens/items.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parseItems(text())
        onFileChanged: reload()
    }
    function parseItems(t) {
        try { root.items = JSON.parse(t || "{}") || {}; } catch (e) { root.items = {}; }
    }
    // items.json is written for Python regexes: its rules carry a leading (?i), which JS expresses as a flag.
    function _ruleRegex(src) { return new RegExp(src.replace(/^\(\?i\)/, ""), "i"); }
    readonly property var _titleRules: (items._title_rules || []).map(r => ({ cls: _ruleRegex(r.class), title: _ruleRegex(r.title), item: r.item }))
    // itemFor("kitty", "nvim notes.txt") → "writable_book": title rules first, then the class key, then _default
    function itemFor(appClass, title) {
        const k = (appClass || "").toLowerCase();
        if (title) {
            for (let i = 0; i < _titleRules.length; i++) {
                const r = _titleRules[i];
                if (r.cls.test(k) && r.title.test(title)) return r.item;
            }
        }
        return items[k] || items[appClass] || items._default || "stone";
    }
    property var _iconCache: ({})
    // iconUrl("compass") → assets/icons/mc → assets/gen/icons → item/<name> → block/<name> → missing texture
    function iconUrl(name) {
        if (!name || !ready) return missingTexture;
        const hit = _iconCache[name];
        if (hit !== undefined) return hit;
        const candidates = (_noMojang ? [] : [assetsDir + "/icons/mc/" + name + ".png"]).concat([assetsDir + "/gen/icons/" + name + ".png"]);
        let url = "";
        for (let i = 0; i < candidates.length && !url.length; i++)
            if (_read(candidates[i]).length > 0) url = "file://" + candidates[i];
        if (!url.length && _texFile("item/" + name).length) url = tex("item/" + name);
        if (!url.length && _texFile("block/" + name).length) url = tex("block/" + name);
        if (!url.length) url = missingTexture;
        _iconCache[name] = url;
        return url;
    }

    // ------------------------------------------------------------ legacy texture API (paper/lacquer grain is gone: textureOpacity is 0)
    readonly property real textureOpacity: (opacity.texture_overlay || {})[mode] !== undefined ? opacity.texture_overlay[mode] : 0
    readonly property real surfaceOpacity: opacity.surface !== undefined ? opacity.surface : 1.0
    readonly property real cardTransparentOpacity: opacity.card_transparent !== undefined ? opacity.card_transparent : 0.72
    readonly property real widgetOpacity: config.widgets && config.widgets.opacity !== undefined ? config.widgets.opacity : (opacity.widget_default !== undefined ? opacity.widget_default : 0.72)
    function texture(name) {
        const alias = {
            "enso": "item/music_disc_13", "enso-ink": "item/music_disc_13", "enso-light": "item/music_disc_13",
            "divider": "gui/header_separator", "ink-divider": "gui/header_separator", "ink-divider-light": "gui/header_separator"
        };
        return tex(alias[name] || "gui/menu_background");
    }
    function sealImage(glyph) { return tex("item/redstone"); }
}
