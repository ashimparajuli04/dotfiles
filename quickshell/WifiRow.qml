import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

Rectangle {
    id: row

    property var network
    signal passwordRequested()
    signal passwordCopyRequested()

    readonly property bool busy: row.network.stateChanging
        || row.network.state === ConnectionState.Connecting
        || row.network.state === ConnectionState.Disconnecting

    // Open and OWE networks need no password; known ones have one stored.
    readonly property bool secure: row.network.security !== WifiSecurityType.Open
        && row.network.security !== WifiSecurityType.Owe
    readonly property bool needsPassword: row.secure && !row.network.known

    implicitHeight: 42
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
            if (row.network.connected)
                row.network.disconnect()
            else if (row.needsPassword)
                row.passwordRequested()
            else
                row.network.connect()
        }
    }

    // Right-click copies the saved password (silently — no visual feedback).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: row.passwordCopyRequested()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: iconFor(row.network.signalStrength)
            color: row.network.connected ? Theme.accent : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }

        Text {
            visible: row.secure
            text: "󰌾"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: row.network.name || "(hidden)"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                visible: row.busy
                text: row.network.state === ConnectionState.Disconnecting ? "Disconnecting…" : "Connecting…"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        Text {
            visible: row.network.known && !row.busy
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
                onClicked: row.network.forget()
            }
        }

        Text {
            visible: !row.busy
            text: row.network.connected ? "Disconnect" : "Connect"
            color: row.network.connected ? Theme.muted : Theme.active
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    function iconFor(strength) {
        if (strength >= 0.75)
            return "󰤨"
        if (strength >= 0.5)
            return "󰤥"
        if (strength >= 0.25)
            return "󰤢"
        if (strength >= 0.05)
            return "󰤟"
        return "󰤯"
    }
}
