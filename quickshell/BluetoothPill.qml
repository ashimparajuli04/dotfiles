import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Wayland

// The Waybar bluetooth pill, re-created as a Quickshell overlay. Hovering it
// opens BluetoothPanel as a preview (held while the pointer is on the pill or
// the panel, closed 1s after leaving both); clicking it opens/latches the
// panel until an outside click. See PillBus.qml for the shared preview logic.
//
// Geometry: sits on the transparent `custom/bluetooth` Waybar spacer (right
// edge at x=1822, flush against the wifi pill; joined row). It no longer
// expands; the wifi/battery pills (to the right) still push it left via
// PillBus.
Scope {
    id: root

    readonly property color accent: "#81a1c1"   // waybar #bluetooth

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots — see changes.md §15/§25.
    // Joined row (§32): rightMargin 98 = 71 (wifi) + 27 (wifi width), so
    // this pill's right edge sits flush against the wifi pill.
    readonly property int collapsedWidth: 27
    readonly property int rightMargin: 89       // screen right edge → window right edge
    readonly property int pillHeight: 24

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

    // Publish "pointer is on the pill" so PillBus can hold the preview panel
    // open while the pointer is either on the pill or on the panel.
    Binding {
        target: PillBus
        property: "hoverBt"
        value: hover.hovered
    }

    // Hover opens the panel as a preview; a click opens it latched. Shared
    // close timer / latch state live in PillBus.qml.
    function openPreview() {
        if (!PillBus.bluetoothOpen) {
            PillBus.show("bluetooth")
            PillBus.panelLatched = false
        }
    }

    function toggle() {
        if (PillBus.bluetoothOpen) {
            if (PillBus.panelLatched)
                PillBus.close("bluetooth")
            else
                PillBus.panelLatched = true
        } else {
            PillBus.show("bluetooth")
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

        implicitWidth: root.collapsedWidth + PillBus.maxPushBt
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
            // Right edge normally at 1814, flush against the wifi pill;
            // the wifi/battery pills (to the right) push this pill left
            // while they expand.
            x: win.width - width - PillBus.pushBt
            height: root.pillHeight
            // Icon-only now (no hover expansion); the wifi/battery pills still
            // push it left while they expand.
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
                // Report the pointer to PillBus instead of opening on the first
                // pixel of hover; the preview opens only after a short rest, so
                // an accidental slide across the row passes through (see
                // PillBus.requestPreview / hoverOpenDelay).
                onHoveredChanged: {
                    if (hovered)
                        PillBus.requestPreview("bluetooth")
                    else
                        PillBus.cancelPreview("bluetooth")
                }
            }

            // Fires once the pointer has rested here long enough.
            Connections {
                target: PillBus
                function onPreviewTickChanged() {
                    if (PillBus.previewName === "bluetooth" && hover.hovered)
                        root.openPreview()
                }
            }

            Text {
                id: glyphText
                anchors.centerIn: parent
                text: root.glyph
                color: root.accent
                // The old Waybar pill's font stack lists Material
                // Design Icons first, so its glyphs came from there.
                font.family: "Material Design Icons"
                font.pixelSize: 13
                font.bold: true
            }
        }
    }
}
