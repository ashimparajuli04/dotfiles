import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland

// The Waybar network pill, re-created as a Quickshell overlay. Hovering it
// opens WifiPanel as a preview (held while the pointer is on the pill or the
// panel, closed 1s after leaving both); clicking it opens/latches the panel
// until an outside click. See PillBus.qml for the shared preview logic.
//
// Geometry: sits on the transparent `custom/wifi` Waybar spacer (right edge
// at x=1849, flush against the battery pill; joined row). It no longer
// expands; the battery pill (to the right) still pushes it left via PillBus.
Scope {
    id: root

    readonly property color accent: "#268bd2"           // waybar #network
    readonly property color disconnectedColor: "#fb958b" // waybar #network.disconnected

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots — see changes.md §15/§25.
    // Joined row (§32): rightMargin 71 = 44 (battery) + 27 (battery width),
    // so this pill's right edge sits flush against the battery pill. Width is
    // 27 to match the other pills, so every icon sits an even 27px apart.
    readonly property int collapsedWidth: 27
    readonly property int rightMargin: 62       // screen right edge → window right edge
    readonly property int pillHeight: 24

    // ---------- state ----------
    readonly property var wifiDevice: {
        var src = root.modelValues(Networking.devices)
        for (var i = 0; i < src.length; i++) {
            if (src[i].type === DeviceType.Wifi)
                return src[i]
        }
        return null
    }

    readonly property var wiredDevice: {
        var src = root.modelValues(Networking.devices)
        for (var i = 0; i < src.length; i++) {
            if (src[i].type === DeviceType.Wired && src[i].connected)
                return src[i]
        }
        return null
    }

    readonly property var connectedWifi: {
        if (!root.wifiDevice)
            return null
        var nets = root.modelValues(root.wifiDevice.networks)
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected)
                return nets[i]
        }
        return null
    }

    readonly property bool connected: root.connectedWifi !== null
    readonly property bool wired: root.wiredDevice !== null
    readonly property int signalPercent: root.connected
        ? Math.round(root.connectedWifi.signalStrength * 100) : 0

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

    // Same glyphs as the old Waybar module (signal glyphs there carried a
    // trailing space because the module's paddings were asymmetric; the
    // Quickshell pill centres its content, so the space would push the ink
    // 4 px left — dropped here).
    readonly property var wifiIcons: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]

    // Waybar picked the icon from its own signal percentage; until the
    // first /proc sample lands, use NetworkManager's percentage with the
    // same buckets (20% steps).
    readonly property int nmIconIdx: Math.max(0, Math.min(4,
        Math.floor(root.signalPercent / 20)))

    readonly property string glyph: {
        if (root.connected)
            return root.wifiIcons[root.wbIconIdx >= 0 ? root.wbIconIdx : root.nmIconIdx]
        if (root.wired)
            return "󰈀"
        return "󰤮"
    }

    readonly property color fg: (root.connected || root.wired) ? root.accent : root.disconnectedColor

    property int wbIconIdx: -1

    // ---------- waybar-exact signal strength ----------
    // The old Waybar 0.15 network module computed its icon from the
    // driver's RSSI with a "punish too-strong signals" formula:
    //   strength = 100 - |dBm + 45| / 45 * 100   (clamped to 0..100)
    // then picked icon floor(strength / 20) from the 5 format-icons.
    // Reading the same /proc value and applying the same formula keeps
    // the glyph identical to the pre-Quickshell bar; NetworkManager's
    // percentage is only the startup fallback.
    // Read /proc/net/wireless in-process (FileView) instead of forking `cat`
    // every 5s; reloaded on the same cadence, identical output.
    FileView {
        id: wirelessView
        path: "/proc/net/wireless"
        printErrors: false
        onLoaded: root.applyWireless(wirelessView.text())
    }

    function applyWireless(text) {
        var dev = root.wifiDevice ? root.wifiDevice.name : ""
        if (!dev)
            return
        var m = String(text).match(new RegExp("^\\s*" + dev + ":\\s*\\S+\\s+([\\d.]+)\\s+(-?\\d+)", "m"))
        if (!m)
            return
        var dbm = parseInt(m[2])
        if (isNaN(dbm) || dbm >= 0 || dbm <= -200)
            return
        var s = 100 - Math.abs(dbm + 45) / 45 * 100
        s = Math.max(0, Math.min(100, Math.floor(s)))
        root.wbIconIdx = Math.max(0, Math.min(4, Math.floor(s / 20)))
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: wirelessView.reload()
    }

    // Publish "pointer is on the pill" so PillBus can hold the preview panel
    // open while the pointer is either on the pill or on the panel.
    Binding {
        target: PillBus
        property: "hoverWifi"
        value: hover.hovered
    }

    // Hover opens the panel as a preview; a click opens it latched. The shared
    // close timer / latch flag live in PillBus.qml so the three preview
    // popovers never fight over which one is open.
    function openPreview() {
        if (!PillBus.wifiOpen) {
            PillBus.show("wifi")
            PillBus.panelLatched = false
        }
    }

    function toggle() {
        if (PillBus.wifiOpen) {
            if (PillBus.panelLatched)
                PillBus.close("wifi")
            else
                PillBus.panelLatched = true
        } else {
            PillBus.show("wifi")
            PillBus.panelLatched = true
        }
    }

    PanelWindow {
        screen: BarScreen.screen
        id: win

        // Fullscreen on this output hides the whole bar (see FullscreenWatch).
        visible: !FullscreenWatch.covering

        anchors {
            top: true
            right: true
        }

        margins {
            top: -24
            right: root.rightMargin
        }

        implicitWidth: root.collapsedWidth + PillBus.maxPushWifi
        implicitHeight: root.pillHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:wifi-pill"

        // Only the pill itself takes input; the rest of the surface
        // stays click-through.
        mask: Region {
            x: pill.x
            y: pill.y
            width: pill.width
            height: pill.height
            radius: pill.radius
        }

        Rectangle {
            id: pill
            anchors.top: parent.top
            // Right edge normally at 1856, flush against the battery
            // pill; the battery pill (to the right) pushes this pill left
            // while it expands.
            x: win.width - width - PillBus.pushWifi
            height: root.pillHeight
            // Icon-only now (no hover expansion); the battery pill still
            // pushes this one left while it expands.
            width: root.collapsedWidth
            // Middle segment of the joined row: square corners.
            radius: 0
            color: "#040404"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle()
            }

            HoverHandler {
                id: hover
                // Don't open on the first pixel of hover: report the pointer to
                // PillBus and let it open the preview only after a short rest,
                // so an accidental slide across the row passes through (see
                // PillBus.requestPreview / hoverOpenDelay).
                onHoveredChanged: {
                    if (hovered)
                        PillBus.requestPreview("wifi")
                    else
                        PillBus.cancelPreview("wifi")
                }
            }

            // Fires once the pointer has rested here long enough.
            Connections {
                target: PillBus
                function onPreviewTickChanged() {
                    if (PillBus.previewName === "wifi" && hover.hovered)
                        root.openPreview()
                }
            }

            Text {
                id: glyphText
                anchors.centerIn: parent
                text: root.glyph
                color: root.fg
                // The old Waybar pill's font stack lists Material
                // Design Icons first, so its glyphs came from there.
                font.family: "Material Design Icons"
                font.pixelSize: 13
                font.bold: true
            }
        }
    }
}
