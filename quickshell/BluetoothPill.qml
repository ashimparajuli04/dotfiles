import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Wayland

// The Waybar bluetooth pill, re-created as a Quickshell overlay so it
// can expand on hover and reveal the connected device name(s) — same
// approach as BrightnessPill.qml / SoundPill.qml.
//
// Geometry: sits on the transparent `custom/bluetooth` Waybar spacer and
// expands LEFTWARD (right edge pinned at x=1756). While it expands it
// pushes the sound and brightness pills left via PillBus; the wifi pill
// (to the right) pushes this one in turn.
Scope {
    id: root

    readonly property color accent: "#81a1c1"   // waybar #bluetooth

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots — see changes.md §15.
    readonly property int collapsedWidth: 27
    readonly property int rightMargin: 164      // screen right edge → window right edge
    readonly property int pillHeight: 24
    readonly property int nameCap: 140          // hover text elides beyond this

    // ---------- state ----------
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: root.adapter !== null
        && root.adapter !== undefined && root.adapter.enabled

    readonly property var connectedNames: {
        var out = []
        if (!root.adapter)
            return out
        var src = root.modelValues(root.adapter.devices)
        for (var i = 0; i < src.length; i++) {
            if (src[i].connected)
                out.push(src[i].name || src[i].address)
        }
        return out
    }

    readonly property string hoverText: !root.powered ? "Off"
        : root.connectedNames.length === 0 ? "No device"
        : root.connectedNames.join(", ")

    // Same glyphs as the old Waybar module: connected → 󰂱, on → 󰂯,
    // off/disabled → 󰂲.
    readonly property string glyph: !root.powered ? "󰂲"
        : root.connectedNames.length > 0 ? "󰂱" : "󰂯"

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

    property bool expanded: false

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
        command: ["qs", "ipc", "call", "bluetooth", "toggle"]
    }

    // Publish the live expansion delta so everything to the left slides
    // out of the way in perfect sync (see PillBus.qml).
    Binding {
        target: PillBus
        property: "btPush"
        value: Math.max(0, pill.width - root.collapsedWidth)
    }

    Binding {
        target: PillBus
        property: "btMaxPush"
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

        implicitWidth: root.expandedWidth + PillBus.wifiMaxPush
        implicitHeight: root.pillHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:bluetooth-pill"

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
            // Right edge normally at 1756; the wifi pill (to the right)
            // pushes this pill left while it expands.
            x: win.width - width - PillBus.wifiPush
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
                // Collapsed the glyph must sit dead-centre (like the old
                // Waybar pill), so the gap only exists while expanded.
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
                    color: root.accent
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
                    color: root.accent
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
