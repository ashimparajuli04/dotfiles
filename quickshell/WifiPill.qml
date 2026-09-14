import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland

// The Waybar network pill, re-created as a Quickshell overlay so it can
// expand on hover and reveal the connected SSID — same approach as
// BrightnessPill.qml / SoundPill.qml.
//
// Geometry: sits on the transparent `custom/wifi` Waybar spacer and
// expands LEFTWARD (right edge pinned at x=1808). While it expands it
// pushes the bluetooth pill (and everything left of it) via PillBus;
// the battery pill (to the right) pushes this one in turn.
Scope {
    id: root

    readonly property color accent: "#268bd2"           // waybar #network
    readonly property color disconnectedColor: "#fb958b" // waybar #network.disconnected

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots — see changes.md §15.
    readonly property int collapsedWidth: 42
    readonly property int rightMargin: 112      // screen right edge → window right edge
    readonly property int pillHeight: 24
    readonly property int nameCap: 140          // hover text elides beyond this

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

    // Same glyphs as the old Waybar module (signal glyphs carry the
    // trailing space the Waybar format-icons entries have, so the ink
    // lands in the same spot).
    readonly property var wifiIcons: ["󰤯 ", "󰤟 ", "󰤢 ", "󰤥 ", "󰤨 "]

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

    readonly property string hoverText: root.connected ? root.connectedWifi.name
        : root.wired ? "Ethernet" : "Disconnected"

    readonly property color fg: (root.connected || root.wired) ? root.accent : root.disconnectedColor

    property bool expanded: false
    property int wbIconIdx: -1

    // ---------- waybar-exact signal strength ----------
    // The old Waybar 0.15 network module computed its icon from the
    // driver's RSSI with a "punish too-strong signals" formula:
    //   strength = 100 - |dBm + 45| / 45 * 100   (clamped to 0..100)
    // then picked icon floor(strength / 20) from the 5 format-icons.
    // Reading the same /proc value and applying the same formula keeps
    // the glyph identical to the pre-Quickshell bar; NetworkManager's
    // percentage is only the startup fallback.
    Process {
        id: signalProc
        command: ["cat", "/proc/net/wireless"]
        stdout: StdioCollector {
            onStreamFinished: {
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
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!signalProc.running)
            signalProc.running = true
    }

    readonly property real expandedWidth: root.collapsedWidth
        + (nameText.implicitWidth > 0 ? 5 + Math.min(nameText.implicitWidth, root.nameCap) : 0)

    Timer {
        id: closeTimer
        interval: 260
        onTriggered: if (!hover.hovered)
            root.expanded = false
    }

    Process {
        id: panelProc
        command: ["qs", "ipc", "call", "wifi", "toggle"]
    }

    // Publish the live expansion delta so everything to the left slides
    // out of the way in perfect sync (see PillBus.qml).
    Binding {
        target: PillBus
        property: "wifiPush"
        value: Math.max(0, pill.width - root.collapsedWidth)
    }

    Binding {
        target: PillBus
        property: "wifiMaxPush"
        value: root.expandedWidth - root.collapsedWidth
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            right: true
        }

        margins {
            top: -24
            right: root.rightMargin
        }

        implicitWidth: root.expandedWidth + PillBus.maxPushWifi
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
            // Right edge normally at 1808; the battery pill (to the
            // right) pushes this pill left while it expands.
            x: win.width - width - PillBus.pushWifi
            height: root.pillHeight
            width: root.expanded ? root.expandedWidth : root.collapsedWidth
            radius: 8
            color: "#040404"

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: panelProc.running = true
            }

            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        closeTimer.stop()
                        root.expanded = true
                    } else {
                        closeTimer.restart()
                    }
                }
            }

            Row {
                id: content
                anchors.centerIn: parent
                // Collapsed the glyph must sit where the old Waybar pill
                // had it; the gap only exists while expanded.
                spacing: root.expanded ? 5 : 0

                Behavior on spacing {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    id: glyphText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyph
                    color: root.fg
                    // The old Waybar pill's font stack lists Material
                    // Design Icons first, so its glyphs came from there.
                    font.family: "Material Design Icons"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    id: nameText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hoverText
                    color: root.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    clip: true
                    width: root.expanded ? Math.min(implicitWidth, root.nameCap) : 0
                    opacity: root.expanded ? 1 : 0

                    Behavior on width {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
