import QtQuick

Item {
    id: slider

    property real value: 0
    signal moved(real v)
    // Fires on every change while dragging; moved() only fires on release.
    signal dragged(real v)

    // Optional theming; the defaults keep the SoundPanel look. The
    // brightness pill overrides these to match the Waybar palette.
    property color trackColor: Theme.bgAlt
    property color fillColor: Theme.accent
    property color knobColor: "#FFFFFF"

    // While dragging, show the local value so the knob doesn't fight
    // live updates coming back from PipeWire.
    readonly property real shown: Math.max(0, Math.min(1, _dragging ? _dragValue : value))

    readonly property bool dragging: _dragging

    property bool _dragging: false
    property real _dragValue: 0

    implicitWidth: 100
    implicitHeight: 22

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: slider.trackColor

        Rectangle {
            width: Math.round(parent.width * slider.shown)
            height: parent.height
            radius: parent.radius
            color: slider.fillColor
        }
    }

    Rectangle {
        id: knob
        width: 12
        height: 12
        radius: 6
        color: slider.knobColor
        y: (slider.height - height) / 2
        x: Math.max(0, Math.min(slider.width - width, Math.round(track.width * slider.shown - width / 2)))
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function apply(mouseX) {
            slider._dragValue = Math.max(0, Math.min(1, mouseX / slider.width))
            if (slider._dragging)
                slider.dragged(slider._dragValue)
        }

        onPressed: function (mouse) {
            slider._dragging = true
            apply(mouse.x)
        }

        onPositionChanged: function (mouse) {
            if (slider._dragging && pressed)
                apply(mouse.x)
        }

        onReleased: function (mouse) {
            if (!slider._dragging)
                return
            apply(mouse.x)
            slider._dragging = false
            slider.moved(slider._dragValue)
        }
    }
}
