import QtQuick
import QtQuick.Layouts
import "CalUtil.js" as CalUtil

Item {
    id: root

    property int viewYear: 2000
    property int viewMonth: 0
    property var events: []
    property string selectedDay: ""
    property string todayStr: ""
    property var cells: []

    signal dayClicked(string dayStr)

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string textSecondary: "#98989F"
    readonly property string todayColor: "#FF453A"
    readonly property string otherMonthColor: "#48484A"

    implicitHeight: header.implicitHeight + grid.implicitHeight + 4

    function rebuild() {
        var first = new Date(root.viewYear, root.viewMonth, 1)
        var lead = first.getDay()
        var dim = new Date(root.viewYear, root.viewMonth + 1, 0).getDate()
        var rows = Math.ceil((lead + dim) / 7)
        var start = CalUtil.addDays(first, -lead)
        var out = []
        for (var i = 0; i < rows * 7; i++) {
            var d = CalUtil.addDays(start, i)
            var ds = CalUtil.fmtDate(d)
            out.push({
                "ds": ds,
                "num": d.getDate(),
                "inMonth": d.getMonth() === root.viewMonth,
                "isToday": ds === root.todayStr,
                "isSelected": ds === root.selectedDay,
                "items": CalUtil.eventsOn(root.events, ds)
            })
        }
        root.cells = out
    }

    onViewYearChanged: rebuild()
    onViewMonthChanged: rebuild()
    onEventsChanged: rebuild()
    onTodayStrChanged: rebuild()
    onSelectedDayChanged: rebuild()
    Component.onCompleted: rebuild()

    RowLayout {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]

            delegate: Text {
                Layout.fillWidth: true
                text: modelData
                color: root.textSecondary
                font.family: root.fontFamily
                font.pixelSize: 10
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    GridLayout {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        columns: 7
        rowSpacing: 2
        columnSpacing: 0

        Repeater {
            model: root.cells

            delegate: Item {
                id: cell

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 72

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dayClicked(cell.modelData.ds)
                }

                Rectangle {
                    id: numCircle
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: cell.modelData.isToday ? root.todayColor : (cell.modelData.isSelected ? "#3A3A3C" : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.num
                        color: cell.modelData.isToday ? "#FFFFFF" : (cell.modelData.inMonth ? "#FFFFFF" : root.otherMonthColor)
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        font.bold: cell.modelData.isToday || cell.modelData.isSelected
                    }
                }

                Column {
                    anchors.top: numCircle.bottom
                    anchors.topMargin: 2
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 2

                    Repeater {
                        model: cell.modelData.items.slice(0, 3)

                        delegate: Rectangle {
                            required property var modelData

                            x: 2
                            width: parent.width - 4
                            height: 13
                            radius: 3.5
                            color: CalUtil.tint(modelData.color, 0.32)

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 3
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.title
                                color: CalUtil.lighten(modelData.color, 1.35)
                                font.family: root.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
