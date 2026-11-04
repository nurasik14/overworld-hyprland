pragma Singleton
import QtQuick
import Quickshell

// UI hooks for IPC (`advancements tab <id>`): the screen listens to tabRequested.
Singleton {
    id: root
    signal tabRequested(string id)
    signal inspectRequested(string id)
    function requestTab(id) { tabRequested(id); }
    function requestInspect(id) { inspectRequested(id); }
}
