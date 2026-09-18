import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The Waybar battery pill, re-created as a Quickshell overlay so it can
// expand on hover and reveal the charge percentage — same approach as
// WifiPill.qml / SoundPill.qml.
//
// Geometry: sits on the transparent `custom/battery` Waybar spacer and
// expands LEFTWARD (right edge pinned at x=1877). The battery is the
// rightmost Quickshell pill, so while it expands it pushes the wifi pill
// (and everything left of it) via PillBus. See changes.md §22.
Scope {
    id: root

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots — see changes.md §25.
    // Snug icon-only pill (same size as the bluetooth pill). The right edge
    // reaches x=1883 — 6 px into the powermenu's black padding, up to the
    // 💢 ink — so the icon sits centred between the wifi gap and the emoji
    // instead of hugging the left side.
    readonly property int collapsedWidth: 27
    readonly property int rightMargin: 37       // screen right edge → window right edge
    readonly property int pillHeight: 24
    readonly property int pctCap: 60            // hover text elides beyond this

    // ---------- state ----------
    // All battery values live in BatteryState.qml (UPower-backed).
    property bool expanded: false

    readonly property real expandedWidth: root.collapsedWidth
        + (pctText.implicitWidth > 0 ? 5 + Math.min(pctText.implicitWidth, root.pctCap) : 0)

    // Hover only expands the pill; collapsing is driven by
    // PillBus.collapseTick and only happens after the whole pill row has
    // been unhovered. Switching quickly to/from a neighbour therefore
    // never collapses this one and never slides the row under the
    // cursor — see PillBus.qml.
    Binding {
        target: PillBus
        property: "hoverBattery"
        value: hover.hovered
    }

    Connections {
        target: PillBus
        function onCollapseTickChanged() {
            if (!hover.hovered)
                root.expanded = false
        }
    }

    Process {
        id: panelProc
        command: ["qs", "ipc", "call", "battery", "toggle"]
    }

    // Publish the live expansion delta so the wifi pill (and everything
    // left of it) slides out of the way in perfect sync (see PillBus.qml).
    Binding {
        target: PillBus
        property: "batteryPush"
        value: Math.max(0, pill.width - root.collapsedWidth)
    }

    Binding {
        target: PillBus
        property: "batteryMaxPush"
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

        implicitWidth: root.expandedWidth
        implicitHeight: root.pillHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:battery-pill"

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
            anchors.right: parent.right
            height: root.pillHeight
            width: root.expanded ? root.expandedWidth : root.collapsedWidth
            radius: 8
            // The old Waybar module was `border-radius: 8px 0 0 8px`:
            // square right corners where the powermenu sat against it.
            topRightRadius: 0
            bottomRightRadius: 0
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
                onHoveredChanged: if (hovered)
                    root.expanded = true
            }

            Row {
                id: content
                anchors.centerIn: parent
                // Collapsed the pill shows the icon only; the gap (and the
                // percentage) only exist while expanded.
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
                    text: BatteryState.glyph
                    color: BatteryState.fg
                    // The old Waybar pill's font stack lists Material
                    // Design Icons first, so its glyphs came from there.
                    font.family: "Material Design Icons"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    id: pctText
                    anchors.verticalCenter: parent.verticalCenter
                    text: BatteryState.ready ? BatteryState.percent + "%" : ""
                    color: BatteryState.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    clip: true
                    width: root.expanded ? Math.min(implicitWidth, root.pctCap) : 0
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
