import QtQuick

// Small rounded pill button for the calendar popup header (prev / next /
// today / refresh). Collapsed it is a 28px circle; give it a `label` and it
// widens to fit. `spinning` drives the glyph's rotation (refresh in progress),
// `alert` turns the glyph red (sync error). Replaces four hand-copied
// Rectangles that shared this exact structure.
Rectangle {
    id: btn

    property string glyph: ""
    property string label: ""
    property bool spinning: false
    property bool alert: false
    property int fontSize: 11

    property string fontFamily: "JetBrainsMono Nerd Font"
    property color bgColor: "#2C2C2E"
    property color hoverColor: "#3A3A3C"
    property color textColor: "#FFFFFF"
    property color alertColor: "#FF453A"

    signal clicked

    implicitWidth: label !== "" ? labelText.implicitWidth + 22 : 28
    implicitHeight: 28
    radius: 14
    color: (hover.hovered || btn.spinning) ? btn.hoverColor : btn.bgColor

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent

        onClicked: btn.clicked()
    }

    Text {
        id: glyphText

        anchors.centerIn: parent
        visible: btn.glyph !== ""
        text: btn.glyph
        color: btn.alert ? btn.alertColor : btn.textColor
        font.family: btn.fontFamily
        font.pixelSize: btn.fontSize

        NumberAnimation on rotation {
            running: btn.spinning
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite

            onRunningChanged: if (!running)
                glyphText.rotation = 0
        }
    }

    Text {
        id: labelText

        anchors.centerIn: parent
        visible: btn.label !== ""
        text: btn.label
        color: btn.textColor
        font.family: btn.fontFamily
        font.pixelSize: btn.fontSize
    }
}
