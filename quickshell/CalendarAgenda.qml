import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    // Array of { label: string, isToday: bool, dayStr: string, events: [] }
    property var sections: []
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color textSecondary: "#98989F"
    property color todayColor: "#FF453A"

    spacing: 16

    Repeater {
        model: root.sections

        delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: modelData.label
                color: modelData.isToday ? root.todayColor : root.textSecondary
                font.family: root.fontFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1.5
            }

            Text {
                Layout.fillWidth: true
                visible: modelData.events.length === 0
                text: "No events"
                color: root.textSecondary
                font.family: root.fontFamily
                font.pixelSize: 11
            }

            Repeater {
                model: modelData.events

                delegate: EventRow {
                    Layout.fillWidth: true
                    fontFamily: root.fontFamily
                    textSecondary: root.textSecondary
                    ev: modelData
                }
            }
        }
    }
}
