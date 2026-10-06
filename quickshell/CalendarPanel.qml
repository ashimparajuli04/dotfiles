import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "CalUtil.js" as CalUtil

Scope {
    id: root

    // ---------- appearance ----------
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property color red: "#FF453A"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#98989F"
    readonly property color cardBg: Theme.bg
    readonly property color cardBorder: "#2C2C2E"
    readonly property color pillBg: "#2C2C2E"
    readonly property color pillHover: "#3A3A3C"
    readonly property color monthBg: Theme.bg
    readonly property color chipBg: "#040404"

    // ---------- state ----------
    property var hoverEvents: []
    property var monthEvents: []
    property var mergedEvents: []
    property string nowLabel: ""
    property string todayStr: ""
    property date selectedDate: new Date()
    property int viewYear: 2000
    property int viewMonth: 0
    property bool cardVisible: false
    property bool popupOpen: false
    property bool syncing: false
    property string syncError: ""

    readonly property var khalJsonFields: [
        "title", "start-date", "end-date", "start-time-full", "end-time-full",
        "all-day", "location", "calendar", "calendar-color", "description", "uid"
    ]

    // ---------- data ----------
    function khalCmd(from, to) {
        var cmd = ["khal", "list"]
        for (var i = 0; i < root.khalJsonFields.length; i++) {
            cmd.push("--json")
            cmd.push(root.khalJsonFields[i])
        }
        cmd.push(from)
        cmd.push(to)
        return cmd
    }

    function dstr(offset) {
        return CalUtil.fmtDate(CalUtil.addDays(new Date(), offset))
    }

    function refreshClock() {
        root.nowLabel = CalUtil.nowStamp()
    }

    function reloadHover() {
        hoverProc.command = root.khalCmd(root.dstr(0), root.dstr(12))
        hoverProc.running = true
    }

    function reloadMonth() {
        var first = new Date(root.viewYear, root.viewMonth, 1)
        var lead = first.getDay()
        var dim = new Date(root.viewYear, root.viewMonth + 1, 0).getDate()
        var rows = Math.ceil((lead + dim) / 7)
        var start = CalUtil.addDays(first, -lead)
        var end = CalUtil.addDays(start, rows * 7)
        monthProc.command = root.khalCmd(CalUtil.fmtDate(start), CalUtil.fmtDate(end))
        monthProc.running = true
    }

    function recompute() {
        root.todayStr = CalUtil.fmtDate(new Date())
        root.mergedEvents = CalUtil.dedupe(root.hoverEvents.concat(root.monthEvents))
    }

    readonly property var cardSections: {
        var out = []
        for (var i = 0; i < 10 && out.length < 4; i++) {
            var ds = root.dstr(i)
            var evs = CalUtil.eventsOn(root.mergedEvents, ds)
            if (evs.length === 0)
                continue
            var label = i === 0 ? CalUtil.dayHeader(ds) : (i === 1 ? "TOMORROW" : CalUtil.dayHeader(ds))
            out.push({ "label": label, "isToday": i === 0, "dayStr": ds, "events": evs })
        }
        return out
    }

    readonly property var popupSections: [{
        "label": CalUtil.dayHeader(CalUtil.fmtDate(root.selectedDate)),
        "isToday": CalUtil.fmtDate(root.selectedDate) === root.todayStr,
        "dayStr": CalUtil.fmtDate(root.selectedDate),
        "events": CalUtil.eventsOn(root.mergedEvents, CalUtil.fmtDate(root.selectedDate))
    }]

    // ---------- interactions ----------
    function openCard() {
        if (root.popupOpen)
            return
        closeTimer.stop()
        root.cardVisible = true
    }

    function scheduleCloseCard() {
        closeTimer.restart()
    }

    function showPopup() {
        root.todayStr = CalUtil.fmtDate(new Date())
        root.selectedDate = new Date()
        root.viewYear = root.selectedDate.getFullYear()
        root.viewMonth = root.selectedDate.getMonth()
        root.popupOpen = true
        root.cardVisible = false
        closeTimer.stop()
        root.reloadMonth()
    }

    function hidePopup() {
        root.popupOpen = false
    }

    function togglePopup() {
        if (root.popupOpen)
            root.hidePopup()
        else
            root.showPopup()
    }

    function selectDay(ds) {
        var d = CalUtil.parseDate(ds)
        root.selectedDate = d
        if (d.getFullYear() !== root.viewYear || d.getMonth() !== root.viewMonth) {
            root.viewYear = d.getFullYear()
            root.viewMonth = d.getMonth()
            root.reloadMonth()
        }
    }

    function shiftMonth(delta) {
        var m = root.viewMonth + delta
        var y = root.viewYear
        if (m < 0) {
            m = 11
            y--
        } else if (m > 11) {
            m = 0
            y++
        }
        root.viewYear = y
        root.viewMonth = m
        root.reloadMonth()
    }

    function goToday() {
        root.todayStr = CalUtil.fmtDate(new Date())
        root.selectedDate = new Date()
        root.viewYear = root.selectedDate.getFullYear()
        root.viewMonth = root.selectedDate.getMonth()
        root.reloadMonth()
    }

    function doSync() {
        if (root.syncing)
            return
        root.syncing = true
        root.syncError = ""
        syncProc.running = true
    }

    // ---------- processes ----------
    Process {
        id: hoverProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.hoverEvents = CalUtil.parseKhal(text)
                root.recompute()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.log("[calendar] khal(hover): " + text.trim())
        }
    }

    Process {
        id: monthProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.monthEvents = CalUtil.parseKhal(text)
                root.recompute()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.log("[calendar] khal(month): " + text.trim())
        }
    }

    Process {
        id: syncProc

        command: ["vdirsyncer", "sync"]

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.log("[calendar] sync: " + text.trim())
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.log("[calendar] sync err: " + text.trim())
        }

        onExited: function (exitCode, exitStatus) {
            root.syncing = false
            if (exitCode !== 0)
                root.syncError = "Sync failed (exit " + exitCode + ")"
            root.reloadHover()
            if (root.popupOpen)
                root.reloadMonth()
        }
    }

    // ---------- timers ----------
    Timer {
        id: clockTimer
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refreshClock()
    }

    Timer {
        id: slowTimer
        interval: 300000
        running: true
        repeat: true
        onTriggered: {
            root.refreshClock()
            root.reloadHover()
            if (root.popupOpen)
                root.reloadMonth()
        }
    }

    Timer {
        id: closeTimer
        // 0 ms: hide on the next event-loop tick (no visible linger). The
        // zero interval is still cancellable in the same tick, so a pointer
        // move from the chip onto the card cancels the close as before.
        interval: 0
        repeat: false
        onTriggered: root.cardVisible = false
    }

    Component.onCompleted: {
        root.refreshClock()
        root.todayStr = CalUtil.fmtDate(new Date())
        root.reloadHover()
    }

    // ---------- ipc ----------
    IpcHandler {
        target: "calendar"

        function toggle() { root.togglePopup() }
        function open() { root.showPopup() }
        function hide() { root.hidePopup() }
        function refresh() { root.doSync() }
        function showcard() { root.openCard() }
        function hidecard() { root.cardVisible = false }
    }

    // ---------- clock chip (top bar) ----------
    PanelWindow {
        screen: BarScreen.screen
        id: chip

        anchors {
            top: true
        }

        margins {
            top: -24
            left: chip.screen ? Math.round((chip.screen.width - chip.implicitWidth) / 2) : 0
        }

        implicitWidth: chipRow.implicitWidth + 22
        implicitHeight: 24
        color: "transparent"
        exclusiveZone: 0

        // Overlay: Waybar sits on the Top layer and would cover the chip there.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:calendar-chip"

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.chipBg

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 0

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: chipMetrics.width
                    text: root.nowLabel
                    color: root.textPrimary
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        TextMetrics {
            id: chipMetrics
            font.family: root.fontFamily
            font.pixelSize: 13
            font.bold: true
            text: "Wed 30 · 12:51 PM"
        }

        HoverHandler {
            onHoveredChanged: hovered ? root.openCard() : root.scheduleCloseCard()
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePopup()
        }
    }

    // ---------- click catcher (closes popup) ----------
    PanelWindow {
        screen: BarScreen.screen
        id: catcher
        visible: root.popupOpen

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        margins {
            top: 1
        }

        color: "transparent"
        exclusiveZone: 0

        // Catcher on Top, popup on Overlay: this guarantees the popup is above
        // the catcher, otherwise every click in the popup would close it.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:calendar-catcher"

        MouseArea {
            anchors.fill: parent
            onClicked: root.hidePopup()
        }
    }

    // ---------- hover card ----------
    PanelWindow {
        screen: BarScreen.screen
        id: card
        visible: root.cardVisible

        anchors {
            top: true
        }

        margins {
            top: 4
            left: card.screen ? Math.round((card.screen.width - card.implicitWidth) / 2) : 0
        }

        implicitWidth: 400
        implicitHeight: cardFrame.implicitHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:calendar-card"

        Rectangle {
            id: cardFrame
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: cardCol.implicitHeight + 26
            radius: 16
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder

            ColumnLayout {
                id: cardCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 13
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    visible: root.cardSections.length === 0
                    text: "No upcoming events"
                    color: root.textSecondary
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(cardAgenda.implicitHeight, 500)
                    contentWidth: width
                    contentHeight: cardAgenda.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    CalendarAgenda {
                        id: cardAgenda
                        width: parent.width
                        fontFamily: root.fontFamily
                        textSecondary: root.textSecondary
                        todayColor: root.red
                        sections: root.cardSections
                    }
                }
            }

            HoverHandler {
                onHoveredChanged: hovered ? root.openCard() : root.scheduleCloseCard()
            }
        }
    }


    // ---------- full calendar popup (lazy) ----------
    // Built on first open and destroyed on close; the chip/clock and hover card
    // stay eager because they need the calendar data.
    LazyLoader {
        active: root.popupOpen

        CalendarPopup {
            panel: root
        }
    }
}
