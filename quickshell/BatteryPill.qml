import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The Waybar battery pill, re-created as a Quickshell overlay. Hovering it
// opens BatteryPanel as a preview (held while the pointer is on the pill or
// the panel, closed 1s after leaving both); clicking it opens/latches the
// panel until an outside click. See PillBus.qml for the shared preview logic.
// It no longer expands on hover; it only expands of its own accord for the
// alert words / ≤50 % percentage (BatteryAlert.forceExpand).
//
// Geometry: sits on the transparent `custom/battery` Waybar spacer (right edge
// pinned at x=1876). The row is joined flush now (changes.md §32): this pill
// abuts the wifi pill on the left and the powermenu continues on the right.
// While it expands (alerts) it pushes the wifi pill (and everything left of
// it) via PillBus. See changes.md §22.
Scope {
    id: root

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots — see changes.md §25.
    // Snug icon-only pill (same size as the bluetooth pill). The right edge
    // reaches x=1876; the left edge (1849) abuts the wifi pill: joined row,
    // changes.md §32. rightMargin is 7px more than the old flush value so the
    // battery→powermenu icon gap matches the row's even 27px spacing.
    readonly property int collapsedWidth: 27
    readonly property int rightMargin: 35       // screen right edge → window right edge
    readonly property int pillHeight: 24
    readonly property int pctCap: 60            // hover text elides beyond this
    readonly property int labelCap: 130         // alert-word text elides beyond this

    // ---------- state ----------
    // All battery values live in BatteryState.qml (UPower-backed); the alert
    // words and the ≤50 % "keep the percentage up" rule live in BatteryAlert.qml.
    // The pill expands only for alerts now — hover opens the panel instead.
    readonly property bool expanded: BatteryAlert.forceExpand

    // Rounded to whole pixels so the pushed (collapsed) pills shift by an
    // exact integer and the joined row never shows a sub-pixel seam.
    readonly property int expandedWidth: Math.round(root.collapsedWidth
        + (pctText.implicitWidth > 0 ? 5 + Math.min(pctText.implicitWidth, root.pctCap) : 0)
        + (labelText.text !== "" ? 5 + Math.min(labelText.implicitWidth, root.labelCap) : 0))

    // Publish "pointer is on the pill" so PillBus can hold the preview panel
    // open while the pointer is on the pill or the panel (and so it keeps
    // other expanded pills from collapsing under the cursor).
    Binding {
        target: PillBus
        property: "hoverBattery"
        value: hover.hovered
    }

    // Hover opens the panel as a preview; a click opens it latched. The shared
    // close timer / latch flag live in PillBus.qml so the four preview popovers
    // never fight over which one is open. Panel toggling is in-process via
    // PillBus (no `qs ipc` subprocess).
    function openPreview() {
        if (!PillBus.batteryOpen) {
            PillBus.show("battery")
            PillBus.panelLatched = false
        }
    }

    function toggle() {
        if (PillBus.batteryOpen) {
            if (PillBus.panelLatched)
                PillBus.close("battery")
            else
                PillBus.panelLatched = true
        } else {
            PillBus.show("battery")
            PillBus.panelLatched = true
        }
    }

    // Publish the live expansion delta so the wifi pill (and everything
    // left of it) slides out of the way in perfect sync (see PillBus.qml).
    Binding {
        target: PillBus
        property: "batteryPush"
        value: Math.max(0, Math.round(pill.width - root.collapsedWidth))
    }

    Binding {
        target: PillBus
        property: "batteryMaxPush"
        // Ceiling = a full percentage text plus a full alert word (a pop can
        // stack on top of the ≤50 % percentage). Every pill to the left
        // reserves this much so the joined row never clips while the battery
        // pill reaches its widest.
        value: (5 + root.pctCap) + (5 + root.labelCap)
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
            // Joined row (changes.md §32): square corners on both sides —
            // the wifi pill abuts on the left, the powermenu continues to
            // the right.
            radius: 0
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
                        PillBus.requestPreview("battery")
                    else
                        PillBus.cancelPreview("battery")
                }
            }

            // Fires once the pointer has rested here long enough.
            Connections {
                target: PillBus
                function onPreviewTickChanged() {
                    if (PillBus.previewName === "battery" && hover.hovered)
                        root.openPreview()
                }
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

                // The alert word (Charging / On battery / Fully charged! /
                // Running low / Critical / Final moments) from BatteryAlert.
                // Empty unless a pop is live, so it reserves no width at rest.
                Text {
                    id: labelText
                    anchors.verticalCenter: parent.verticalCenter
                    text: BatteryAlert.label
                    color: BatteryState.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    clip: true
                    width: (root.expanded && text !== "") ? Math.min(implicitWidth, root.labelCap) : 0
                    opacity: (root.expanded && text !== "") ? 1 : 0

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
