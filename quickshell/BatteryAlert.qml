pragma Singleton

import QtQuick

// Battery pill alerts, driven straight off the live UPower state in
// BatteryState.qml — no polling daemon (this replaces the old bash
// ~/.config/battery-alert loop, which posted notifications through the
// notification daemon).
//
// The pill itself does the talking: BatteryPill.qml binds its expansion to
// `forceExpand` and renders `label`. Two things force it open:
//   * a transient "pop" — a word shown for a few seconds on an event
//     (plug in → Charging, unplug → On battery, charge to 100 % →
//     Fully charged!, and 20/10/5 % → Running low / Critical / Final
//     moments);
//   * the idle 50 % rule — from 50 % down the percentage stays visible
//     (no word) until the battery climbs back above 50 %.
QtObject {
    id: root

    // A word pop's on-screen time. "Fully charged!" is a calmer state, so it
    // gets the shorter 3 s the design asked for; the rest sit at 5 s.
    readonly property int popDuration: 5000
    readonly property int fullPopDuration: 3000

    // The word currently popped ("" when none). BatteryPill reads this.
    property string label: ""

    // ---------- edge detection ----------
    // Thresholds fire once per downward crossing and re-arm only once the
    // battery is clearly back above them (the small hysteresis keeps a 1 %
    // bounce — or a reboot — from re-popping).
    property bool armed20: true
    property bool armed10: true
    property bool armed5: true
    property bool armedFull: true

    property int lastPercent: -1
    property bool lastPlugged: false

    readonly property bool ready: BatteryState.ready
    readonly property int percent: BatteryState.percent
    readonly property bool plugged: BatteryState.plugged
    readonly property bool charging: BatteryState.charging

    // Idle "always show the percentage" band: 50 % and below.
    readonly property bool pinned: ready && percent <= 50

    // BatteryPill binds its expansion to this.
    readonly property bool forceExpand: pinned || label !== ""

    // The most severe low-battery word for a given level, or "".
    function lowLabel(p) {
        if (p <= 5)
            return "Final moments"
        if (p <= 10)
            return "Critical"
        if (p <= 20)
            return "Running low"
        return ""
    }

    function pop(text, duration) {
        root.label = text
        popTimer.interval = duration
        popTimer.restart()
    }

    // Dev/test hook (see PanelIpc `battery alertpop`) so the pops can be
    // exercised without waiting for a real discharge.
    function testPop(text) {
        pop(String(text), popDuration)
    }

    function evaluate() {
        if (!ready) {
            lastPercent = -1
            return
        }

        var p = percent
        var prev = lastPercent
        var lowWord = ""

        // Re-arm thresholds once clearly back above them.
        if (p > 22)
            armed20 = true
        if (p > 12)
            armed10 = true
        if (p > 7)
            armed5 = true
        if (p < 99 || !plugged)
            armedFull = true

        // Plug / unplug edges.
        if (plugged && !lastPlugged) {
            if (p < 100)
                pop("Charging", popDuration)
        } else if (!plugged && lastPlugged) {
            // If we unplug already below a threshold (e.g. we were charging at
            // 18 %), say the low word instead — a plain "On battery" would
            // swallow the warning, since there is no downward crossing left to
            // detect.
            lowWord = lowLabel(p)
            pop(lowWord !== "" ? lowWord : "On battery", popDuration)
            if (lowWord === "Running low")
                armed20 = false
            else if (lowWord === "Critical")
                armed10 = false
            else if (lowWord === "Final moments")
                armed5 = false
        }

        // Reached full while plugged in.
        if (plugged && p >= 100 && armedFull) {
            pop("Fully charged!", fullPopDuration)
            armedFull = false
        }

        // Downward threshold crossings — only meaningful while discharging.
        if (!charging) {
            if (prev > 20 && p <= 20 && armed20) {
                pop("Running low", popDuration)
                armed20 = false
            }
            if (prev > 10 && p <= 10 && armed10) {
                pop("Critical", popDuration)
                armed10 = false
            }
            if (prev > 5 && p <= 5 && armed5) {
                pop("Final moments", popDuration)
                armed5 = false
            }
        }

        lastPercent = p
        lastPlugged = plugged
    }

    property Timer popTimer: Timer {
        interval: root.popDuration
        onTriggered: root.label = ""
    }

    property Connections stateConns: Connections {
        target: BatteryState
        function onPercentChanged() { root.evaluate() }
        function onPluggedChanged() { root.evaluate() }
        function onChargingChanged() { root.evaluate() }
    }

    // Prime the memory so booting up (already low, already full, already
    // plugged) never fires a spurious pop on the first UPower tick.
    Component.onCompleted: {
        if (root.ready) {
            root.lastPercent = root.percent
            root.armed20 = root.percent > 20
            root.armed10 = root.percent > 10
            root.armed5 = root.percent > 5
            root.armedFull = !(root.plugged && root.percent >= 100)
        }
        root.lastPlugged = root.plugged
    }
}
