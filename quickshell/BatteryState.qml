pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Shared battery state for the Waybar-replacement pill (BatteryPill.qml)
// and the Low Power Mode popover (BatteryPanel.qml). The glyphs and
// colours mirror the old Waybar battery module exactly. See changes.md §22.
QtObject {
    // UPower.displayDevice is null on machines without a battery.
    readonly property var bat: UPower.displayDevice
    readonly property bool ready: bat !== null && bat !== undefined && bat.ready

    // Quickshell's UPower percentage is 0.0–1.0 (upower's 0–100 is scaled
    // by the service), so convert before rounding.
    readonly property int percent: ready ? Math.round(bat.percentage * 100) : 0
    readonly property int state: ready ? bat.state : UPowerDeviceState.Unknown
    readonly property string stateText: ready ? UPowerDeviceState.toString(bat.state) : "No battery"

    // The display device is a composite: it has percentage/state/rates but
    // no Capacity/EnergyFull, so health comes from the real laptop battery.
    readonly property var laptopBattery: {
        var src = modelValues(UPower.devices)
        for (var i = 0; i < src.length; i++) {
            if (src[i].isLaptopBattery)
                return src[i]
        }
        return null
    }
    readonly property bool healthSupported: laptopBattery !== null && laptopBattery.healthSupported
    readonly property real healthPercentage: healthSupported ? laptopBattery.healthPercentage : 0
    readonly property real energyCapacity: healthSupported ? laptopBattery.energyCapacity : 0

    function modelValues(m) {
        if (!m)
            return []
        if (m.values !== undefined)
            return m.values
        var out = []
        var n = m.length !== undefined ? m.length : 0
        for (var i = 0; i < n; i++)
            out.push(m[i])
        return out
    }

    readonly property bool charging: ready
        && (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge)
    readonly property bool full: ready
        && (state === UPowerDeviceState.FullyCharged || percent >= 100)
    readonly property bool plugged: !UPower.onBattery
    readonly property bool warning: ready && !charging && percent <= 25
    readonly property bool critical: ready && !charging && percent <= 10

    // The old Waybar module's format-icons arrays, kept verbatim.
    readonly property var chargingIcons: ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
    readonly property var defaultIcons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    // Waybar picks ceil(capacity / 100 × icon count) − 1, clamped.
    readonly property string glyph: {
        var icons = charging ? chargingIcons : defaultIcons
        var i = Math.ceil(percent / 100 * icons.length) - 1
        i = Math.max(0, Math.min(icons.length - 1, i))
        return icons[ready ? i : 0]
    }

    // The old #battery CSS palette (base / charging / warning / critical /
    // full-plugged), with the CSS cascade order reproduced.
    readonly property color fg: critical ? "#fb958b"
        : warning ? "#ecd3a0"
        : charging ? "#87bb82"
        : (full || plugged) ? "#91ffc3"
        : "#8fbcbb"
}
