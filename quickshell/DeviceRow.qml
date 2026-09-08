import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Rectangle {
    id: row

    property var device
    property bool pairBusy: false
    property string pairError: ""

    readonly property bool busy: row.pairBusy
        || row.device.pairing
        || row.device.state === BluetoothDeviceState.Connecting
        || row.device.state === BluetoothDeviceState.Disconnecting

    // Quickshell has no BlueZ pairing agent, so device.pair() fails with
    // "no agent available" on most devices. bluetoothctl registers an agent
    // while it runs, so pair through it, then trust + connect on success.
    Process {
        id: pairProc
        command: ["timeout", "45", "bluetoothctl", "pair", row.device.address]
        running: false
        onExited: function (exitCode) {
            row.pairBusy = false
            if (row.device.paired || exitCode === 0) {
                row.pairError = ""
                row.device.trusted = true
                row.device.connect()
            } else {
                row.pairError = "Pairing failed — put the device in pairing mode and try again"
            }
        }
    }

    implicitHeight: row.pairError !== "" ? 56 : 42
    radius: 12
    color: hover.hovered ? Theme.bgAlt : "transparent"
    Layout.fillWidth: true

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (row.pairBusy)
                return
            if (row.device.connected) {
                row.device.disconnect()
            } else if (row.device.paired) {
                row.device.connect()
            } else {
                row.pairError = ""
                row.pairBusy = true
                pairProc.running = true
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: iconFor(row.device.icon)
            color: row.device.connected ? Theme.accent : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: row.device.name || row.device.address
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                visible: row.busy
                text: (row.pairBusy || row.device.pairing) ? "Pairing…"
                    : (row.device.state === BluetoothDeviceState.Connecting ? "Connecting…" : "Disconnecting…")
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Text {
                Layout.fillWidth: true
                visible: row.pairError !== ""
                text: row.pairError
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Text {
            visible: row.device.batteryAvailable
            text: "󰁹 " + Math.round(row.device.battery * 100) + "%"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Text {
            visible: row.device.paired || row.device.trusted
            text: "Forget"
            color: forgetHover.hovered ? Theme.fg : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11

            HoverHandler {
                id: forgetHover
                cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                onClicked: row.device.forget()
            }
        }

        Text {
            text: row.device.connected ? "Disconnect" : (row.device.paired ? "Connect" : "Pair")
            color: row.device.connected ? Theme.muted : Theme.active
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    function iconFor(name) {
        if (!name)
            return "󰂯"
        if (name.indexOf("headset") !== -1 || name.indexOf("headphone") !== -1 || name.indexOf("audio") !== -1)
            return "󰋋"
        if (name.indexOf("mouse") !== -1)
            return "󰍽"
        if (name.indexOf("keyboard") !== -1)
            return "󰌌"
        if (name.indexOf("phone") !== -1)
            return "󰏲"
        return "󰂯"
    }
}
