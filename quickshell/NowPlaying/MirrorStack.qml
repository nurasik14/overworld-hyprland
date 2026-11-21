import QtQuick
import QtMultimedia
import "sync.js" as Sync

/*  MirrorStack — the silent mirror for a whole file OR a long video in parts: two VideoMirror players stacked on each other.
 *    parts: var          [{start, dur, file}] on the video's timeline (the daemon's ready parts, sorted); a whole file is
 *                        [{start: 0, dur: 0, file}] (dur 0 = to the file's end), [] = nothing
 *    clock: var          the browser's clock (NowPlayingService.clock), as for VideoMirror
 *    active: bool        false = both players stop and release their files
 *    readonly ready      the front player shows the browser's position (fade it in over the thumbnail; else the cover shows)
 *  The FRONT player shows the part that covers the position (sync.pickPart); the BACK one preloads the part after it
 *  (sync.nextPart), paused on its first frame until the browser reaches that part's start, then running in sync with its own
 *  clock (sync.partClock). SWAP s before the front part ends, the back one is raised on top (it has been in sync for the
 *  overlap's length) and the old front stays visible underneath for a moment, so there is no flash. A jump outside the
 *  front part loads the right part straight into the front (the cover shows until its first frame), or swaps when the back
 *  one already has it.
 */
Item {
    id: root
    property var parts: []
    property var clock: ({ valid: false })
    property bool active: true
    property int fillMode: VideoOutput.PreserveAspectCrop
    property int fadeMs: 250                  // the view passes Theme.ms(250) (reduced motion: 0)

    property bool frontIsA: true
    readonly property var front: frontIsA ? slotA : slotB
    readonly property var back: frontIsA ? slotB : slotA
    property real now: Date.now()
    property bool lingering: false            // the old front stays visible under the new one right after a swap
    readonly property bool frontCovers: root.covers(front.file, root.target)
    readonly property real target: Sync.target(root.clock, root.now)
    readonly property bool ready: root.active && front.ready && root.frontCovers
    readonly property string shownFile: ready ? front.file : ""
    readonly property string preloadFile: back.file
    property int swaps: 0
    readonly property var lastDecision: front.lastDecision

    function partOf(file) {
        const list = root.parts || [];
        for (let i = 0; i < list.length; i++) if (list[i].file === file) return list[i];
        return null;
    }
    function indexOf(file) {
        const list = root.parts || [];
        for (let i = 0; i < list.length; i++) if (list[i].file === file) return i;
        return -1;
    }
    function covers(file, t) {
        const p = file.length ? partOf(file) : null;
        return !!p && t >= 0 && p.start <= t + 0.05 && (p.dur <= 0 || t < p.start + p.dur - 0.05);
    }

    // which file goes into which player: on every tick (4/s), on a new part list and on every browser clock change
    function update() {
        root.now = Date.now();
        if (!root.active) { slotA.file = ""; slotB.file = ""; return; }
        const list = root.parts || [];
        const t = Sync.target(root.clock, root.now);
        const want = Sync.pickPart(list, t, root.indexOf(root.front.file));
        const wantFile = want >= 0 ? list[want].file : "";
        const nxt = Sync.nextPart(list, want);
        const nextFile = nxt >= 0 ? list[nxt].file : "";
        if (wantFile.length && wantFile !== root.front.file) {
            if (wantFile === root.back.file && (root.back.ready || !root.frontCovers)) {
                root.frontIsA = !root.frontIsA;      // the preloaded part takes over; the old front lingers underneath
                root.swaps++;
                root.lingering = true;
                linger.restart();
            } else if (wantFile !== root.back.file && !root.frontCovers) {
                root.front.file = wantFile;          // a jump (or the first part): straight into the front, the cover shows meanwhile
            } else if (wantFile !== root.back.file) {
                root.back.file = wantFile;           // the front still shows the right moment: take over once this one is up
            }
        } else if (!wantFile.length && !root.frontCovers) {
            root.front.file = "";
        }
        // the back player preloads what comes next (unless it still lingers or waits to take over)
        if (!root.lingering && root.back.file !== wantFile && root.back.file !== nextFile) root.back.file = nextFile;
    }
    onPartsChanged: update()
    onClockChanged: update()
    onActiveChanged: update()
    Component.onCompleted: update()
    Timer { interval: 250; repeat: true; running: root.active && (root.parts || []).length > 0; onTriggered: root.update() }
    Timer { id: linger; interval: 600; onTriggered: { root.lingering = false; root.update(); } }

    component Slot: VideoMirror {
        property string file: ""
        property bool isA: false
        readonly property bool isFront: isA === root.frontIsA
        anchors.fill: parent
        fillMode: root.fillMode
        active: root.active && file.length > 0
        source: file
        clock: file.length ? Sync.partClock(root.clock, root.partOf(file) || { start: 0, dur: 0 }, root.now) : ({ valid: false })
        z: isFront ? 1 : 0
        opacity: isFront ? (root.ready ? 1 : 0) : (root.lingering && ready ? 1 : 0)
        Behavior on opacity { NumberAnimation { duration: root.fadeMs } }
    }
    Slot { id: slotA; isA: true }
    Slot { id: slotB }
}
