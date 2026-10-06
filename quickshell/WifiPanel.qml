import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool panelOpen: true
    property var pendingNetwork: null
    property string lastError: ""

    readonly property var wifiDevice: {
        var src = root.modelValues(Networking.devices)
        for (var i = 0; i < src.length; i++) {
            if (src[i].type === DeviceType.Wifi)
                return src[i]
        }
        return null
    }
    readonly property bool powered: Networking.wifiEnabled

    readonly property var connectedNetworks: root.networksBy("connected")
    readonly property var savedNetworks: root.networksBy("saved")
    readonly property var availableNetworks: root.networksBy("available")
    readonly property bool noNetworks: root.wifiDevice !== null
        && root.connectedNetworks.length === 0
        && root.savedNetworks.length === 0
        && root.availableNetworks.length === 0

    // The list grows to at most half the screen; anything longer scrolls.
    readonly property real listMaxHeight: panel.screen
        ? Math.max(160, panel.screen.height / 2)
        : 420

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

    function networksBy(mode) {
        var src = root.modelValues(root.wifiDevice ? root.wifiDevice.networks : null)
        var out = []
        for (var i = 0; i < src.length; i++) {
            var n = src[i]
            if (mode === "connected" && n.connected)
                out.push(n)
            else if (mode === "saved" && n.known && !n.connected)
                out.push(n)
            else if (mode === "available" && !n.known && !n.connected)
                out.push(n)
        }
        if (mode === "available")
            out.sort(function (a, b) { return b.signalStrength - a.signalStrength })
        else
            out.sort(function (a, b) { return (a.name || "").localeCompare(b.name || "") })
        return out
    }

    function startScan() {
        if (!root.wifiDevice)
            return
        // Quickshell only exposes nearby (unknown) networks while scanning,
        // so scanning stays enabled for as long as the popover is open.
        root.wifiDevice.scannerEnabled = true
    }

    function rescan() {
        if (!root.wifiDevice)
            return
        // Toggling off and on forces an immediate scan request (the backend
        // rate-limits it). Both assignments happen in the same frame, so the
        // network list does not visibly flicker.
        root.wifiDevice.scannerEnabled = false
        root.wifiDevice.scannerEnabled = true
    }

    function scrollListBy(delta) {
        var maxY = Math.max(0, listFlick.contentHeight - listFlick.height)
        listFlick.contentY = Math.max(0, Math.min(listFlick.contentY - delta, maxY))
    }

    function promptPassword(network) {
        root.lastError = ""
        root.pendingNetwork = network
        pwInput.text = ""
        pwInput.forceActiveFocus()
    }

    function submitPassword() {
        if (!root.pendingNetwork)
            return
        root.lastError = ""
        root.pendingNetwork.connectWithPsk(pwInput.text)
    }

    function cancelPassword() {
        root.pendingNetwork = null
        root.lastError = ""
    }

    // Right-click on an entry copies the stored password to the clipboard.
    // Deliberately silent: no toast, no color change, and failures do nothing.
    function copySavedPassword(network) {
        if (!network || !network.known || !network.name)
            return
        // The helper looks the profile up by SSID, reads the secret with
        // nmcli -s and pipes it to wl-copy via stdin (never argv).
        Quickshell.execDetached([Quickshell.shellDir + "/wifi-copy-password.sh", network.name])
    }

    // Lazy-loaded (shell.qml): "opened" side effects run at load, "closed" ones
    // at destruction; closing mirrors panelOpen back to the bus.
    onPanelOpenChanged: PillBus.wifiOpen = root.panelOpen

    Component.onCompleted: {
        root.lastError = ""
        listFlick.contentY = 0
        root.startScan()
    }

    Component.onDestruction: {
        root.pendingNetwork = null
        root.lastError = ""
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = false
    }

    // Opening this popover closes the others, in-process via PillBus
    // (no `qs ipc` subprocesses). See PillBus.qml.

    Connections {
        target: root.pendingNetwork

        function onConnectionFailed(reason) {
            root.lastError = "Connection failed: " + ConnectionFailReason.toString(reason)
            // A failed attempt still leaves its NetworkManager profile saved
            // (with the wrong password). Drop it so the next try starts clean;
            // forget() is a no-op if no profile was created.
            if (root.pendingNetwork) {
                root.pendingNetwork.forget()
                pwInput.text = ""
                pwInput.forceActiveFocus()
            }
        }

        function onConnectedChanged() {
            if (root.pendingNetwork && root.pendingNetwork.connected) {
                root.pendingNetwork = null
                root.lastError = ""
            }
        }
    }

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
        WlrLayershell.namespace: "quickshell:wifi-catcher"

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
        WlrLayershell.namespace: "quickshell:wifi-panel"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: frame
            anchors.fill: parent
            focus: true
            color: Theme.bg
            radius: Theme.radius
            implicitHeight: col.implicitHeight + 28

            Keys.onEscapePressed: {
                if (root.pendingNetwork !== null)
                    root.cancelPassword()
                else
                    root.panelOpen = false
            }

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

            // Wheel over the right gutter (next to the scrollbar) scrolls too.
            WheelHandler {
                onWheel: function (event) {
                    if (listFlick.contentHeight <= listFlick.height)
                        return
                    var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2
                    root.scrollListBy(delta)
                    event.accepted = true
                }
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

                // ---- Header: icon, name, power switch ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.powered ? "󰖩" : "󰖪"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Wi-Fi"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.wifiDevice ? root.wifiDevice.name : "No Wi-Fi device"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    ToggleSwitch {
                        checked: root.powered
                        enabled: root.wifiDevice !== null && root.wifiDevice !== undefined
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }

                // ---- Scan button ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 34
                    visible: root.powered && root.wifiDevice !== null
                    radius: 17
                    color: scanHover.hovered ? Qt.lighter(Theme.bgAlt, 1.25) : Theme.bgAlt

                    HoverHandler {
                        id: scanHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.rescan()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰍉  Scan for networks"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                // ---- Scrollable network list (half screen max) ----
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: listFlick.height

                    Flickable {
                        id: listFlick
                        width: parent.width
                        height: Math.min(listCol.implicitHeight, root.listMaxHeight)
                        contentWidth: width
                        contentHeight: listCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        onWheel: function (event) {
                            var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2
                            root.scrollListBy(delta)
                            event.accepted = true
                        }
                    }

                    ColumnLayout {
                        id: listCol
                        width: listFlick.width
                        spacing: 6

                        // ---- Connected ----
                        Text {
                            Layout.topMargin: 4
                            visible: root.powered && root.connectedNetworks.length > 0
                            text: "CONNECTED"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }

                        Repeater {
                            model: root.powered ? root.connectedNetworks : []
                            delegate: WifiRow {
                                network: modelData
                                onPasswordRequested: root.promptPassword(network)
                                onPasswordCopyRequested: root.copySavedPassword(network)
                            }
                        }

                        // ---- Saved (known, not connected) ----
                        Text {
                            Layout.topMargin: 4
                            visible: root.powered && root.savedNetworks.length > 0
                            text: "SAVED"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }

                        Repeater {
                            model: root.powered ? root.savedNetworks : []
                            delegate: WifiRow {
                                network: modelData
                                onPasswordRequested: root.promptPassword(network)
                                onPasswordCopyRequested: root.copySavedPassword(network)
                            }
                        }

                        // ---- Available (unknown) ----
                        Text {
                            Layout.topMargin: 4
                            visible: root.powered && root.availableNetworks.length > 0
                            text: "AVAILABLE"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }

                        Repeater {
                            model: root.powered ? root.availableNetworks : []
                            delegate: WifiRow {
                                network: modelData
                                onPasswordRequested: root.promptPassword(network)
                                onPasswordCopyRequested: root.copySavedPassword(network)
                            }
                        }

                        // ---- Empty state ----
                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            Layout.bottomMargin: 4
                            visible: root.powered && root.wifiDevice !== null && root.noNetworks
                            text: "No networks found.\nHit Scan to look again."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Slim scrollbar thumb (draggable; wheel scrolling is
                    // handled by the Flickable itself)
                    Rectangle {
                        id: scrollThumb

                        readonly property real maxContentY: Math.max(1, listFlick.contentHeight - listFlick.height)
                        readonly property real trackHeight: listFlick.height
                        readonly property real thumbHeight: Math.max(28, trackHeight * listFlick.height / Math.max(1, listFlick.contentHeight))
                        readonly property bool needed: listFlick.contentHeight > listFlick.height + 1

                        visible: needed
                        width: 4
                        radius: 2
                        color: thumbDrag.pressed ? Theme.accent : Theme.muted
                        opacity: thumbHover.hovered || thumbDrag.pressed ? 1.0 : 0.65
                        x: listFlick.width - width + 8
                        y: needed ? (listFlick.contentY / maxContentY) * (trackHeight - thumbHeight) : 0
                        height: thumbHeight

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        HoverHandler {
                            id: thumbHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        MouseArea {
                            id: thumbDrag

                            property real lastSceneY: 0

                            anchors.fill: parent

                            onPressed: function (mouse) {
                                lastSceneY = mouse.y + scrollThumb.y
                            }

                            onPositionChanged: function (mouse) {
                                if (!pressed)
                                    return
                                // mouse.y is relative to the moving thumb, so add
                                // thumb.y back to get a stable pointer position.
                                var sceneY = mouse.y + scrollThumb.y
                                var dy = sceneY - lastSceneY
                                lastSceneY = sceneY
                                var track = scrollThumb.trackHeight - scrollThumb.thumbHeight
                                if (track <= 0)
                                    return
                                listFlick.contentY = Math.max(0, Math.min(scrollThumb.maxContentY,
                                    listFlick.contentY + dy * (scrollThumb.maxContentY / track)))
                            }
                        }
                    }
                }

                // ---- Password prompt for secured, unsaved networks ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: pwCol.implicitHeight + 20
                    visible: root.pendingNetwork !== null
                    radius: 12
                    color: Theme.bgAlt

                    onVisibleChanged: if (visible) pwInput.forceActiveFocus()

                    ColumnLayout {
                        id: pwCol
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 10
                        }
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: "Password for " + (root.pendingNetwork ? root.pendingNetwork.name : "")
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 8
                                color: Theme.bg
                                border.width: 1
                                border.color: pwInput.activeFocus ? Theme.accent : Theme.bgAlt

                                TextInput {
                                    id: pwInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    passwordCharacter: "•"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    selectByMouse: true
                                    clip: true

                                    Keys.onReturnPressed: root.submitPassword()
                                    Keys.onEnterPressed: root.submitPassword()
                                    Keys.onEscapePressed: root.cancelPassword()
                                }
                            }

                            Rectangle {
                                implicitWidth: 76
                                implicitHeight: 30
                                radius: 8
                                color: pwConnectHover.hovered ? Qt.lighter(Theme.accent, 1.15) : Theme.accent

                                HoverHandler {
                                    id: pwConnectHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.submitPassword()
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Connect"
                                    color: "#FFFFFF"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.lastError !== ""
                            text: root.lastError
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 4
                    visible: !root.powered
                    text: "Wi-Fi is off."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
