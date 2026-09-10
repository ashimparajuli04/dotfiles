import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Library + queue browser for the music widget, opened by clicking the
// widget's cover art (IPC target "music" is also available for keybinds).
// Styled to match the widget / the old eww look.
Scope {
    id: root

    property bool panelOpen: false
    property int tab: 0               // 0 = library, 1 = queue
    property string filter: ""

    readonly property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenW: root.targetScreen ? root.targetScreen.width : 1920
    readonly property real screenH: root.targetScreen ? root.targetScreen.height : 1080
    readonly property real maxListHeight: Math.round(root.screenH * 0.5)

    readonly property var filteredLibrary: {
        if (root.filter === "")
            return MusicState.libraryFiles
        var f = root.filter.toLowerCase()
        return MusicState.libraryFiles.filter(function (p) {
            return p.toLowerCase().indexOf(f) !== -1
        })
    }

    function displayName(p) {
        return p.replace(/\.[^.\/]+$/, "")
    }

    function open(t) {
        root.tab = t
        root.panelOpen = true
        MusicState.refreshLibrary()
        MusicState.refreshQueue()
        hideBluetooth.running = true
        hideSound.running = true
        hideWifi.running = true
        hidePowermenu.running = true
    }

    Process {
        id: hideBluetooth
        command: ["qs", "ipc", "call", "bluetooth", "hide"]
    }

    Process {
        id: hideSound
        command: ["qs", "ipc", "call", "sound", "hide"]
    }

    Process {
        id: hideWifi
        command: ["qs", "ipc", "call", "wifi", "hide"]
    }

    Process {
        id: hidePowermenu
        command: ["qs", "ipc", "call", "powermenu", "hide"]
    }

    IpcHandler {
        target: "music"
        function toggle() {
            if (root.panelOpen)
                root.panelOpen = false
            else
                root.open(root.tab)
        }
        function show() { root.open(root.tab) }
        function hide() { root.panelOpen = false }
        function library() { root.open(0) }
        function queue() { root.open(1) }
    }

    onPanelOpenChanged: {
        if (root.panelOpen) {
            root.filter = ""
            searchInput.forceActiveFocus()
        }
    }

    // Transparent click-catcher below the Waybar.
    PanelWindow {
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
        WlrLayershell.namespace: "quickshell:music-catcher"

        MouseArea {
            anchors.fill: parent
            onClicked: root.panelOpen = false
        }
    }

    // Panel sits directly above the widget.
    PanelWindow {
        id: panel
        screen: root.targetScreen
        visible: root.panelOpen

        anchors {
            left: true
            bottom: true
        }
        margins {
            left: Math.round(root.screenW * 0.02)
            bottom: Math.round(root.screenH * 0.03) + Math.round(root.screenH * 0.20) + 6
        }

        implicitWidth: 384
        implicitHeight: Math.min(frame.implicitHeight, Math.round(root.screenH * 0.62))
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:music-panel"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: frame
            anchors.fill: parent
            focus: true
            color: MusicStyle.bg
            implicitHeight: col.implicitHeight + 24

            Keys.onEscapePressed: root.panelOpen = false

            ColumnLayout {
                id: col
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 12
                }
                spacing: 8

                // ---- tabs + actions ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [{ label: "LIBRARY", idx: 0 }, { label: "QUEUE", idx: 1 }]

                        delegate: Rectangle {
                            required property var modelData

                            implicitWidth: 68
                            implicitHeight: 24
                            color: root.tab === modelData.idx ? MusicStyle.fg : "transparent"
                            border.width: 2
                            border.color: MusicStyle.border

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.tab === modelData.idx ? MusicStyle.bg : MusicStyle.fg
                                font.family: MusicStyle.fontFamily
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tab = modelData.idx
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MusicButton {
                        // md-shuffle U+F049D
                        glyph: "\udb81\udc9d"
                        visible: root.tab === 0
                        onClicked: MusicState.shuffleAll()
                    }

                    MusicButton {
                        // md-close U+F0156
                        glyph: "\udb80\udd56"
                        onClicked: root.panelOpen = false
                    }
                }

                // ---- search ----
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    color: "transparent"
                    border.width: 2
                    border.color: MusicStyle.border
                    visible: root.tab === 0

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: MusicStyle.fg
                        font.family: MusicStyle.fontFamily
                        font.pixelSize: 11
                        selectByMouse: true
                        clip: true

                        onTextChanged: root.filter = text

                        Keys.onDownPressed: libraryList.forceActiveFocus()
                        Keys.onEscapePressed: root.panelOpen = false

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "search…"
                            visible: searchInput.text === ""
                            color: Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.45)
                            font.family: MusicStyle.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                // ---- list ----
                Item {
                    id: listHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: {
                        var h = root.tab === 0 ? libraryList.contentHeight : queueList.contentHeight
                        return Math.min(Math.max(h, 40), root.maxListHeight)
                    }

                    ListView {
                        id: libraryList
                        anchors.fill: parent
                        visible: root.tab === 0
                        model: root.filteredLibrary
                        clip: true
                        spacing: 1

                        Keys.onReturnPressed: root.playCurrentLibrary()
                        Keys.onEnterPressed: root.playCurrentLibrary()

                        delegate: Rectangle {
                            id: libRow

                            required property string modelData
                            required property int index

                            width: libraryList.width
                            height: 22
                            color: hover.hovered ? Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.12) : "transparent"

                            HoverHandler {
                                id: hover
                                cursorShape: Qt.PointingHandCursor
                            }

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                verticalAlignment: Text.AlignVCenter
                                text: root.displayName(libRow.modelData)
                                color: MusicStyle.fg
                                font.family: MusicStyle.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.MiddleButton)
                                        MusicState.queueFile(libRow.modelData)
                                    else
                                        MusicState.playFile(libRow.modelData)
                                }
                            }
                        }
                    }

                    ListView {
                        id: queueList
                        anchors.fill: parent
                        visible: root.tab === 1
                        model: MusicState.queueFiles
                        clip: true
                        spacing: 1

                        onVisibleChanged: if (visible && MusicState.songPos > 0)
                            positionViewAtIndex(MusicState.songPos - 1, ListView.Center)

                        Keys.onReturnPressed: root.playCurrentQueue()
                        Keys.onEnterPressed: root.playCurrentQueue()

                        delegate: Rectangle {
                            id: queueRow

                            required property string modelData
                            required property int index

                            readonly property bool isCurrent: MusicState.songPos - 1 === index

                            width: queueList.width
                            height: 22
                            color: isCurrent ? MusicStyle.fg
                                : (hover.hovered ? Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.12) : "transparent")

                            HoverHandler {
                                id: hover
                                cursorShape: Qt.PointingHandCursor
                            }

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                verticalAlignment: Text.AlignVCenter
                                text: (queueRow.index + 1) + "  " + root.displayName(queueRow.modelData)
                                color: queueRow.isCurrent ? MusicStyle.bg : MusicStyle.fg
                                font.family: MusicStyle.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.RightButton)
                                        MusicState.removeQueueIndex(queueRow.index)
                                    else
                                        MusicState.playQueueIndex(queueRow.index)
                                }
                            }
                        }
                    }

                    // empty states
                    Text {
                        anchors.centerIn: parent
                        visible: root.tab === 0 && root.filteredLibrary.length === 0
                        text: MusicState.libraryLoaded ? "No matches" : "Loading…"
                        color: Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.6)
                        font.family: MusicStyle.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.tab === 1 && MusicState.queueFiles.length === 0
                        text: "Queue is empty"
                        color: Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.6)
                        font.family: MusicStyle.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    function playCurrentLibrary() {
        if (libraryList.currentIndex >= 0 && libraryList.currentIndex < root.filteredLibrary.length)
            MusicState.playFile(root.filteredLibrary[libraryList.currentIndex])
    }

    function playCurrentQueue() {
        if (queueList.currentIndex >= 0 && queueList.currentIndex < MusicState.queueFiles.length)
            MusicState.playQueueIndex(queueList.currentIndex)
    }
}
