import QtQuick

Rectangle {
    id: sw

    property bool checked: false
    signal toggled()

    implicitWidth: 42
    implicitHeight: 22
    radius: height / 2
    color: sw.checked ? Theme.accent : Theme.bgAlt

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Rectangle {
        id: knob
        width: 16
        height: 16
        radius: 8
        color: "#FFFFFF"
        y: (sw.height - height) / 2
        x: sw.checked ? sw.width - width - 3 : 3

        Behavior on x {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
