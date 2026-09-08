import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool panelOpen: false
    property int selectedIndex: 0
    property int hoveredIndex: -1
    property int tooltipIndex: -1
    property int tooltipDelay: 500
    property string userHost: ""
    property string uptime: ""

    // Colors and metrics are copied from the rofi powermenu theme
    // (~/.config/rofi/powermenu/type-6/style-5.rasi) so the panel looks
    // identical: centered 800x369 frame, 2x3 icon grid, image side panel.
    readonly property color bg: "#11092D"
    readonly property color bgAlt: "#281657"
    readonly property color fg: "#FFFFFF"
    readonly property color sel: "#DF5296"
    readonly property color active: "#6E77FF"
    readonly property color barText: "#11092D"

    readonly property int tileWidth: 105
    readonly property int tileHeight: 83
    readonly property int tileMargin: 30
    readonly property int tileSpacing: 30

    // Same order as the rofi menu (its listview is column-major):
    // lock / suspend / logout in the first column, hibernate / reboot /
    // shutdown in the second.
    readonly property var actions: [
        { name: "Lock", glyph: "\uE98F", command: ["bash", "-c", "swaylock -i ~/Pictures/wallpapers/newwave-1.png --indicator-radius 70 --inside-color 1e1e2e --inside-clear-color f5c2e7 --inside-wrong-color f38ba8 --ring-color 1e1e2e --ring-clear-color f5c2e7 --ring-ver-color 89b4fa --ring-wrong-color f38ba8 --inside-ver-color 89b4fa --line-clear-color f5c2e7 --line-wrong-color f38ba8 --line-ver-color 89b4fa --font \"SF Pro Display\""] },
        { name: "Suspend", glyph: "\uE9A3", command: ["bash", "-c", "mpc -q pause; amixer set Master mute; systemctl suspend"] },
        { name: "Logout", glyph: "\uE991", command: ["swaymsg", "exit"] },
        { name: "Hibernate", glyph: "\uE9AF", command: ["systemctl", "hibernate"] },
        { name: "Reboot", glyph: "\uE9C4", command: ["systemctl", "reboot"] },
        { name: "Shutdown", glyph: "\uE9C0", command: ["systemctl", "poweroff"] }
    ]

    function refreshInfo() {
        infoProc.running = true
    }

    // Hovering a tile long enough reveals its name under the grid.
    Timer {
        id: tooltipTimer
        interval: root.tooltipDelay
        repeat: false
        onTriggered: root.tooltipIndex = root.hoveredIndex
    }

    // Rofi cycles through the list; arrows move within/across the columns.
    function moveSelection(dx, dy) {
        var col = Math.floor(root.selectedIndex / 3)
        var row = root.selectedIndex % 3
        root.selectedIndex = ((col + dx + 2) % 2) * 3 + ((row + dy + 3) % 3)
    }

    function run(index) {
        var action = root.actions[index]
        if (!action)
            return
        root.panelOpen = false
        actionProc.command = action.command
        actionProc.running = true
    }

    // Opening this popover closes the others, and vice versa.
    Process {
        id: hideWifi
        command: ["qs", "ipc", "call", "wifi", "hide"]
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
        id: actionProc
    }

    Process {
        id: infoProc
        command: ["bash", "-c", "printf '%s@%s|%s' \"$USER\" \"$(cat /proc/sys/kernel/hostname)\" \"$(uptime -p | sed -e 's/up //g')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("|")
                if (parts.length >= 2) {
                    root.userHost = parts[0]
                    root.uptime = parts[1]
                }
            }
        }
    }

    onPanelOpenChanged: {
        if (root.panelOpen) {
            // Rofi highlights the first entry on open.
            root.selectedIndex = 0
            root.hoveredIndex = -1
            root.tooltipIndex = -1
            tooltipTimer.stop()
            root.refreshInfo()
            hideWifi.running = true
            hideBluetooth.running = true
            hideSound.running = true
            frame.forceActiveFocus()
        } else {
            tooltipTimer.stop()
            root.hoveredIndex = -1
            root.tooltipIndex = -1
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle() { root.panelOpen = !root.panelOpen }
        function show() { root.panelOpen = true }
        function hide() { root.panelOpen = false }
    }

    // Transparent click-catcher: closes the popover when clicking anywhere
    // outside of it. The Waybar's 30px exclusive zone is applied by the
    // compositor, so no top margin is needed: the surface starts right
    // below the bar, which is exactly the area rofi centers its window in.
    PanelWindow {
        id: catcher
        visible: root.panelOpen

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:powermenu"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.panelOpen = false
        }

        Rectangle {
            id: frame
            width: 800
            height: 369
            anchors.centerIn: parent
            // Rofi places the centered window one pixel lower; match it.
            anchors.verticalCenterOffset: 1
            color: root.bg
            focus: true

            Keys.onEscapePressed: root.panelOpen = false
            Keys.onReturnPressed: root.run(root.selectedIndex)
            Keys.onEnterPressed: root.run(root.selectedIndex)
            Keys.onUpPressed: root.moveSelection(0, -1)
            Keys.onDownPressed: root.moveSelection(0, 1)
            Keys.onLeftPressed: root.moveSelection(-1, 0)
            Keys.onRightPressed: root.moveSelection(1, 0)

            // Absorb clicks so only the area outside the frame closes the menu.
            MouseArea {
                anchors.fill: parent
            }

            // ---- Action grid (2 columns x 3 rows, column-major) ----
            Repeater {
                model: root.actions.length
                delegate: Rectangle {
                    x: root.tileMargin + Math.floor(index / 3) * (root.tileWidth + root.tileSpacing)
                    y: root.tileMargin + (index % 3) * (root.tileHeight + root.tileSpacing)
                    width: root.tileWidth
                    height: root.tileHeight
                    color: root.selectedIndex === index ? root.sel : root.bgAlt

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) {
                                root.selectedIndex = index
                                root.hoveredIndex = index
                                tooltipTimer.restart()
                            } else if (root.hoveredIndex === index) {
                                root.hoveredIndex = -1
                                root.tooltipIndex = -1
                                tooltipTimer.stop()
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.run(index)
                    }

                    Text {
                        anchors.centerIn: parent
                        // The glyph's ink sits slightly right of the em box center.
                        anchors.horizontalCenterOffset: -1
                        text: root.actions[index].glyph
                        color: root.selectedIndex === index ? root.bg : root.fg
                        font.family: "feather"
                        font.pointSize: 32
                        font.bold: true
                    }
                }
            }

            // ---- Hover tooltip: the tile's name after a short delay ----
            Rectangle {
                id: tooltip
                visible: root.tooltipIndex >= 0
                width: tooltipText.implicitWidth + 20
                height: 24
                x: Math.round(150 - width / 2)
                y: 342
                color: root.bgAlt

                Text {
                    id: tooltipText
                    anchors.centerIn: parent
                    text: root.tooltipIndex >= 0 ? root.actions[root.tooltipIndex].name : ""
                    color: root.fg
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                }
            }

            // ---- Image panel (right half) ----
            // Rofi scales z.png (510x420) to the panel height, keeps the
            // aspect ratio, anchors it top-left and repeats it horizontally;
            // the clipped strip on the right shows the next tile's edge.
            Item {
                id: imageBox
                x: 300
                y: 0
                width: 500
                height: 369
                clip: true

                readonly property string src: "file://" + Quickshell.shellDir + "/../rofi/images/z.png"
                // 510/420 are the natural dimensions of z.png.
                readonly property real imgWidth: 510 * (height / 420)

                Image {
                    x: 0
                    y: 0
                    width: imageBox.imgWidth
                    height: imageBox.height
                    source: imageBox.src
                    fillMode: Image.Stretch
                    smooth: true
                }

                Image {
                    x: imageBox.imgWidth
                    y: 0
                    width: imageBox.imgWidth
                    height: imageBox.height
                    source: imageBox.src
                    fillMode: Image.Stretch
                    smooth: true
                }
            }

            // ---- User / host (top bar), pink like rofi's inputbar ----
            Rectangle {
                x: 310
                y: 10
                width: 480
                height: 58
                color: root.sel

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    // Rofi's font fallback picks Material Icons for this glyph.
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "\uEA00 "
                        color: root.barText
                        font.family: "Material Icons"
                        font.pointSize: 10
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.userHost
                        color: root.barText
                        font.family: Theme.fontFamily
                        font.pointSize: 10
                    }
                }
            }

            // ---- Uptime (bottom bar), blue like rofi's message box ----
            Rectangle {
                x: 310
                y: 301
                width: 480
                height: 58
                color: root.active

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    // Rofi's font fallback picks Iosevka for this glyph.
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "\uE939 "
                        color: root.barText
                        font.family: "Iosevka Nerd Font"
                        font.pointSize: 10
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "Uptime: " + root.uptime
                        color: root.barText
                        font.family: Theme.fontFamily
                        font.pointSize: 10
                    }
                }
            }
        }
    }
}
