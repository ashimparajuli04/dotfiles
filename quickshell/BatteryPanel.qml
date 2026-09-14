import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Battery popover, opened by clicking the battery pill (or `qs ipc call
// battery toggle`). Live charge info comes from UPower (BatteryState.qml);
// the Low Power Mode switch drives `~/.local/bin/power-mode` through
// passwordless sudo (boost off + 1.4 GHz cap — see bin/power-mode).
// Same popover pattern as SoundPanel.qml: click-catcher, Escape close,
// only one panel open at a time. See changes.md §22.
Scope {
    id: root

    readonly property string helper: "/home/ashim/.local/bin/power-mode"

    property bool panelOpen: false
    property bool lowPower: false

    // ---------- low power mode ----------
    // Reading sysfs needs no privileges; flipping it does (sudo -n, the
    // machine already has passwordless sudo — setup.sh also drops a
    // scoped sudoers rule so this works on a fresh machine).
    Process {
        id: statusProc
        command: [root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Ignore stale reads that race an in-flight toggle.
                if (!setProc.running)
                    root.lowPower = String(text).trim() === "on"
            }
        }
    }

    Process {
        id: setProc
        onExited: if (!statusProc.running)
            statusProc.running = true
    }

    function setLowPower(on) {
        root.lowPower = on            // optimistic; the refresh corrects it
        setProc.command = ["sudo", "-n", root.helper, on ? "on" : "off"]
        setProc.running = true
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.panelOpen
        triggeredOnStart: true
        onTriggered: if (!setProc.running && !statusProc.running)
            statusProc.running = true
    }

    // ---------- live values ----------
    function hhmm(seconds) {
        if (!seconds || seconds <= 0 || !isFinite(seconds))
            return ""
        var m = Math.round(seconds / 60)
        var h = Math.floor(m / 60)
        m = m % 60
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    readonly property string stateLine: {
        if (!BatteryState.ready)
            return "No battery detected"
        if (BatteryState.charging) {
            var tf = root.hhmm(BatteryState.bat.timeToFull)
            return tf !== "" ? "Charging · " + tf + " to full" : "Charging"
        }
        if (BatteryState.full || BatteryState.plugged)
            return "Plugged in"
        var te = root.hhmm(BatteryState.bat.timeToEmpty)
        return te !== "" ? "Discharging · " + te + " left" : "Discharging"
    }

    readonly property var infoRows: {
        var rows = []
        if (!BatteryState.ready)
            return rows
        rows.push({ label: "Status", value: BatteryState.stateText })
        if (BatteryState.charging) {
            var tf = root.hhmm(BatteryState.bat.timeToFull)
            if (tf !== "")
                rows.push({ label: "Time to full", value: tf })
        } else {
            var te = root.hhmm(BatteryState.bat.timeToEmpty)
            if (te !== "")
                rows.push({ label: "Time left", value: te })
        }
        var rate = Math.abs(BatteryState.bat.changeRate)
        if (rate && isFinite(rate) && rate > 0.01)
            rows.push({
                label: BatteryState.charging ? "Charge rate" : "Power draw",
                value: rate.toFixed(1) + " W"
            })
        if (BatteryState.healthSupported) {
            var v = Math.round(BatteryState.healthPercentage) + "%"
            var cap = BatteryState.energyCapacity
            if (cap && isFinite(cap) && cap > 0.01)
                v += " · " + cap.toFixed(1) + " Wh"
            rows.push({ label: "Health", value: v })
        }
        return rows
    }

    // ---------- popover plumbing ----------
    // Only one popover at a time: opening this one closes the others.
    Process {
        id: hideBluetooth
        command: ["qs", "ipc", "call", "bluetooth", "hide"]
    }

    Process {
        id: hideWifi
        command: ["qs", "ipc", "call", "wifi", "hide"]
    }

    Process {
        id: hideSound
        command: ["qs", "ipc", "call", "sound", "hide"]
    }

    Process {
        id: hidePowermenu
        command: ["qs", "ipc", "call", "powermenu", "hide"]
    }

    Process {
        id: hideMusic
        command: ["qs", "ipc", "call", "music", "hide"]
    }

    function hideOthers() {
        hideBluetooth.running = true
        hideWifi.running = true
        hideSound.running = true
        hidePowermenu.running = true
        hideMusic.running = true
    }

    IpcHandler {
        target: "battery"
        function toggle() {
            root.hideOthers()
            root.panelOpen = !root.panelOpen
        }
        function show() {
            root.panelOpen = true
            root.hideOthers()
        }
        function hide() { root.panelOpen = false }
    }

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
        WlrLayershell.namespace: "quickshell:battery-catcher"

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
            top: 6
            right: 6
        }

        implicitWidth: 360
        implicitHeight: frame.implicitHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:battery-panel"
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

                // ---- Header: glyph, name/state, percentage ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: BatteryState.glyph
                        color: BatteryState.fg
                        font.family: "Material Design Icons"
                        font.pixelSize: 22
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Battery"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.stateLine
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: BatteryState.ready ? BatteryState.percent + "%" : "--"
                        color: BatteryState.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                    }
                }

                // ---- Info rows: status / time / draw / health ----
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 4

                    Repeater {
                        model: root.infoRows
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: modelData.label
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: modelData.value
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }

                // ---- Low Power Mode ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    implicitHeight: 52
                    radius: 12
                    color: Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.35)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: "󰉁"
                            color: root.lowPower ? Theme.active : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: "Low Power Mode"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "CPU capped at 1.4 GHz, boost off"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        ToggleSwitch {
                            checked: root.lowPower
                            onToggled: root.setLowPower(!root.lowPower)
                        }
                    }
                }
            }
        }
    }
}
