import QtQuick
import QtQuick.Layouts
import "CalUtil.js" as CalUtil

Rectangle {
    id: row

    property var ev: ({ "title": "", "allDay": false, "location": "", "startTime": "", "endTime": "", "color": "#0A84FF", "calendar": "" })
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color textSecondary: "#98989F"

    readonly property color evColor: ev.color
    readonly property color light: CalUtil.lighten(ev.color, 1.3)
    readonly property bool isBirthday: ("" + ev.calendar).toLowerCase().indexOf("birth") !== -1

    implicitHeight: content.implicitHeight + 16
    radius: 10
    color: CalUtil.tint(ev.color, 0.16)

    RowLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 8

        // Timed event: thin accent bar on the left
        Rectangle {
            visible: !row.ev.allDay
            Layout.preferredWidth: 3
            Layout.fillHeight: true
            Layout.minimumHeight: 32
            radius: 1.5
            color: row.evColor
        }

        // All-day event: rounded icon square
        Rectangle {
            visible: row.ev.allDay
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: 8
            color: CalUtil.tint(row.ev.color, 0.4)

            Text {
                anchors.centerIn: parent
                text: row.isBirthday ? "\uF06B" : "\uF133"
                color: row.light
                font.family: row.fontFamily
                font.pixelSize: 12
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: row.ev.title
                color: row.light
                font.family: row.fontFamily
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                visible: row.ev.location !== ""
                spacing: 3

                Text {
                    text: "\uF276"
                    color: row.textSecondary
                    font.family: row.fontFamily
                    font.pixelSize: 10
                }

                Text {
                    Layout.fillWidth: true
                    text: row.ev.location
                    color: row.textSecondary
                    font.family: row.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 1

            Text {
                Layout.alignment: Qt.AlignRight
                text: row.ev.allDay ? "all-day" : CalUtil.fmt12(row.ev.startTime)
                color: row.ev.allDay ? "#D1D1D6" : row.light
                font.family: row.fontFamily
                font.pixelSize: 12
            }

            Text {
                Layout.alignment: Qt.AlignRight
                visible: !row.ev.allDay && row.ev.endTime !== ""
                text: CalUtil.fmt12(row.ev.endTime)
                color: row.textSecondary
                font.family: row.fontFamily
                font.pixelSize: 12
            }
        }
    }
}
