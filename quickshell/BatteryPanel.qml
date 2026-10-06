import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Battery popover, opened by clicking the battery pill (or `qs ipc call
// battery toggle`). Live charge info comes from UPower (BatteryState.qml);
// the two Low Power Mode tiers drive `~/.local/bin/power-mode` through
// passwordless sudo — tier 1 caps the CPU frequency, tier 2 additionally
// caps the whole APU's wattage via ryzenadj (see bin/power-mode).
// Same popover pattern as SoundPanel.qml: click-catcher, Escape close,
// only one panel open at a time. See changes.md §25/§26.
Scope {
    id: root

    readonly property string helper: "/home/ashim/.local/bin/power-mode"

    property bool panelOpen: true
    property bool lowPower: false
    property bool powerLimit: false

    // ---------- low power mode ----------
    // Reading state needs no privileges; flipping it does (sudo -n, the
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
        id: limitStatusProc
        command: [root.helper, "limit-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!setProc.running)
                    root.powerLimit = String(text).trim() === "on"
            }
        }
    }

    Process {
        id: setProc
        onExited: {
            if (!statusProc.running)
                statusProc.running = true
            if (!limitStatusProc.running)
                limitStatusProc.running = true
        }
    }

    function setLowPower(on) {
        root.lowPower = on            // optimistic; the refresh corrects it
        if (!on)
            root.powerLimit = false   // tier 2 stacks on tier 1
        setProc.command = ["sudo", "-n", root.helper, on ? "on" : "off"]
        setProc.running = true
    }

    function setPowerLimit(on) {
        root.powerLimit = on          // optimistic; the refresh corrects it
        if (on)
            root.lowPower = true      // tier 2 implies tier 1
        setProc.command = ["sudo", "-n", root.helper, on ? "max" : "limit-off"]
        setProc.running = true
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.panelOpen
        triggeredOnStart: true
        onTriggered: {
            if (setProc.running)
                return
            if (!statusProc.running)
                statusProc.running = true
            if (!limitStatusProc.running)
                limitStatusProc.running = true
        }
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
    // Only one popover at a time is handled by PillBus; this panel is
    // lazy-loaded (shell.qml), so closing mirrors panelOpen back to the bus.
    onPanelOpenChanged: PillBus.batteryOpen = root.panelOpen

    // IPC for this panel lives in the always-on PanelIpc.qml (this component is
    // lazy-loaded, so its own IpcHandler would vanish when closed).

    // Transparent click-catcher: closes the popover when clicking anywhere
    // outside of it. Starts below the 29px Waybar so the bar stays clickable.
    PanelWindow {
        screen: BarScreen.screen
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
        screen: BarScreen.screen
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

            // Pointer inside the panel keeps the hover preview held open;
            // tapping anywhere inside *latches* it until an outside click.
            // The shared timer / latch flag live in PillBus.qml.
            HoverHandler {
                id: panelHover
                onHoveredChanged: PillBus.pointerOnPanel = panelHover.hovered
            }

            TapHandler {
                // Observe taps without stealing them from the panel's buttons.
                grabPermissions: PointerHandler.ApprovesTakeOverByAnything
                onTapped: PillBus.panelLatched = true
            }

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

                // ---- Low Power Mode (tier 1) + Power Limit (tier 2) ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    implicitHeight: lpCol.implicitHeight + 24
                    radius: 12
                    color: Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.35)

                    ColumnLayout {
                        id: lpCol
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 12
                        }
                        spacing: 10

                        // Tier 1: CPU frequency cap.
                        RowLayout {
                            Layout.fillWidth: true
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

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // Tier 2: whole-APU power limit (ryzenadj).
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "󰊚"
                                color: root.powerLimit ? Theme.active : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: "Power Limit"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "APU capped at 6 W · ryzenadj"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            ToggleSwitch {
                                checked: root.powerLimit
                                onToggled: root.setPowerLimit(!root.powerLimit)
                            }
                        }
                    }
                }
            }
        }
    }
}
