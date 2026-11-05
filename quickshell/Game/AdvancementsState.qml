pragma Singleton
import QtQuick
import Quickshell

// UI hooks for IPC (`advancements tab <id>`): the screen listens to tabRequested.
Singleton {
    id: root
    signal tabRequested(string id)
    signal inspectRequested(string id)
    signal resetDialogRequested()
    function requestTab(id) { tabRequested(id); }
    function requestInspect(id) { inspectRequested(id); }
    function requestResetDialog() { resetDialogRequested(); }
}
