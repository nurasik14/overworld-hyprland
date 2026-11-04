pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

/*  NotificationService — the org.freedesktop.Notifications daemon + the desk of notes.
 *
 *  NotificationService.all      every tracked note (newest first)        → notification centre
 *  NotificationService.popups   notes currently shown as paper-note popups (newest first)
 *  NotificationService.groups   [{ app, icon, notes: [...] }] newest app first
 *  NotificationService.dnd / unread · toggleDnd() · dismiss(note) · dismissAll() · expirePopup(note)
 *
 *  Each note is a NoteWrapper { n (Notification), id, time, popup, hovered, urgency, timeout }.
 *  Timeouts: low 4 s · normal 7 s · critical sticky (0). Hover pauses the popup timer.
 */
Singleton {
    id: root

    property bool dnd: false
    property int unread: 0
    property var all: []        // NoteWrapper[], newest first
    readonly property var popups: all.filter(w => w.popup)
    readonly property int count: all.length

    readonly property var groups: {
        const map = {}, order = [];
        for (let i = 0; i < all.length; i++) {
            const w = all[i];
            const key = w.appName || "Unknown";
            if (!map[key]) { map[key] = { app: key, icon: w.appIcon, notes: [] }; order.push(key); }
            map[key].notes.push(w);
        }
        return order.map(k => map[k]);
    }

    component NoteWrapper: QtObject {
        id: wrap
        required property var n
        property int nid: 0
        property double time: Date.now()
        property bool popup: false
        property bool hovered: false
        property bool closing: false
        property bool pendingDismiss: false
        readonly property string appName: n ? (n.appName || "") : ""
        readonly property string appIcon: n ? (n.appIcon || "") : ""
        readonly property string summary: n ? (n.summary || "") : ""
        readonly property string body: n ? (n.body || "") : ""
        readonly property string image: n ? (n.image || "") : ""
        readonly property int urgency: n ? n.urgency : NotificationUrgency.Normal
        readonly property bool critical: urgency === NotificationUrgency.Critical
        readonly property bool low: urgency === NotificationUrgency.Low
        readonly property var actions: n ? n.actions : []
        readonly property int timeout: critical ? 0
                                     : (n && n.expireTimeout > 0 ? n.expireTimeout
                                        : (low ? ConfigService.timeoutLow : ConfigService.timeoutNormal))
        property Timer timer: Timer {
            interval: Math.max(1, wrap.timeout)
            running: wrap.popup && wrap.timeout > 0 && !wrap.hovered
            repeat: false
            onTriggered: root.expirePopup(wrap)
        }
        property Timer closeTimer: Timer {      // lets the card slide out (durFast) before it leaves the model
            interval: 200
            onTriggered: {
                wrap.popup = false; wrap.closing = false;
                if (wrap.pendingDismiss) { wrap.pendingDismiss = false; root.dismiss(wrap); }
                else if (wrap.n && wrap.n.transient) wrap.n.expire();
            }
        }
        property Connections conn: Connections {
            target: wrap.n
            function onClosed(reason) { root.remove(wrap); }
        }
    }
    Component { id: wrapperComponent; NoteWrapper {} }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodySupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => {
            // JaKooLit's Volume.sh / Brightness.sh (still bound to the XF86 keys) send a note tagged
            // x-canonical-private-synchronous: volume_notif | brightness_notif; the Overworld OSD already covers
            // those keys, so swallow such notes instead of showing a paper note next to the slip.
            const sync = notification.hints ? notification.hints["x-canonical-private-synchronous"] : undefined;
            if (sync === "volume_notif" || sync === "brightness_notif") { notification.expire(); return; }
            notification.tracked = true;
            const w = wrapperComponent.createObject(root, { n: notification, nid: notification.id, time: Date.now() });
            w.popup = !root.dnd;
            root.all = [w].concat(root.all);
            root.unread++;
            if (!root.dnd) SoundService.play(w.critical ? "notify-urgent" : "notify");
        }
    }

    function expirePopup(w) {           // popup slides away, note stays on the desk (unless transient)
        if (!w || w.closing) return;
        if (!w.popup) { if (w.n && w.n.transient) w.n.expire(); return; }
        w.closing = true;
        w.closeTimer.start();
    }
    function dismissPopup(w) {          // user closed the popup: slide out, then dismiss
        if (!w) return;
        if (!w.popup || w.closing) { dismiss(w); return; }
        w.pendingDismiss = true;
        w.closing = true;
        w.closeTimer.start();
    }
    function dismiss(w) {               // user closed it: tell the app and drop it
        if (!w) return;
        if (w.n) w.n.dismiss(); else remove(w);
    }
    function remove(w) {
        const i = root.all.indexOf(w);
        if (i < 0) return;
        const copy = root.all.slice();
        copy.splice(i, 1);
        root.all = copy;
        w.destroy();
    }
    function dismissAll() {
        const copy = root.all.slice();
        for (let i = 0; i < copy.length; i++) if (copy[i].n) copy[i].n.dismiss(); else remove(copy[i]);
        root.unread = 0;
    }
    function hidePopups() { for (let i = 0; i < root.all.length; i++) root.all[i].popup = false; }
    function toggleDnd() {
        root.dnd = !root.dnd;
        if (root.dnd) hidePopups();
    }
    function markRead() { root.unread = 0; }
    function invokeDefault(w) {         // click on the body: default action if present, else dismiss
        if (!w || !w.n) return;
        const acts = w.n.actions || [];
        for (let i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default") { acts[i].invoke(); return; }
        }
        if (acts.length === 1) { acts[0].invoke(); return; }
        dismissPopup(w);
    }
    function appGlyph(name) {           // fallback seal glyph: first letter of the app name
        const s = (name || "").trim();
        return s.length ? s[0].toUpperCase() : "报";
    }
}
