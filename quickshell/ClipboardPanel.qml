import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Clipboard history popover, lazy-loaded by shell.qml while
// PillBus.clipboardOpen is true (so it costs ~0 while closed).
//
// It sits under the Waybar-drawn clipboard pill: PillBus.clipboardLeft is the
// pill's left edge, recomputed from the workspace count (Waybar lays out the
// pill itself). Opens on a left-click on the pill or Mod+Shift+V; closes on an
// outside click, Esc, or after picking an entry (unless pinned).
Scope {
    id: root

    readonly property int panelWidth: 340
    readonly property int maxListHeight: 320

    property string query: ""

    readonly property var filtered: {
        var q = root.query.trim().toLowerCase()
        if (q === "")
            return ClipboardHistory.entries
        var out = []
        for (var i = 0; i < ClipboardHistory.entries.length; i++) {
            var e = ClipboardHistory.entries[i]
            if (e.preview.toLowerCase().indexOf(q) !== -1)
                out.push(e)
        }
        return out
    }

    function closeAndUnpin() {
        PillBus.clipboardPinned = false
        PillBus.close("clipboard")
    }

    function activate(id) {
        ClipboardHistory.copy(id)
        if (!PillBus.clipboardPinned)
            PillBus.close("clipboard")
    }

    // Keep the list fresh while the panel is open (cliphist has no event
    // stream). Cheap: one `cliphist list` fork every 1.5s, only while open.
    Timer {
        interval: 1500
        running: PillBus.clipboardOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: ClipboardHistory.refresh()
    }

    // ---------- click catcher (outside click closes) ----------
    PanelWindow {
        screen: BarScreen.screen
        id: catcher
        visible: PillBus.clipboardOpen

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

        // Top layer, so the panel (Overlay) always draws above it.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:clipboard-catcher"

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeAndUnpin()
        }
    }

    // ---------- the panel ----------
    PanelWindow {
        screen: BarScreen.screen
        id: panel
        visible: PillBus.clipboardOpen

        anchors {
            top: true
            left: true
        }

        margins {
            top: 30
            left: panel.screen ? Math.max(4, Math.min(PillBus.clipboardLeft,
                                                     panel.screen.width - root.panelWidth - 4))
                               : PillBus.clipboardLeft
        }

        implicitWidth: root.panelWidth
        implicitHeight: Math.min(root.maxListHeight + 150, frame.implicitHeight)
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:clipboard-panel"
        WlrLayershell.keyboardFocus: PillBus.clipboardOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: frame

            anchors.fill: parent
            focus: true
            color: Theme.bg
            radius: Theme.radius
            implicitHeight: col.implicitHeight + 28
            clip: true

            Keys.onEscapePressed: root.closeAndUnpin()

            ColumnLayout {
                id: col

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 14
                }

                spacing: 6

                // ---- header ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\uDB80\uDD4D"
                        color: Theme.accent
                        font.family: "Material Design Icons"
                        font.pixelSize: 18
                    }

                    Text {
                        text: "Clipboard"
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    PillButton {
                        glyph: "\uDB81\uDC03"
                        fontFamily: "Material Design Icons"
                        bgColor: PillBus.clipboardPinned ? Theme.accent : Theme.bgAlt
                        hoverColor: PillBus.clipboardPinned ? Theme.active : Qt.lighter(Theme.bgAlt, 1.25)
                        onClicked: PillBus.clipboardPinned = !PillBus.clipboardPinned
                    }

                    PillButton {
                        glyph: "\uDB82\uDDE7"
                        fontFamily: "Material Design Icons"
                        onClicked: ClipboardHistory.wipe()
                    }
                }

                // ---- search ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    implicitHeight: 32
                    radius: 10
                    color: Theme.bgAlt

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "\uDB80\uDF49"
                            color: Theme.muted
                            font.family: "Material Design Icons"
                            font.pixelSize: 14
                        }

                        TextInput {
                            id: searchInput

                            Layout.fillWidth: true
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            clip: true
                            selectByMouse: true
                            onTextChanged: root.query = text

                            Keys.onEscapePressed: root.closeAndUnpin()

                            Text {
                                anchors.fill: parent
                                visible: searchInput.text === ""
                                text: "Search…"
                                color: Theme.muted
                                verticalAlignment: Text.AlignVCenter
                                font: searchInput.font
                            }
                        }
                    }
                }

                // ---- history list ----
                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.preferredHeight: Math.min(contentHeight, root.maxListHeight)
                    spacing: 4
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filtered

                    delegate: Rectangle {
                        id: row

                        required property var modelData

                        readonly property string thumb: ClipboardHistory.thumbs[row.modelData.id] || ""

                        width: list.width
                        height: (row.modelData.isImage && row.thumb !== "") ? 46 : 40
                        radius: 10
                        color: rowHover.hovered ? Theme.bgAlt : "transparent"

                        HoverHandler {
                            id: rowHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.activate(row.modelData.id)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            // Leading: a thumbnail for image clips (once decoded),
                            // otherwise a type glyph.
                            Item {
                                Layout.preferredWidth: row.modelData.isImage ? 56 : 18
                                Layout.fillHeight: true

                                Text {
                                    anchors.centerIn: parent
                                    visible: row.thumb === ""
                                    text: row.modelData.isImage ? "\uDB80\uDEE9" : "\uDB80\uDD8F"
                                    color: Theme.muted
                                    font.family: "Material Design Icons"
                                    font.pixelSize: 15
                                }

                                Image {
                                    anchors.centerIn: parent
                                    visible: row.thumb !== ""
                                    width: 52
                                    height: 36
                                    source: row.thumb !== "" ? "file://" + row.thumb : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    sourceSize.width: 104
                                    sourceSize.height: 72
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.preview
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                visible: rowHover.hovered

                                text: "\uDB82\uDDE7"
                                color: delHover.hovered ? "#FF5555" : Theme.muted
                                font.family: "Material Design Icons"
                                font.pixelSize: 15

                                HoverHandler {
                                    id: delHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: ClipboardHistory.remove(row.modelData.id)
                                }
                            }
                        }
                    }
                }

                // ---- empty state ----
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 4
                    visible: root.filtered.length === 0
                    text: root.query !== "" ? "No matches." : "Clipboard is empty."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
