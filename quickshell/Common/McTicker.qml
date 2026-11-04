import QtQuick
import qs.Common

/*  McTicker — a reference on the global 20 TPS clock. Holding one keeps Theme.tick running; dropping the last one
 *  stops the timer, so an idle shell does not wake 20 times a second.
 *    active: bool     hold the clock only while true (bind to `visible`, a running state…)
 *    tick: int        Theme.tick while active, frozen otherwise
 *    ticked(int)      fires once per tick while active
 *
 *    McTicker { id: t; active: root.visible; onTicked: n => frame = n % 32 }
 */
QtObject {
    id: root
    property bool active: true
    property bool _held: false
    property int _frozen: 0
    readonly property int tick: active ? Theme.tick : _frozen
    signal ticked(int tick)

    function _sync() {
        if (active && !_held) { Theme.tickAcquire(); _held = true; }
        else if (!active && _held) { Theme.tickRelease(); _held = false; _frozen = Theme.tick; }
    }
    onActiveChanged: _sync()
    onTickChanged: if (active) ticked(tick)
    Component.onCompleted: _sync()
    Component.onDestruction: if (_held) { Theme.tickRelease(); _held = false; }
}
