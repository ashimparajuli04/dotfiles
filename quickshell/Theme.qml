pragma Singleton

import QtQuick

QtObject {
    // New Wave palette (matches rofi style-2.rasi / waybar)
    readonly property color bg: "#040404"
    readonly property color bgAlt: "#32197D"
    readonly property color fg: "#FFFFFF"
    readonly property color muted: "#A79BC8"
    readonly property color accent: "#FF00F1"
    readonly property color active: "#9878FF"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int radius: 20
}
