pragma Singleton

import QtQuick

// Palette of the eww music widget this replaces — kept deliberately so the
// Quickshell version is visually indistinguishable from the old one.
QtObject {
    readonly property color bg: "#df6bac"        // pink box
    readonly property color fg: "#1A182C"        // dark text / borders
    readonly property color border: "#1A182C"

    // Neon pair used only inside the visualizer strip.
    readonly property color neonA: "#FF00F1"
    readonly property color neonB: "#9878FF"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
}
