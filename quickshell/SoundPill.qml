import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// The Waybar pulseaudio pill, re-created as a Quickshell overlay. Hovering it
// opens SoundPanel as a preview (held while the pointer is on the pill or the
// panel, closed 1s after leaving both); clicking it opens/latches the panel
// until an outside click. See PillBus.qml for the shared preview logic.
//
// The old inline hover slider is gone — volume is adjusted by scrolling over
// the pill or from the panel. The wheel always controls the PipeWire default
// sink: the exact same device your keyboard volume keys drive.
Scope {
    id: root

    readonly property color accent: "#a55377"   // waybar #pulseaudio
    readonly property color mutedColor: "#fb958b"

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots — see changes.md §14/§25/§28.
    // Joined row (§32): rightMargin 125 = 98 (bluetooth) + 27 (its width),
    // so this pill's right edge sits flush against the bluetooth pill.
    readonly property int collapsedWidth: 27
    readonly property int rightMargin: 116      // screen right edge → window right edge
    readonly property int pillHeight: 24

    // ---------- state ----------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: (root.sink && root.sink.audio) ? root.sink.audio.volume : 0
    readonly property bool muted: (root.sink && root.sink.audio) ? root.sink.audio.muted : false

    // Never display more than 100%: above that is over-amplification the
    // UI should not offer (see changes.md §27).
    readonly property real shownFraction: Math.max(0, Math.min(1, root.volume))
    readonly property int shownPercent: Math.round(root.shownFraction * 100)

    // Keep live bindings on the displayed node: untracked nodes may not
    // push property updates (see changes.md §11).
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function prop(name) {
        return (root.sink && root.sink.properties) ? root.sink.properties[name] : undefined
    }

    // Same glyphs the old Waybar module used: mute → 󰝟, otherwise
    // 󰕿/󰖀/󰕾 by level. Deliberately level-based only — the icon never
    // switches to a headphone glyph when headphones are connected, so the
    // speaker always reflects the volume level.
    // Plane-15 codepoints use surrogate pairs: a 5-hex-digit \u escape is
    // invalid in JS and truncates to a 4-digit glyph + a literal character.
    readonly property string glyph: {
        if (root.muted)
            return "\udb81\udf5f"
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

    // Drag updates were coalesced here while the inline slider existed; with
    // the slider gone the wheel and IPC nudge apply straight away.
    function nudge(delta) {
        root.applyVolume(root.volume + delta)
    }

    // Publish "pointer is on the pill" so PillBus can hold the preview panel
    // open while the pointer is either on the pill or on the panel.
    Binding {
        target: PillBus
        property: "hoverSound"
        value: hover.hovered
    }

    // Hover opens the panel as a preview; a click opens it latched. Shared
    // close timer / latch state live in PillBus.qml.
    function openPreview() {
        if (!PillBus.soundOpen) {
            PillBus.show("sound")
            PillBus.panelLatched = false
        }
    }

    function toggle() {
        if (PillBus.soundOpen) {
            if (PillBus.panelLatched)
                PillBus.close("sound")
            else
                PillBus.panelLatched = true
        } else {
            PillBus.show("sound")
            PillBus.panelLatched = true
        }
    }

    Process {
        id: pavuProc
        command: ["pavucontrol"]
    }

    IpcHandler {
        target: "volume"
        function up() { root.nudge(0.05) }
        function down() { root.nudge(-0.05) }
        function set(percent: int) { root.applyVolume(percent / 100) }
    }

    PanelWindow {
        screen: BarScreen.screen
        id: win

        anchors {
            top: true
            right: true
        }

        margins {
            top: -24
            right: root.rightMargin
        }

        implicitWidth: root.collapsedWidth + PillBus.maxPushSound
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
            // Icon-only now (no hover expansion, so no inline slider); the
            // bluetooth/wifi/battery pills still push it left.
            width: root.collapsedWidth
            // Middle segment of the joined row: square corners.
            radius: 0
            color: "#040404"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function (mouse) {
                    if (mouse.button === Qt.RightButton)
                        pavuProc.running = true
                    else
                        root.toggle()
                }
            }

            HoverHandler {
                id: hover
                // Report the pointer to PillBus instead of opening on the first
                // pixel of hover; the preview opens only after a short rest, so
                // an accidental slide across the row passes through (see
                // PillBus.requestPreview / hoverOpenDelay).
                onHoveredChanged: {
                    if (hovered)
                        PillBus.requestPreview("sound")
                    else
                        PillBus.cancelPreview("sound")
                }
            }

            // Fires once the pointer has rested here long enough.
            Connections {
                target: PillBus
                function onPreviewTickChanged() {
                    if (PillBus.previewName === "sound" && hover.hovered)
                        root.openPreview()
                }
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

            // Pinned to the pill's right edge (as it was while the pill used
            // to expand); the pill is a fixed 27px now.
            Text {
                id: glyphText
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyph
                color: root.muted ? root.mutedColor : root.accent
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }
    }
}
