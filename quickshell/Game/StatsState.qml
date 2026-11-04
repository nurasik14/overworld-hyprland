pragma Singleton
import QtQuick
import Quickshell

// UI hook for IPC (`stats tab <general|items|mobs>`): the screen listens to tabRequested.
Singleton {
    id: root
    signal tabRequested(string name)
    function requestTab(name) { tabRequested(name); }
}
