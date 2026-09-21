import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// The Waybar pulseaudio pill, re-created as a Quickshell overlay so it can
// expand on hover and reveal a draggable slider — same approach as
// BrightnessPill.qml.
//
// The slider ALWAYS controls the PipeWire default sink: the exact same
// device your keyboard volume keys drive (`pactl ... @DEFAULT_SINK@`).
// When two devices are playing at once, this still only touches the
// default one, just like the keys do.
//
// Geometry: sits on the transparent `custom/sound` Waybar spacer and
// expands LEFTWARD (right edge pinned at x=1795, flush against the
// bluetooth pill; joined row — changes.md §32), unlike the brightness
// pill. While it expands it pushes the brightness pill left via
// PillBus.soundPush; the bluetooth and wifi pills (to its right) push
// this pill in turn, so the joined row stays flush when it grows (see
// PillBus.qml). Left of the brightness pill the space is empty
// (mpris/tray pills, if visible, are the only thing that can be
// transiently covered).
Scope {
    id: root

    readonly property color accent: "#a55377"   // waybar #pulseaudio
    readonly property color mutedColor: "#fb958b"

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots — see changes.md §14/§25/§28.
    // Joined row (§32): rightMargin 125 = 98 (bluetooth) + 27 (its width),
    // so this pill's right edge sits flush against the bluetooth pill.
    readonly property int collapsedWidth: 27
    readonly property int expandedWidth: 118    // right edge stays at x=1795
    readonly property int rightMargin: 125      // screen right edge → window right edge
    readonly property int pillHeight: 24

    // ---------- state ----------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: (root.sink && root.sink.audio) ? root.sink.audio.volume : 0
    readonly property bool muted: (root.sink && root.sink.audio) ? root.sink.audio.muted : false

    property bool expanded: false

    readonly property bool dragActive: slider.dragging
    // Never display more than 100%: above that is over-amplification the
    // UI should not offer (see changes.md §27).
    readonly property real shownFraction: Math.max(0, Math.min(1, root.dragActive ? slider.shown : root.volume))
    readonly property int shownPercent: Math.round(root.shownFraction * 100)

    // Keep live bindings on the displayed node: untracked nodes may not
    // push property updates (see changes.md §11).
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function prop(name) {
        return (root.sink && root.sink.properties) ? root.sink.properties[name] : undefined
    }

    // Same glyphs the old Waybar module used: mute → 󰝟, headphones →
    // the  FontAwesome headphone glyph, otherwise 󰕿/󰖀/󰕾 by level.
    // Plane-15 codepoints use surrogate pairs: a 5-hex-digit \u escape is
    // invalid in JS and truncates to a 4-digit glyph + a literal character.
    readonly property string glyph: {
        if (root.muted)
            return "\udb81\udf5f"
        var d = ((root.prop("device.icon-name") || "") + " "
            + (root.sink ? root.sink.name : "") + " " + (root.sink ? root.sink.description : "")).toLowerCase()
        if (d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1
            || d.indexOf("earbud") !== -1 || d.indexOf("bluez") !== -1)
            return "\uf025"
        if (root.shownFraction < 0.33)
            return "\udb81\udd7f"
        if (root.shownFraction < 0.66)
            return "\udb81\udd80"
        return "\udb81\udd7e"
    }

    // ---------- volume ----------
    // Hard ceiling at 100%: wheel, drag and IPC all funnel through here,
    // so the UI can never dial in over-amplification.
    function applyVolume(v) {
        if (root.sink && root.sink.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    // Drag updates are coalesced to at most every 30ms (see BrightnessPill).
    property real pendingApply: -1
    function requestVolume(v) {
        root.pendingApply = v
        if (!applyTimer.running)
            applyTimer.start()
    }

    function nudge(delta) {
        root.applyVolume(root.volume + delta)
    }

    Timer {
        id: applyTimer
        interval: 30
        onTriggered: {
            if (root.pendingApply >= 0) {
                root.applyVolume(root.pendingApply)
                root.pendingApply = -1
            }
        }
    }

    // Hover — or an active slider drag — keeps this pill engaged in
    // PillBus; collapsing is driven by PillBus.collapseTick and only
    // happens after no pill in the row is engaged. A drag can therefore
    // never be collapsed mid-drag, and releasing it outside the pill
    // resumes the normal grace period — see PillBus.qml.
    Binding {
        target: PillBus
        property: "hoverSound"
        value: hover.hovered || root.dragActive
    }

    Connections {
        target: PillBus
        function onCollapseTickChanged() {
            if (!hover.hovered && !root.dragActive)
                root.expanded = false
        }
    }

    // Panel toggling is in-process via PillBus (no `qs ipc` subprocess). See PillBus.qml.
    Process {
        id: pavuProc
        command: ["pavucontrol"]
    }

    // Publish the live expansion delta so the brightness pill slides out
    // of the way in perfect sync (see PillBus.qml / BrightnessPill.qml).
    Binding {
        target: PillBus
        property: "soundPush"
        value: Math.max(0, Math.round(pill.width - root.collapsedWidth))
    }

    Binding {
        target: PillBus
        property: "soundMaxPush"
        value: root.expandedWidth - root.collapsedWidth
    }

    IpcHandler {
        target: "volume"
        function up() { root.nudge(0.05) }
        function down() { root.nudge(-0.05) }
        function set(percent: int) { root.applyVolume(percent / 100) }
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

        implicitWidth: root.expandedWidth + PillBus.maxPushSound
        implicitHeight: root.pillHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:sound-pill"

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
            // Right edge normally at 1787, flush against the bluetooth
            // pill; the bluetooth/wifi/battery pills (to the right) push
            // this pill left while they expand.
            x: win.width - width - PillBus.pushSound
            height: root.pillHeight
            width: root.expanded ? root.expandedWidth : root.collapsedWidth
            // Middle segment of the joined row: square corners.
            radius: 0
            color: "#040404"

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function (mouse) {
                    if (mouse.button === Qt.RightButton)
                        pavuProc.running = true
                    else
                        PillBus.toggleOpen("sound")
                }
            }

            HoverHandler {
                id: hover
                onHoveredChanged: if (hovered)
                    root.expanded = true
            }

            WheelHandler {
                onWheel: function (event) {
                    var d = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y
                    if (d === 0)
                        return
                    root.nudge(d > 0 ? 0.05 : -0.05)
                    event.accepted = true
                }
            }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 5

                Text {
                    id: glyphText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyph
                    color: root.muted ? root.mutedColor : root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                VolumeSlider {
                    id: slider
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.expanded ? 84 : 0
                    height: 22
                    opacity: root.expanded ? 1 : 0
                    enabled: root.expanded
                    value: root.volume
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
                        root.requestVolume(v)
                    }

                    onMoved: function (v) {
                        // Releasing the drag re-engages the normal grace
                        // period (the PillBus hover binding drops when
                        // dragActive goes false — see PillBus.qml).
                        root.applyVolume(v)
                    }
                }
            }
        }
    }
}
