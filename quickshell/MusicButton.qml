import QtQuick

// Icon button for the music widget: square, 2px dark border, dark glyph.
// `active` inverts the button (dark fill, pink glyph) for on-states like
// shuffle / repeat / play.
Rectangle {
    id: root

    property string glyph: ""
    property bool active: false
    property int glyphSize: 15

    signal clicked()

    implicitWidth: 34
    implicitHeight: 25
    radius: 0
    color: root.active
        ? MusicStyle.fg
        : (hover.hovered ? Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.12) : "transparent")
    border.width: 2
    border.color: MusicStyle.border

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.active ? MusicStyle.bg : MusicStyle.fg
        font.family: MusicStyle.fontFamily
        font.pixelSize: root.glyphSize
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
