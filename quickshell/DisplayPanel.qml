import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Display setup wizard — a centred modal card. Opened automatically when a
// never-configured external display is connected (Displays.qml) or manually
// from the power menu's Display button. See Displays.qml for the state
// machine, persistence and the sway commands it drives.
Scope {
    id: root

    readonly property var disp: Displays

    readonly property color tile: "#281657"
    readonly property color tileHover: "#3A2370"
    readonly property color fg: "#FFFFFF"
    readonly property color muted: "#A79BC8"
    readonly property color accent: "#DF5296"
    readonly property color active: "#6E77FF"

    // Pop-in animation (0 -> 1).
    property real intro: 0
    NumberAnimation on intro {
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.OutCubic
        running: true
    }

    // ---------- mode definitions ----------
    readonly property var modes: [
        { key: "mirror", label: "Mirror", desc: "Same on both", glyph: "\udb80\udd8f" },
        { key: "expand", label: "Expand", desc: "Side by side", glyph: "\udb81\ude16" },
        { key: "only-laptop", label: "Only laptop", desc: "External off", glyph: "\udb80\udf22" },
        { key: "only-external", label: "Only external", desc: "Laptop off", glyph: "\udb80\udf79" }
    ]

    readonly property var sides: [
        { key: "up", glyph: "\udb80\udc5d" },
        { key: "down", glyph: "\udb80\udc45" },
        { key: "left", glyph: "\udb80\udc4d" },
        { key: "right", glyph: "\udb80\udc54" }
    ]

    readonly property string deviceLabel: disp.deviceModel && disp.deviceModel.length
        ? disp.deviceModel + " (" + disp.deviceName + ")"
        : disp.deviceName

    readonly property string mainShort: disp.chosenMain === disp.internalName ? "Laptop" : "External"
    readonly property string otherShort: disp.chosenMain === disp.internalName ? "External" : "Laptop"

    function close() { root.disp.cancel() }

    // ---------- reusable tile ----------
    component OptionTile: Rectangle {
        id: t
        property string glyph: ""
        property string label: ""
        property string desc: ""
        property bool selected: false
        signal activated()

        width: 136
        height: 110
        radius: 12
        color: hover.hovered ? root.tileHover : root.tile
        border.width: t.selected ? 2 : 0
        border.color: root.accent

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: t.activated()
        }

        Column {
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: t.glyph
                color: t.selected ? root.accent : root.fg
                font.family: Theme.fontFamily
                font.pixelSize: 30
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: t.label
                color: root.fg
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: t.desc
                color: root.muted
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }
        }
    }

    component TextButton: Rectangle {
        id: b
        property string label: ""
        signal activated()
        width: btext.implicitWidth + 24
        height: 30
        radius: 8
        color: bhover.hovered ? root.tileHover : root.tile
        HoverHandler { id: bhover; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: b.activated() }
        Text {
            id: btext
            anchors.centerIn: parent
            text: b.label
            color: root.fg
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    // ---------- side picker arrow ----------
    component ArrowTile: Rectangle {
        id: a
        property string glyph: ""
        signal activated()
        width: 64
        height: 64
        radius: 10
        color: ahover.hovered ? root.tileHover : root.tile
        HoverHandler { id: ahover; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: a.activated() }
        Text {
            anchors.centerIn: parent
            text: a.glyph
            color: root.fg
            font.family: Theme.fontFamily
            font.pixelSize: 26
        }
    }

    PanelWindow {
        id: catcher
        visible: root.disp.promptOpen
        screen: BarScreen.screen

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:display-setup"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 640
            height: content.implicitHeight + 48
            radius: Theme.radius
            color: Theme.bg
            opacity: root.intro
            scale: 0.96 + 0.04 * root.intro
            focus: true

            Keys.onEscapePressed: root.close()

            // Absorb clicks on the card so only the outside closes it.
            MouseArea { anchors.fill: parent }

            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 16

                // ---------- header ----------
                Text {
                    width: parent.width
                    text: "Display setup"
                    color: root.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: root.disp.hasExternal
                    text: root.deviceLabel
                    color: root.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                // ---------- no external connected ----------
                Text {
                    width: parent.width
                    visible: !root.disp.hasExternal
                    wrapMode: Text.WordWrap
                    text: "No external display connected. Plug one in and it will be configured automatically."
                    color: root.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                // ---------- step 0: mode ----------
                Row {
                    visible: root.disp.hasExternal && root.disp.step === 0
                    spacing: 12
                    Repeater {
                        model: root.modes
                        delegate: OptionTile {
                            required property var modelData
                            glyph: modelData.glyph
                            label: modelData.label
                            desc: modelData.desc
                            selected: root.disp.chosenMode === modelData.key
                            onActivated: root.disp.chooseMode(modelData.key)
                        }
                    }
                }

                // ---------- step 1: main display ----------
                Column {
                    visible: root.disp.hasExternal && root.disp.step === 1
                    spacing: 12
                    Text {
                        text: "Which display is the main one?"
                        color: root.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    Row {
                        spacing: 12
                        OptionTile {
                            glyph: "\udb80\udf22"
                            label: "Laptop"
                            desc: root.disp.internalName
                            selected: root.disp.chosenMain === root.disp.internalName
                            onActivated: root.disp.chooseMain(root.disp.internalName)
                        }
                        OptionTile {
                            glyph: "\udb80\udf79"
                            label: "External"
                            desc: root.disp.deviceName
                            selected: root.disp.chosenMain === root.disp.deviceName
                            onActivated: root.disp.chooseMain(root.disp.deviceName)
                        }
                    }
                }

                // ---------- step 2: position ----------
                Column {
                    visible: root.disp.hasExternal && root.disp.step === 2
                    spacing: 12
                    Text {
                        text: "Where is " + root.otherShort + " relative to " + root.mainShort + "?"
                        color: root.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Item {
                        width: 3 * 64 + 2 * 6
                        height: 3 * 64 + 2 * 6
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 64
                            height: 64
                            radius: 10
                            color: root.active
                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Main"
                                    color: "#FFFFFF"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.mainShort
                                    color: "#FFFFFF"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                }
                            }
                        }

                        ArrowTile {
                            x: 70; y: 0
                            glyph: "\udb80\udc5d"
                            onActivated: root.disp.chooseSide("up")
                        }
                        ArrowTile {
                            x: 70; y: 140
                            glyph: "\udb80\udc45"
                            onActivated: root.disp.chooseSide("down")
                        }
                        ArrowTile {
                            x: 0; y: 70
                            glyph: "\udb80\udc4d"
                            onActivated: root.disp.chooseSide("left")
                        }
                        ArrowTile {
                            x: 140; y: 70
                            glyph: "\udb80\udc54"
                            onActivated: root.disp.chooseSide("right")
                        }
                    }
                }

                // ---------- footer ----------
                Row {
                    spacing: 12
                    TextButton {
                        visible: root.disp.step > 0
                        label: "\udb80\udd41  Back"
                        onActivated: root.disp.back()
                    }
                    TextButton {
                        label: "Cancel"
                        onActivated: root.close()
                    }
                }
            }
        }
    }

    Component.onCompleted: card.forceActiveFocus()
}
