import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The Waybar backlight pill, re-created as a Quickshell overlay so it can
// expand on hover and reveal a draggable slider. It sits exactly over the
// transparent `custom/brightness` spacer slot in the Waybar layout:
//   * Overlay layer so it draws above Waybar
//   * top margin -24 lands on the Waybar pill row (same trick as the
//     calendar chip in CalendarPanel.qml)
//   * rightMargin = distance from the right screen edge to the pill's
//     right edge (tuned against the real bar with screenshots)
// The input mask keeps the transparent remainder of the surface
// click-through, so neighbouring Waybar pills stay clickable.
Scope {
    id: root

    readonly property color accent: "#2aa198"

    // ---------- geometry ----------
    // collapsedWidth should match the Waybar spacer slot width set in
    // style.css (#custom-brightness); rightMargin is measured from the
    // screen's right edge. Both tuned with screenshots — see changes.md.
    readonly property int collapsedWidth: 70
    readonly property int expandedWidth: 200
    readonly property int rightMargin: 276
    readonly property int pillHeight: 24

    // ---------- state ----------
    property int percent: 100
    property bool expanded: false
    property real pendingApply: -1

    readonly property bool dragActive: slider.dragging

    // Same icon set as the old Waybar backlight module (Nerd Font
    // "brightness" glyphs): the circle fills up as brightness rises.
    readonly property var iconGlyphs: ["\ue38d", "\ue3d3", "\ue3d1", "\ue3cf",
        "\ue3ce", "\ue3cd", "\ue3ca", "\ue3c8", "\ue39b"]
    readonly property string iconGlyph: {
        var i = Math.round(root.shownPercent / 100 * (root.iconGlyphs.length - 1))
        i = Math.max(0, Math.min(root.iconGlyphs.length - 1, i))
        return root.iconGlyphs[i]
    }

    // While dragging, the local slider value wins so the text follows
    // the finger; otherwise it shows the device value.
    readonly property int shownPercent: Math.max(1, Math.min(100,
        root.dragActive ? Math.round(slider.shown * 100) : root.percent))

    // ---------- brightnessctl ----------
    function applyPercent(p) {
        var v = Math.max(1, Math.min(100, Math.round(p)))
        setProc.command = ["brightnessctl", "set", v + "%"]
        setProc.running = true
    }

    // Drag updates are coalesced to at most every 30ms: smooth to the
    // eye without spawning a hundred brightnessctl calls per second.
    function requestPercent(p) {
        root.pendingApply = p
        if (!applyTimer.running)
            applyTimer.start()
    }

    function nudge(delta) {
        root.applyPercent(root.percent + delta)
    }

    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // e.g. amdgpu_bl1,backlight,65535,100%,65535
                var parts = String(text).trim().split(",")
                if (parts.length >= 4) {
                    var p = parseInt(parts[3])
                    if (!isNaN(p))
                        root.percent = p
                }
            }
        }
    }

    Process {
        id: setProc
        onExited: if (!readProc.running)
            readProc.running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!readProc.running)
            readProc.running = true
    }

    Timer {
        id: applyTimer
        interval: 30
        onTriggered: {
            if (root.pendingApply >= 0) {
                root.applyPercent(root.pendingApply)
                root.pendingApply = -1
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 260
        onTriggered: if (!hover.hovered && !root.dragActive)
            root.expanded = false
    }

    IpcHandler {
        target: "brightness"
        function up() { root.nudge(5) }
        function down() { root.nudge(-5) }
        function refresh() { if (!readProc.running) readProc.running = true }
        function expand() { root.expanded = true }
        function collapse() { root.expanded = false }
        function set(percent: int) { root.applyPercent(percent) }
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            right: true
        }

        margins {
            top: -24
            right: root.rightMargin
        }

        implicitWidth: root.expandedWidth
        implicitHeight: root.pillHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:brightness-pill"

        // Only the pill itself takes input; the rest of the surface
        // stays click-through.
        mask: Region {
            x: pill.x
            y: pill.y
            width: pill.width
            height: pill.height
            radius: pill.radius
        }

        Rectangle {
            id: pill
            anchors.top: parent.top
            anchors.right: parent.right
            height: root.pillHeight
            width: root.expanded ? root.expandedWidth : root.collapsedWidth
            radius: 8
            color: "#040404"

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        closeTimer.stop()
                        root.expanded = true
                    } else {
                        closeTimer.restart()
                    }
                }
            }

            WheelHandler {
                onWheel: function (event) {
                    var d = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y
                    if (d === 0)
                        return
                    root.nudge(d > 0 ? 5 : -5)
                    event.accepted = true
                }
            }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 5

                Text {
                    id: icon
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.iconGlyph
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: root.accent
                }

                VolumeSlider {
                    id: slider
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.expanded ? 104 : 0
                    height: 22
                    opacity: root.expanded ? 1 : 0
                    enabled: root.expanded
                    value: root.percent / 100
                    trackColor: "#1F1F1F"
                    fillColor: root.accent
                    knobColor: "#FFFFFF"

                    Behavior on width {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }

                    onDragged: function (v) {
                        root.requestPercent(v * 100)
                    }

                    onMoved: function (v) {
                        root.applyPercent(v * 100)
                        if (!hover.hovered)
                            closeTimer.restart()
                    }
                }

                Text {
                    id: pct
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.shownPercent + "%"
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }
    }
}
