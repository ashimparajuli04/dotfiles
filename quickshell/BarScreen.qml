pragma Singleton

import QtQuick
import Quickshell

// The one output the whole bar (Waybar + every Quickshell overlay) lives on.
//
// Waybar duplicates its bar across every connected output unless `output` is
// set, and an unset PanelWindow.screen defaults to Qt's primary screen — so
// with a second display the Waybar layout and the Quickshell pills land on
// different monitors (the "half the bar on each screen" bug). The display
// setup wizard (Displays.qml) updates preferredName when the chosen main
// display changes; every PanelWindow binds its `screen` to this.
QtObject {
    // Output name the bar is pinned to. Kept in sync with the Waybar `output`
    // by Displays.qml (bin/waybar-output writes the include file).
    property string preferredName: "eDP-1"

    readonly property var screen: {
        var s = Quickshell.screens
        for (var i = 0; i < s.length; i++)
            if (s[i].name === preferredName)
                return s[i]
        return s.length > 0 ? s[0] : null
    }
}
