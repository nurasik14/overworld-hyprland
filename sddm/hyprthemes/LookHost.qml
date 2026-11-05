// Hosts one look. SDDM gives every theme a single `config` object in the engine's root context, filled from the wrapper's theme.conf,
// and QML looks a name up through the item it is used in, then its ancestors, then that root context. So the two properties below
// shadow names for everything the look's Main.qml and its components evaluate, and the look needs no change for them:
//   config                   the keys of [look.<id>] in theme.conf, with SDDM's stringValue/intValue/realValue/boolValue API
//   hyprthemesSessionIndex   the session this look starts on (the installer replaces `sessionModel.lastIndex` by this name)
// Singletons do not get this: they only see the root context. Silent's Config singleton therefore reads the real `config`,
// and the installer keeps Silent's sections at the top level of theme.conf and everything else under [look.*] and [HyprThemes].
import QtQuick

FocusScope {
    id: host

    property var lookInfo
    property var realConfig
    property int hyprthemesSessionIndex: 0

    signal loaded()
    signal failed()

    function start() { loader.source = lookInfo.dir + "/Main.qml"; }

    property QtObject config: QtObject {
        function rawValue(key) {
            const section = host.lookInfo.configSection;
            return host.realConfig[(section ? section + "/" : "") + key];
        }
        function stringValue(key) { const v = rawValue(key); return (v === undefined || v === null) ? "" : String(v); }
        function intValue(key) { return parseInt(stringValue(key)) || 0; }
        function realValue(key) { return parseFloat(stringValue(key)) || 0; }
        function boolValue(key) { return stringValue(key).toLowerCase() === "true"; }
    }

    Loader {
        id: loader
        anchors.fill: parent
        focus: true
        onStatusChanged: {
            if (status === Loader.Ready) host.loaded();
            else if (status === Loader.Error) host.failed();
        }
    }
}
