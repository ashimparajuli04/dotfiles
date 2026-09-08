import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool panelOpen: false
    property int currentTab: 0

    readonly property var tabModel: [
        { label: "Output", glyph: "󰓃" },
        { label: "Input", glyph: "󰍬" },
        { label: "Playback", glyph: "󰝚" }
    ]

    readonly property bool pwReady: Pipewire.ready
    readonly property var outputs: root.deviceNodes(PwNodeType.AudioSink)
    readonly property var inputs: root.deviceNodes(PwNodeType.AudioSource)
    readonly property var streams: root.streamNodes(PwNodeType.AudioOutStream)

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property int defaultSinkId: (root.defaultSink !== null && root.defaultSink !== undefined)
        ? root.defaultSink.id : -1

    readonly property var defaultSource: Pipewire.defaultAudioSource
    readonly property int defaultSourceId: (root.defaultSource !== null && root.defaultSource !== undefined)
        ? root.defaultSource.id : -1

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

    function appName(n) {
        if (!n || !n.properties)
            return ""
        return n.properties["application.name"] || n.description || n.name || ""
    }

    // Audio device endpoints. The PwNodeType flag values are composite
    // (AudioSink = Audio|Sink), so check for the full flag and exclude streams.
    function deviceNodes(flag) {
        var src = root.modelValues(Pipewire.nodes)
        var out = []
        for (var i = 0; i < src.length; i++) {
            var n = src[i]
            if (n && !n.isStream && (n.type & flag) === flag)
                out.push(n)
        }
        var def = (flag === PwNodeType.AudioSink) ? root.defaultSink : root.defaultSource
        out.sort(function (a, b) {
            if (def) {
                if (a.id === def.id)
                    return -1
                if (b.id === def.id)
                    return 1
            }
            return (a.description || a.name || "").localeCompare(b.description || b.name || "")
        })
        return out
    }

    function streamNodes(flag) {
        var src = root.modelValues(Pipewire.nodes)
        var out = []
        for (var i = 0; i < src.length; i++) {
            var n = src[i]
            if (n && (n.type & flag) === flag)
                out.push(n)
        }
        out.sort(function (a, b) {
            return root.appName(a).localeCompare(root.appName(b))
        })
        return out
    }

    // Keep live bindings on every node we display so volume/mute/route
    // changes are pushed to us (nodes not tracked may be unbound).
    readonly property var tracked: {
        var out = []
        out = out.concat(root.outputs, root.inputs, root.streams)
        return out
    }

    PwObjectTracker {
        objects: root.tracked
    }

    function scrollListBy(delta) {
        var maxY = Math.max(0, listFlick.contentHeight - listFlick.height)
        listFlick.contentY = Math.max(0, Math.min(listFlick.contentY - delta, maxY))
    }

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
        id: hidePowermenu
        command: ["qs", "ipc", "call", "powermenu", "hide"]
    }

    function hideOthers() {
        hideBluetooth.running = true
        hideWifi.running = true
        hidePowermenu.running = true
    }

    function moveStream(stream, sink) {
        if (!stream || !sink || moveProc.running)
            return
        var serial = stream.properties ? stream.properties["object.serial"] : undefined
        if (serial === undefined || serial === null || serial === "")
            return
        moveProc.command = ["pactl", "move-sink-input", "" + serial, "" + sink.name]
        moveProc.running = true
    }

    Process {
        id: moveProc
    }

    onPanelOpenChanged: {
        if (root.panelOpen)
            listFlick.contentY = 0
    }

    onCurrentTabChanged: {
        if (typeof listFlick !== "undefined")
            listFlick.contentY = 0
    }

    IpcHandler {
        target: "sound"
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
        WlrLayershell.namespace: "quickshell:sound-catcher"

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

        implicitWidth: 400
        implicitHeight: frame.implicitHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:sound-panel"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: frame
            anchors.fill: parent
            focus: true
            color: Theme.bg
            radius: Theme.radius
            implicitHeight: col.implicitHeight + 28

            Keys.onEscapePressed: root.panelOpen = false

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

                // ---- Header: icon, name, master mute ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: (root.defaultSink && root.defaultSink.audio && root.defaultSink.audio.muted)
                            ? "󰖁" : "󰕾"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Sound"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.defaultSink
                                ? (root.defaultSink.description || root.defaultSink.name)
                                : (root.pwReady ? "No output device" : "PipeWire unavailable")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    ToggleSwitch {
                        checked: (root.defaultSink && root.defaultSink.audio)
                            ? root.defaultSink.audio.muted : false
                        enabled: root.defaultSink !== null && root.defaultSink !== undefined
                        onToggled: {
                            if (root.defaultSink && root.defaultSink.audio)
                                root.defaultSink.audio.muted = !root.defaultSink.audio.muted
                        }
                    }
                }

                // ---- Tabs: Output / Input / Playback ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 34
                    radius: 17
                    color: Theme.bgAlt

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 3

                        Repeater {
                            model: root.tabModel
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 14
                                color: root.currentTab === index
                                    ? Theme.accent
                                    : (tabHover.hovered ? Qt.lighter(Theme.bgAlt, 1.3) : "transparent")

                                HoverHandler {
                                    id: tabHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.currentTab = index
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.glyph + "  " + modelData.label
                                    color: root.currentTab === index ? "#FFFFFF" : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                // ---- Scrollable tab content (half screen max) ----
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: listFlick.height

                    Flickable {
                        id: listFlick
                        width: parent.width
                        height: Math.min(contentCol.implicitHeight, root.listMaxHeight)
                        contentWidth: width
                        contentHeight: contentCol.implicitHeight
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
                            id: contentCol
                            width: listFlick.width
                            spacing: 6

                            // ---- Output devices ----
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: root.currentTab === 0

                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 6
                                    Layout.bottomMargin: 4
                                    visible: root.pwReady && root.outputs.length === 0
                                    text: "No output devices"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Repeater {
                                    model: root.outputs
                                    delegate: AudioRow {
                                        node: modelData
                                        isDefault: root.defaultSinkId === modelData.id
                                    }
                                }
                            }

                            // ---- Input devices ----
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: root.currentTab === 1

                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 6
                                    Layout.bottomMargin: 4
                                    visible: root.pwReady && root.inputs.length === 0
                                    text: "No input devices"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Repeater {
                                    model: root.inputs
                                    delegate: AudioRow {
                                        node: modelData
                                        isInput: true
                                        isDefault: root.defaultSourceId === modelData.id
                                    }
                                }
                            }

                            // ---- Application playback ----
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: root.currentTab === 2

                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 6
                                    Layout.bottomMargin: 4
                                    visible: root.pwReady && root.streams.length === 0
                                    text: "Nothing is playing"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Repeater {
                                    model: root.streams
                                    delegate: AudioRow {
                                        node: modelData
                                        isStream: true
                                        sinks: root.outputs
                                        onMoveRequested: function (sink) {
                                            root.moveStream(modelData, sink)
                                        }
                                    }
                                }
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

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 4
                    visible: !root.pwReady
                    text: "PipeWire is not available."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
