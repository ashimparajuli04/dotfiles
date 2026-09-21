import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool panelOpen: true
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: root.adapter !== null && root.adapter !== undefined ? root.adapter.enabled : false

    readonly property var connectedDevices: root.devicesBy("connected")
    readonly property var savedDevices: root.devicesBy("saved")
    readonly property var nearbyDevices: root.devicesBy("nearby")
    readonly property bool noDevices: root.powered
        && root.connectedDevices.length === 0
        && root.savedDevices.length === 0
        && root.nearbyDevices.length === 0

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

    function devicesBy(mode) {
        var src = root.modelValues(root.adapter ? root.adapter.devices : null)
        var out = []
        for (var i = 0; i < src.length; i++) {
            var d = src[i]
            if (mode === "connected" && d.connected)
                out.push(d)
            else if (mode === "saved" && d.paired && !d.connected)
                out.push(d)
            else if (mode === "nearby" && !d.paired)
                out.push(d)
        }
        out.sort(function (a, b) {
            return (a.name || a.address || "").localeCompare(b.name || b.address || "")
        })
        return out
    }

    Timer {
        id: scanTimer
        interval: 20000
        repeat: false
        onTriggered: if (root.adapter) root.adapter.discovering = false
    }

    // Only one popover at a time is handled by PillBus; this panel is
    // lazy-loaded (shell.qml), so closing mirrors panelOpen back to the bus.
    onPanelOpenChanged: PillBus.bluetoothOpen = root.panelOpen

    // IPC for this panel lives in the always-on PanelIpc.qml (this component is
    // lazy-loaded, so its own IpcHandler would vanish when closed).

    // Transparent click-catcher: closes the popover when clicking anywhere
    // outside of it. Starts below the 29px Waybar so the bar stays clickable.
    PanelWindow {
        id: catcher
        visible: root.panelOpen

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        margins {
            top: 31
        }

        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:bt-catcher"

        MouseArea {
            anchors.fill: parent
            onClicked: root.panelOpen = false
        }
    }

    PanelWindow {
        id: panel
        visible: root.panelOpen

        anchors {
            top: true
            right: true
        }
        margins {
            top: 6   // waybar's 30px exclusive zone is applied by the compositor,
                     // so 6px here = 36px from the screen edge
            right: 6
        }

        implicitWidth: 360
        implicitHeight: frame.implicitHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:bt-panel"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: frame
            anchors.fill: parent
            focus: true
            color: Theme.bg
            radius: Theme.radius
            implicitHeight: col.implicitHeight + 28

            Keys.onEscapePressed: root.panelOpen = false

            ColumnLayout {
                id: col
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 14
                }
                spacing: 6

                // ---- Header: icon, name, power switch ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.powered ? "󰂯" : "󰂲"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Bluetooth"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.adapter ? root.adapter.name : "No adapter found"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    ToggleSwitch {
                        checked: root.powered
                        enabled: root.adapter !== null && root.adapter !== undefined
                        onToggled: root.adapter.enabled = !root.adapter.enabled
                    }
                }

                // ---- Scan button ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 34
                    visible: root.powered
                    radius: 17
                    color: scanHover.hovered ? Qt.lighter(Theme.bgAlt, 1.25) : Theme.bgAlt

                    HoverHandler {
                        id: scanHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.adapter.discovering) {
                                root.adapter.discovering = false
                                scanTimer.stop()
                            } else {
                                root.adapter.discovering = true
                                scanTimer.restart()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.adapter && root.adapter.discovering ? "󰍉  Scanning…" : "󰍉  Scan for devices"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                // ---- Connected ----
                Text {
                    Layout.topMargin: 8
                    visible: root.powered && root.connectedDevices.length > 0
                    text: "CONNECTED"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }

                Repeater {
                    model: root.powered ? root.connectedDevices : []
                    delegate: DeviceRow { device: modelData }
                }

                // ---- Saved (paired, not connected) ----
                Text {
                    Layout.topMargin: 8
                    visible: root.powered && root.savedDevices.length > 0
                    text: "SAVED"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }

                Repeater {
                    model: root.powered ? root.savedDevices : []
                    delegate: DeviceRow { device: modelData }
                }

                // ---- Nearby (discovered, unpaired) ----
                Text {
                    Layout.topMargin: 8
                    visible: root.powered && root.nearbyDevices.length > 0
                    text: "NEARBY"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }

                Repeater {
                    model: root.powered ? root.nearbyDevices : []
                    delegate: DeviceRow { device: modelData }
                }

                // ---- Empty state ----
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 4
                    visible: root.powered && root.noDevices
                    text: "No devices yet.\nPut the device in pairing mode, then hit Scan."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 4
                    visible: !root.powered
                    text: "Bluetooth is off."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
