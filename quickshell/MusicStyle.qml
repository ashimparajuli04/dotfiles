pragma Singleton

import QtQuick

// Palette + layout for the music widget, matched to the original eww widget
// (sampled from a screenshot of it): dark backdrop, pink card, lavender
// lyrics. Layout constants derive from the measured original: ~466 px wide
// window, 150 px cover.
QtObject {
    readonly property color bg: "#df6bac"        // pink card
    readonly property color fg: "#1A182C"        // dark text / borders / backdrop
    readonly property color border: "#1A182C"
    readonly property color lyrics: "#A79BC8"    // lyrics text on the backdrop

    // Neon pair for the visualizer (currently unused — re-added later).
    readonly property color neonA: "#FF00F1"
    readonly property color neonB: "#9878FF"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // ---------- layout ----------
    readonly property int widgetWidth: 466
    readonly property int widgetPadding: 30
    readonly property int cardPadding: 16
    readonly property int cardGap: 12
    readonly property int lyricsHeight: 220
    readonly property int buttonHeight: 38

    // height of the pink card: padding + cover + gap + button row + padding
    readonly property int cardHeight: cardPadding * 2 + 150 + 10 + buttonHeight

    // total panel height; used by MusicPanel to sit above the widget
    readonly property int widgetHeight: widgetPadding * 2 + cardHeight + cardGap + lyricsHeight
}
