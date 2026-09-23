import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "CalUtil.js" as CalUtil

// The full calendar popover (month grid + header + selected-day agenda).
// Extracted from CalendarPanel.qml so it can be lazy-loaded — built on first
// open and destroyed on close. It reads state and callbacks from its owning
// CalendarPanel through `panel` (single reference, no prop-drilling); the chip,
// clock and hover card stay eager in CalendarPanel because they need the data
// too. See changes.md §41.
PanelWindow {
    id: popup

    property var panel: null

    visible: panel.popupOpen

    anchors {
        top: true
    }

    margins {
        top: 4
        left: popup.screen ? Math.round((popup.screen.width - popup.implicitWidth) / 2) : 0
    }

    implicitWidth: 460
    implicitHeight: popupFrame.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:calendar-popup"
    WlrLayershell.keyboardFocus: panel.popupOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Rectangle {
        id: popupFrame
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: popupCol.implicitHeight + 28
        radius: 18
        color: panel.monthBg
        border.width: 1
        border.color: panel.cardBorder
        focus: true

        onVisibleChanged: if (visible)
            forceActiveFocus()

        Keys.onEscapePressed: panel.hidePopup()

        ColumnLayout {
            id: popupCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 10

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PillButton {
                    glyph: "\uF053"
                    fontFamily: panel.fontFamily
                    bgColor: panel.pillBg
                    hoverColor: panel.pillHover
                    textColor: panel.textPrimary
                    onClicked: panel.shiftMonth(-1)
                }

                Text {
                    Layout.fillWidth: true
                    text: CalUtil.monthName(panel.viewMonth) + " " + panel.viewYear
                    color: panel.textPrimary
                    font.family: panel.fontFamily
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                PillButton {
                    glyph: "\uF054"
                    fontFamily: panel.fontFamily
                    bgColor: panel.pillBg
                    hoverColor: panel.pillHover
                    textColor: panel.textPrimary
                    onClicked: panel.shiftMonth(1)
                }

                PillButton {
                    label: "Today"
                    fontFamily: panel.fontFamily
                    bgColor: panel.pillBg
                    hoverColor: panel.pillHover
                    textColor: panel.textPrimary
                    onClicked: panel.goToday()
                }

                PillButton {
                    glyph: "\uF021"
                    fontSize: 13
                    spinning: panel.syncing
                    alert: panel.syncError !== ""
                    fontFamily: panel.fontFamily
                    bgColor: panel.pillBg
                    hoverColor: panel.pillHover
                    textColor: panel.textPrimary
                    alertColor: panel.red
                    onClicked: panel.doSync()
                }
            }

            // ---- month grid ----
            CalendarMonth {
                Layout.fillWidth: true
                viewYear: panel.viewYear
                viewMonth: panel.viewMonth
                // Grid uses monthEvents only: reloadMonth() already fetches the
                // whole visible grid range, so keying it off mergedEvents made
                // every 5-min hover refresh rebuild all 42 cells for no visible
                // change. The hover card/agenda still use mergedEvents.
                events: panel.monthEvents
                selectedDay: CalUtil.fmtDate(panel.selectedDate)
                todayStr: panel.todayStr
                onDayClicked: function (ds) { panel.selectDay(ds) }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: panel.cardBorder
            }

            Text {
                Layout.fillWidth: true
                visible: panel.syncError !== ""
                text: panel.syncError
                color: panel.red
                font.family: panel.fontFamily
                font.pixelSize: 10
            }

            // ---- selected day agenda ----
            Flickable {
                id: popupFlick
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(popupAgenda.implicitHeight, 240)
                contentWidth: width
                contentHeight: popupAgenda.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                CalendarAgenda {
                    id: popupAgenda
                    width: popupFlick.width
                    fontFamily: panel.fontFamily
                    textSecondary: panel.textSecondary
                    todayColor: panel.red
                    sections: panel.popupSections
                }
            }
        }
    }
}
