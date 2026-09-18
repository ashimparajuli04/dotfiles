pragma Singleton

import QtQuick

// Shared state between the bar pills. Each pill that expands LEFTWARD
// publishes its live expansion delta here; every pill to its left binds
// its position shift to the sum of the deltas of the pills on its right,
// so the row keeps its gaps while pills expand (push instead of overlap).
//
// Layout (left → right): brightness · sound · bluetooth · wifi · battery
QtObject {
    id: bus

    // Live push distances — follow each pill's width animation
    // frame-by-frame while the pill expands/contracts.
    property real soundPush: 0
    property real btPush: 0
    property real wifiPush: 0
    property real batteryPush: 0

    // Maximum push from each pill (expanded width − collapsed width).
    property real soundMaxPush: 0
    property real btMaxPush: 0
    property real wifiMaxPush: 0
    property real batteryMaxPush: 0

    // The shift applied to a pill's position (sum of the pushes of every
    // expanding pill to its right).
    readonly property real pushBt: wifiPush + batteryPush
    readonly property real pushWifi: batteryPush
    readonly property real pushSound: btPush + wifiPush + batteryPush
    readonly property real pushBrightness: soundPush + btPush + wifiPush + batteryPush

    // Window slack needed for the same sums at full expansion.
    readonly property real maxPushBt: wifiMaxPush + batteryMaxPush
    readonly property real maxPushWifi: batteryMaxPush
    readonly property real maxPushSound: btMaxPush + wifiMaxPush + batteryMaxPush
    readonly property real maxPushBrightness: soundMaxPush + btMaxPush + wifiMaxPush + batteryMaxPush

    // ---------- hover hold ----------
    // Each pill publishes its hover state here. An expanded pill must NOT
    // collapse while the pointer is on any other pill: the collapse would
    // push the row and slide the pill under the cursor (the wifi →
    // bluetooth flicker). Instead, a single shared grace timer runs only
    // while the whole row is unhovered; when it fires, every expanded pill
    // collapses together, so the row keeps its gaps.
    property bool hoverBrightness: false
    property bool hoverSound: false
    property bool hoverBt: false
    property bool hoverWifi: false
    property bool hoverBattery: false

    readonly property bool hoverAny: hoverBrightness || hoverSound
        || hoverBt || hoverWifi || hoverBattery

    // Bumped when the row has been fully unhovered for the grace period;
    // each expanded pill listens and collapses off this single broadcast.
    property int collapseTick: 0

    onHoverAnyChanged: {
        if (hoverAny)
            idleTimer.stop()
        else
            idleTimer.restart()
    }

    // Grace period once the pointer has left the whole row. 500 ms: enough
    // time to cross the ~10 px gap between pills (or change your mind)
    // without feeling sluggish when leaving the bar.
    property Timer idleTimer: Timer {
        interval: 500
        onTriggered: if (!bus.hoverAny)
            bus.collapseTick++
    }
}
