pragma Singleton

import QtQuick

// Shared state between the bar pills. Each pill that expands LEFTWARD
// publishes its live expansion delta here; every pill to its left binds
// its position shift to the sum of the deltas of the pills on its right,
// so the row keeps its gaps while pills expand (push instead of overlap).
//
// Layout (left → right): brightness · sound · bluetooth · wifi
QtObject {
    // Live push distances — follow each pill's width animation
    // frame-by-frame while the pill expands/contracts.
    property real soundPush: 0
    property real btPush: 0
    property real wifiPush: 0

    // Maximum push from each pill (expanded width − collapsed width).
    property real soundMaxPush: 0
    property real btMaxPush: 0
    property real wifiMaxPush: 0

    // The shift applied to a pill's position (sum of the pushes of every
    // expanding pill to its right).
    readonly property real pushSound: btPush + wifiPush
    readonly property real pushBrightness: soundPush + btPush + wifiPush

    // Window slack needed for the same sums at full expansion.
    readonly property real maxPushSound: btMaxPush + wifiMaxPush
    readonly property real maxPushBrightness: soundMaxPush + btMaxPush + wifiMaxPush
}
