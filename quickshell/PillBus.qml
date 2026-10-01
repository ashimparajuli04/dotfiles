pragma Singleton

import QtQuick

// Shared state between the bar pills. Each pill that expands LEFTWARD
// publishes its live expansion delta here; every pill to its left binds
// its position shift to the sum of the deltas of the pills on its right,
// so the joined row stays flush while pills expand (push instead of
// overlap; see changes.md §32).
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

    // Brightness is the leftmost pill, so nothing inside PillBus needs its
    // own expansion — but external consumers (the Waybar tray spacer, via
    // TrayShift.qml) do, to know the cluster's full leftward reach.
    property real brightnessPush: 0
    property real brightnessMaxPush: 0

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

    // Total leftward reach of the cluster from its collapsed position — the
    // sum of every pill's live delta. The Waybar tray spacer shifts the
    // system tray left by this much so a hover-expanding pill never covers
    // it (see TrayShift.qml / changes.md §35).
    readonly property real reach: pushBrightness + brightnessPush
    readonly property real maxReach: maxPushBrightness + brightnessMaxPush

    // ---------- hover hold ----------
    // Each pill publishes its hover state here. An expanded pill must NOT
    // collapse while the pointer is on any other pill: the collapse would
    // push the row and slide the pill under the cursor (the wifi →
    // bluetooth flicker). Instead, a single shared grace timer runs only
    // while the whole row is unhovered; when it fires, every expanded pill
    // collapses together, so the joined row stays flush.
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
    // time to change your mind (the joined pills have no gaps to cross)
    // without feeling sluggish when leaving the bar.
    property Timer idleTimer: Timer {
        interval: 500
        onTriggered: if (!bus.hoverAny)
            bus.collapseTick++
    }

    // ---------- panel open state (drives lazy loading) ----------
    // shell.qml wraps each popover in a LazyLoader keyed to these flags, so a
    // panel exists only while open and is destroyed when closed (~0 cost shut).
    // Pills call toggleOpen(); external `qs ipc call` reaches them through the
    // always-on PanelIpc. Removes the old `qs ipc` subprocess coordination and
    // lets the heavy popovers stay unloaded. See changes.md §39.
    property bool soundOpen: false
    property bool batteryOpen: false
    property bool bluetoothOpen: false
    property bool wifiOpen: false
    property bool musicOpen: false
    property bool powermenuOpen: false
    property bool discordOpen: false
    property int musicTab: 0

    readonly property var panelNames: ["sound", "battery", "bluetooth", "wifi", "music", "powermenu", "discord"]

    function isOpen(name) {
        switch (name) {
        case "sound": return soundOpen
        case "battery": return batteryOpen
        case "bluetooth": return bluetoothOpen
        case "wifi": return wifiOpen
        case "music": return musicOpen
        case "powermenu": return powermenuOpen
        case "discord": return discordOpen
        }
        return false
    }

    function setOpen(name, v) {
        switch (name) {
        case "sound": soundOpen = v; break
        case "battery": batteryOpen = v; break
        case "bluetooth": bluetoothOpen = v; break
        case "wifi": wifiOpen = v; break
        case "music": musicOpen = v; break
        case "powermenu": powermenuOpen = v; break
        case "discord": discordOpen = v; break
        }
    }

    function closeOthers(name) {
        for (var i = 0; i < panelNames.length; i++)
            if (panelNames[i] !== name)
                setOpen(panelNames[i], false)
    }

    function closeAll() {
        for (var i = 0; i < panelNames.length; i++)
            setOpen(panelNames[i], false)
    }

    function show(name) {
        closeOthers(name)
        setOpen(name, true)
    }

    function close(name) {
        setOpen(name, false)
    }

    function toggleOpen(name) {
        var v = !isOpen(name)
        if (v)
            closeOthers(name)
        setOpen(name, v)
    }
}
