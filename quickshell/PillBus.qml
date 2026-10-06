pragma Singleton

import QtQuick
import Quickshell.Io

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

    // The system tray pill's live left edge, measured from the screen's right
    // edge (published by TrayWidget.qml). The Discord voice pill sits a fixed
    // gap left of this, so it tracks the tray's real width instead of a fixed
    // reserved slot and never collides as tray icons come and go. Defaults to
    // one tray icon's worth until TrayWidget publishes the real value.
    property real trayLeftInset: 212

    // ---------- hover hold (pill expansion) ----------
    // Brightness and battery expand on hover. While the pointer is on ANY pill
    // in the row, the expanded one must not collapse — collapsing shifts the
    // row and slides a different icon under the cursor. So a single shared
    // grace timer runs only while the whole row is unhovered; when it fires the
    // expanded pills collapse together (see BrightnessPill/BatteryPill).
    property bool hoverBrightness: false
    property bool hoverBattery: false

    // The wifi / bluetooth / sound pills no longer expand; they publish "the
    // pointer is on my pill" here for both the preview coordinator below and
    // the expansion hold above. Discord likewise shifts with the cluster.
    property bool hoverSound: false
    property bool hoverBt: false
    property bool hoverWifi: false
    property bool hoverDiscord: false

    readonly property bool hoverAny: hoverBrightness || hoverBattery
        || hoverSound || hoverBt || hoverWifi || hoverDiscord

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

    // ---------- preview popovers (wifi / bluetooth / sound / battery) ----------
    // Hovering one of those pills opens its panel as a *preview*: it is held
    // open while the pointer is on the pill OR on the panel, and auto-closes
    // after 1s away from both. Clicking the pill — or tapping inside the panel,
    // or opening it via IPC — *latches* it, so it then stays until an outside
    // click (or Esc) no matter where the pointer goes. Only one panel is ever
    // open (show() closes the others), so all of them share this single timer
    // and latch flag; the pills/panels "talk" to each other through here.
    property bool pointerOnPanel: false
    property bool panelLatched: false

    readonly property bool previewPanelHeld: hoverWifi || hoverBt
        || hoverSound || hoverBattery || pointerOnPanel
    readonly property bool previewPanelOpen: wifiOpen || bluetoothOpen
        || soundOpen || batteryOpen

    onPreviewPanelHeldChanged: {
        if (previewPanelHeld)
            previewCloseTimer.stop()
        else
            previewCloseTimer.restart()
    }

    // 1s: how long the pointer may be off both the pill and the panel (e.g.
    // crossing the gap between them) before an unlatched preview closes.
    property Timer previewCloseTimer: Timer {
        interval: 1000
        onTriggered: {
            if (bus.previewPanelHeld || bus.panelLatched)
                return
            if (bus.wifiOpen)
                bus.close("wifi")
            else if (bus.bluetoothOpen)
                bus.close("bluetooth")
            else if (bus.soundOpen)
                bus.close("sound")
            else if (bus.batteryOpen)
                bus.close("battery")
        }
    }

    // Reset the transient preview state whenever all the preview panels are
    // closed by anyone (catcher, Esc, another pill's show(), or IPC hide).
    function previewReset() {
        if (!bus.previewPanelOpen) {
            panelLatched = false
            pointerOnPanel = false
            previewCloseTimer.stop()
        }
    }

    onWifiOpenChanged: previewReset()
    onBluetoothOpenChanged: previewReset()
    onSoundOpenChanged: previewReset()
    onBatteryOpenChanged: previewReset()

    // ---------- hover-intent (delay before a preview opens) ----------
    // A hover preview must not fire the instant the pointer clips a pill: an
    // accidental slide across the row — or brushing a pill on the way to
    // another — should pass through silently. Each preview pill reports the
    // pointer on enter and cancels on leave; one shared timer then opens the
    // preview only after the pointer has RESTED on the same pill for
    // hoverOpenDelay ms. Clicking a pill (or opening it via IPC) is unaffected:
    // it still latches immediately.
    property string pendingPreview: ""   // pill the pointer is resting on
    property string previewName: ""      // pill whose dwell just elapsed
    property int previewTick: 0          // bumped when previewName is due
    property int hoverOpenDelay: 250     // ms of rest before a preview opens

    // Whether the pointer is currently on the named pill (each pill publishes
    // its own hover state above).
    function pillHovered(name) {
        switch (name) {
        case "wifi": return hoverWifi
        case "bluetooth": return hoverBt
        case "sound": return hoverSound
        case "battery": return hoverBattery
        }
        return false
    }

    // A pill calls this when the pointer enters it.
    function requestPreview(name) {
        if (bus.pendingPreview === name)
            return
        bus.pendingPreview = name
        hoverOpenTimer.restart()
    }

    // A pill calls this when the pointer leaves it. Only the pill that owns
    // the pending dwell may cancel it — moving from A to B cancels A and
    // (re)starts B regardless of the order the two events arrive in.
    function cancelPreview(name) {
        if (bus.pendingPreview !== name)
            return
        hoverOpenTimer.stop()
        bus.pendingPreview = ""
    }

    property Timer hoverOpenTimer: Timer {
        interval: bus.hoverOpenDelay
        onTriggered: {
            var n = bus.pendingPreview
            bus.pendingPreview = ""
            // Fire only if the pointer is still resting on that same pill.
            if (n === "" || !bus.pillHovered(n))
                return
            bus.previewName = n
            bus.previewTick++
        }
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
    property bool clipboardOpen: false
    property int musicTab: 0

    // Clipboard popover state (ClipboardPanel.qml). The pill itself is drawn
    // by Waybar (#custom-clipboard), so nothing here draws or tracks it:
    //   clipboardPinned — pin button keeps the panel open after picking an item
    //   clipboardLeft   — left edge of the Waybar pill, so the popover sits
    //                     under it. Recomputed from the workspace count below.
    property bool clipboardPinned: false
    property int wsCount: 0
    readonly property real clipboardLeft: Math.round(52 + 16 * bus.wsCount)

    // The #custom-clipboard pill sits just right of the workspaces module,
    // whose width is linear in the workspace count (one 24px focused dot, the
    // rest 8px; see waybar/style.css). Waybar doesn't expose module geometry,
    // so recompute the pill's left offset to place the popover under it. The
    // pill needs no tracking — Waybar lays it out (and animates it) itself.
    property Process wsProc: Process {
        command: ["swaymsg", "-t", "get_workspaces", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = String(text).match(/"type"\s*:\s*"workspace"/g)
                bus.wsCount = m ? m.length : 0
            }
        }
    }

    property Timer wsPoll: Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: bus.wsProc.running = true
    }

    readonly property var panelNames: ["sound", "battery", "bluetooth", "wifi", "music", "powermenu", "discord", "clipboard"]

    function isOpen(name) {
        switch (name) {
        case "sound": return soundOpen
        case "battery": return batteryOpen
        case "bluetooth": return bluetoothOpen
        case "wifi": return wifiOpen
        case "music": return musicOpen
        case "powermenu": return powermenuOpen
        case "discord": return discordOpen
        case "clipboard": return clipboardOpen
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
        case "clipboard": clipboardOpen = v; break
        }
    }

    // Powermenu is a centred, full-screen overlay that neither opens on hover
    // nor overlaps the right-side popovers, so it is exempt from the
    // single-panel rule: opening another panel leaves it open, and opening it
    // closes nothing. Every other panel still closes its siblings.
    function closeOthers(name) {
        if (name === "powermenu")
            return
        for (var i = 0; i < panelNames.length; i++)
            if (panelNames[i] !== name && panelNames[i] !== "powermenu")
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
