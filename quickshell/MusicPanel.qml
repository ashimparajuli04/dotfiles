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

    property bool panelOpen: true
    property int tab: 0               // 0 = library, 1 = queue
    property string filter: ""

    readonly property var targetScreen: BarScreen.screen
    readonly property real screenW: root.targetScreen ? root.targetScreen.width : 1920
    readonly property real screenH: root.targetScreen ? root.targetScreen.height : 1080
    readonly property real maxListHeight: Math.round(root.screenH * 0.5)
    // sits directly above the music widget (bottom margin + widget height)
    readonly property int panelBottom: Math.round(root.screenH * 0.03) + MusicStyle.widgetHeight + 6
    readonly property int maxPanelHeight: Math.max(240,
        Math.min(Math.round(root.screenH * 0.62), root.screenH - root.panelBottom - 40))

    readonly property var filteredLibrary: {
        if (root.filter === "")
            return MusicState.libraryFiles
        var f = root.filter.toLowerCase()
        return MusicState.libraryFiles.filter(function (p) {
            return p.toLowerCase().indexOf(f) !== -1
        })
    }

    // a new filter invalidates the highlighted row
    onFilterChanged: libraryList.currentIndex = 0

    function displayName(p) {
        return p.replace(/\.[^.\/]+$/, "")
    }

    // IPC for this panel lives in the always-on PanelIpc.qml (this component is
    // lazy-loaded, so its own IpcHandler would vanish when closed).

    // Lazy-loaded (shell.qml): "opened" side effects run at load; closing
    // mirrors panelOpen back to the bus. PanelIpc sets PillBus.musicTab first.
    onPanelOpenChanged: PillBus.musicOpen = root.panelOpen

    // Keyboard focus target depends on the tab: the library keeps the search box
    // focused (so typing always refines), the queue is a plain list.
    function focusActive() {
        root.headerFocused = false
        if (root.tab === 0) {
            searchInput.forceActiveFocus()
        } else {
            var i = Math.max(0, MusicState.songPos - 1)
            queueList.currentIndex = i
            queueList.positionViewAtIndex(i, ListView.Center)
            queueList.forceActiveFocus()
        }
    }

    // ---- keyboard navigation ----
    // Left/Right move a highlight across the header controls
    // (Library → Queue → Shuffle → Close); Up/Down move the list selection;
    // Enter activates whichever the highlight is on.
    property bool headerFocused: false
    property int headerIndex: 0                 // 0=library 1=queue 2=shuffle 3=close
    readonly property int headerCount: 4

    function moveHeader(delta) {
        var idx = Math.max(0, Math.min(root.headerIndex + delta, root.headerCount - 1))
        root.headerIndex = idx
        if (idx === 0 || idx === 1) {
            // Library / Queue switch as soon as you land on them — no Enter.
            root.headerFocused = false
            root.tab = idx
            root.focusActive()
        } else {
            // Shuffle / Close only highlight; Enter activates them.
            root.headerFocused = true
        }
    }

    function activateHeader() {
        switch (root.headerIndex) {
        case 0: root.tab = 0; root.headerFocused = false; root.focusActive(); break
        case 1: root.tab = 1; root.headerFocused = false; root.focusActive(); break
        case 2: MusicState.shuffleAll(); break
        case 3: root.panelOpen = false; break
        }
    }

    function moveSelection(delta) {
        root.headerFocused = false
        if (root.tab === 0)
            libraryList.currentIndex = Math.max(0, Math.min(libraryList.currentIndex + delta, libraryList.count - 1))
        else
            queueList.currentIndex = Math.max(0, Math.min(queueList.currentIndex + delta, queueList.count - 1))
    }

    function confirm() {
        if (root.headerFocused)
            root.activateHeader()
        else if (root.tab === 0)
            root.playCurrentLibrary()
        else
            root.playCurrentQueue()
    }

    Component.onCompleted: {
        root.tab = PillBus.musicTab
        MusicState.refreshLibrary()
        MusicState.refreshQueue()
        root.filter = ""
        focusActive()
    }

    Connections {
        target: PillBus
        function onMusicTabChanged() {
            root.tab = PillBus.musicTab
            focusActive()
        }
    }

    // Transparent click-catcher below the Waybar.
    PanelWindow {
        visible: root.panelOpen
        screen: BarScreen.screen

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
            bottom: root.panelBottom
        }

        implicitWidth: MusicStyle.widgetWidth
        implicitHeight: Math.min(frame.implicitHeight, root.maxPanelHeight)
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:music-panel"
        // Exclusive (not OnDemand): OnDemand focus is "as determined by the OS"
        // and wlroots only grants it on a click, so a panel opened by the keybind
        // (or the cover-art click) never receives the keyboard. Exclusive grabs it
        // while open so the search box + arrow keys work immediately.
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Belt-and-braces: refocus the right widget whenever the surface maps.
        onVisibleChanged: if (visible) focusActive()

        Rectangle {
            id: frame
            anchors.fill: parent
            focus: true
            color: MusicStyle.bg
            implicitHeight: col.implicitHeight + 24

            // Meta+M closes again: Exclusive focus swallows the sway keybind while
            // the panel is open, so handle the toggle here instead.
            Shortcut { sequence: "Meta+M"; onActivated: root.panelOpen = false }

            Keys.onLeftPressed: root.moveHeader(-1)
            Keys.onRightPressed: root.moveHeader(1)
            Keys.onReturnPressed: root.confirm()
            Keys.onEnterPressed: root.confirm()
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

                            readonly property bool focused: root.headerFocused && root.headerIndex === modelData.idx

                            implicitWidth: 68
                            implicitHeight: 24
                            color: root.tab === modelData.idx ? MusicStyle.fg
                                : (focused ? Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.12) : "transparent")
                            border.width: 2
                            border.color: focused ? MusicStyle.neonB : MusicStyle.border

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
                                onClicked: {
                                    root.headerFocused = false
                                    root.tab = modelData.idx
                                    root.focusActive()
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MusicButton {
                        // md-shuffle U+F049D
                        glyph: "\udb81\udc9d"
                        active: root.headerFocused && root.headerIndex === 2
                        onClicked: MusicState.shuffleAll()
                    }

                    MusicButton {
                        // md-close U+F0156
                        glyph: "\udb80\udd56"
                        active: root.headerFocused && root.headerIndex === 3
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

                        onTextChanged: {
                            root.filter = text
                            root.headerFocused = false
                        }

                        // Left/Right move the header highlight; Up/Down move the
                        // list selection without leaving the search box (so typing
                        // to refine always works); Enter confirms the highlight.
                        Keys.onLeftPressed: root.moveHeader(-1)
                        Keys.onRightPressed: root.moveHeader(1)
                        Keys.onDownPressed: root.moveSelection(1)
                        Keys.onUpPressed: root.moveSelection(-1)
                        Keys.onReturnPressed: root.confirm()
                        Keys.onEnterPressed: root.confirm()
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
                        currentIndex: 0

                        Keys.onReturnPressed: root.playCurrentLibrary()
                        Keys.onEnterPressed: root.playCurrentLibrary()

                        delegate: Rectangle {
                            id: libRow

                            required property string modelData
                            required property int index

                            readonly property bool selected: ListView.isCurrentItem
                            width: libraryList.width
                            height: 22
                            color: selected ? MusicStyle.fg
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
                                text: root.displayName(libRow.modelData)
                                color: libRow.selected ? MusicStyle.bg : MusicStyle.fg
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
                        currentIndex: 0

                        onVisibleChanged: if (visible && MusicState.songPos > 0) {
                            currentIndex = MusicState.songPos - 1
                            positionViewAtIndex(MusicState.songPos - 1, ListView.Center)
                        }

                        Keys.onLeftPressed: root.moveHeader(-1)
                        Keys.onRightPressed: root.moveHeader(1)
                        Keys.onDownPressed: root.moveSelection(1)
                        Keys.onUpPressed: root.moveSelection(-1)
                        Keys.onReturnPressed: root.confirm()
                        Keys.onEnterPressed: root.confirm()
                        Keys.onEscapePressed: root.panelOpen = false

                        delegate: Rectangle {
                            id: queueRow

                            required property string modelData
                            required property int index

                            readonly property bool isCurrent: MusicState.songPos - 1 === index
                            readonly property bool selected: ListView.isCurrentItem

                            width: queueList.width
                            height: 22
                            // cursor = solid fill (as in the library); the
                            // currently-playing row is marked with a ▶ glyph in a
                            // fixed-width column so titles stay aligned
                            color: selected ? MusicStyle.fg
                                : (hover.hovered ? Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.12) : "transparent")

                            HoverHandler {
                                id: hover
                                cursorShape: Qt.PointingHandCursor
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                text: queueRow.isCurrent ? "\udb81\udc0a" : ""
                                color: queueRow.selected ? MusicStyle.bg : MusicStyle.fg
                                font.family: MusicStyle.fontFamily
                                font.pixelSize: queueRow.height
                            }

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 30
                                anchors.rightMargin: 4
                                verticalAlignment: Text.AlignVCenter
                                text: (queueRow.index + 1) + "  " + root.displayName(queueRow.modelData)
                                color: queueRow.selected ? MusicStyle.bg : MusicStyle.fg
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
