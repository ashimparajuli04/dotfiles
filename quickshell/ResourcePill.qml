import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The CPU + RAM pill, a Quickshell overlay just like the brightness / sound /
// bluetooth / wifi / battery pills. It sits on the transparent `custom/system`
// Waybar spacer and is now its OWN standalone, fully-rounded pill: a 10px gap
// separates it from the icon row to its right (that row reads left → right:
// brightness · sound · bluetooth · wifi · battery · powermenu; see PillBus.qml).
// It used to be the left cap of that joined row.
//
// It does NOT expand on hover (like the wifi/bluetooth pills): both values are
// always visible. Left-click opens btop in a floating kitty window (app_id
// "btop"; the float/centre rule lives in sway/config).
//
// Values are read in-process: /proc/stat (CPU, delta between samples) and
// /proc/meminfo (MemAvailable/MemTotal), reloaded once a second. No per-second
// process spawn, matching the brightness pill's sysfs read and the wifi pill's
// /proc/net/wireless read (see changes.md).
Scope {
    id: root

    // Every icon in the row is a different colour. CPU = nord purple,
    // RAM = nord green — both unused by the other pills.
    readonly property color cpuColor: "#b48ead"
    readonly property color ramColor: "#a3be8c"

    // ---------- geometry ----------
    // Standalone, fully-rounded pill. It hugs its content with the same 7px
    // horizontal padding as the icon-only pills (27px = 13px glyph + 2×7), so
    // the "excess" either side of the glyphs matches theirs. The width is
    // content-driven — but it stays constant because the percentage fields are
    // fixed-width (below), so the pill never jiggles.
    //
    // rightMargin 180 = 170 (the brightness pill's left edge = its 143
    // rightMargin + 27 width) + 10 (the gap to the icon row), so a 10px gap
    // sits between this pill and the brightness pill. Tuned with screenshots —
    // see changes.md.
    readonly property int padH: 7
    readonly property int collapsedWidth: contentRow.implicitWidth + root.padH * 2
    readonly property int rightMargin: 180      // screen right edge → window right edge
    readonly property int pillHeight: 24
    // Fixed-width percentage field so "9%" and "99%" don't shift the glyphs.
    // Sized for three monospace characters ("00%") — it only grows on the rare
    // "100%" reading (see the Text width below). Was 33 (four chars), which
    // reserved a whole extra digit and left a large gap before the RAM glyph
    // for short values like "9%".
    readonly property int pctWidth: 24

    // ---------- state ----------
    property int cpuPercent: 0
    property int memPercent: 0

    // CPU is a rate, and /proc/stat holds cumulative counters — so a single
    // read has no percentage. prev* keep the last sample; the first read only
    // primes them (cpuPercent stays 0 until the second sample lands 1s later).
    property real prevIdle: -1
    property real prevTotal: -1

    // Material Design Icons: CPU = chip (\uF061A), RAM = memory (\uF035B).
    // cpu-64-bit (\uF0EE0) was the original CPU glyph, but its tiny "64" label
    // smears into a blob at 13px — the plain chip reads cleanly. Plane-15
    // codepoints use surrogate pairs: a 5-hex-digit \u escape is invalid in JS
    // and truncates to a 4-digit glyph + a literal character, so these are
    // written as UTF-16 surrogate pairs (like BrightnessPill.qml).
    readonly property string cpuGlyph: "\udb81\ude1a"
    readonly property string ramGlyph: "\udb80\udf5b"

    FileView {
        id: statView
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.applyStat(statView.text())
    }

    FileView {
        id: memView
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.applyMem(memView.text())
    }

    function applyStat(text) {
        // First line: "cpu user nice system idle iowait irq softirq steal ..."
        var f = String(text).split("\n")[0].trim().split(/\s+/)
        if (f.length < 8 || f[0] !== "cpu")
            return
        var v = []
        for (var i = 1; i < f.length; i++)
            v.push(parseInt(f[i]) || 0)
        // idle = idle + iowait; every other field is busy time.
        var idle = v[3] + v[4]
        var total = 0
        for (var j = 0; j < v.length; j++)
            total += v[j]
        if (root.prevTotal >= 0 && total > root.prevTotal) {
            var dTotal = total - root.prevTotal
            var dIdle = idle - root.prevIdle
            root.cpuPercent = Math.max(0, Math.min(100,
                Math.round((dTotal - dIdle) / dTotal * 100)))
        }
        root.prevIdle = idle
        root.prevTotal = total
    }

    function applyMem(text) {
        var m = String(text)
        var total = /MemTotal:\s+(\d+)/.exec(m)
        var avail = /MemAvailable:\s+(\d+)/.exec(m)
        if (total && avail && parseInt(total[1]) > 0) {
            root.memPercent = Math.max(0, Math.min(100,
                Math.round((1 - parseInt(avail[1]) / parseInt(total[1])) * 100)))
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statView.reload()
            memView.reload()
        }
    }

    // Left-click launches btop in a floating kitty window.
    Process {
        id: btopProc
        command: ["kitty", "--class", "btop", "-e", "btop"]
    }

    // Publish "pointer is on the pill" so PillBus keeps the row from collapsing
    // under the cursor while resting here (same as the other pills).
    Binding {
        target: PillBus
        property: "hoverSystem"
        value: hover.hovered
    }

    IpcHandler {
        target: "system"
        function btop() { btopProc.running = true }
        function refresh() { statView.reload(); memView.reload() }
    }

    PanelWindow {
        screen: BarScreen.screen
        id: win

        // Fullscreen on this output hides the whole bar (see FullscreenWatch).
        visible: !FullscreenWatch.covering

        anchors {
            top: true
            right: true
        }

        margins {
            top: -24
            right: root.rightMargin
        }

        implicitWidth: root.collapsedWidth + PillBus.maxReach
        implicitHeight: root.pillHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:system-pill"

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
            // Slides left with the icon row while anything to its right
            // expands (PillBus.reach = brightness + sound + bt + wifi + battery
            // deltas), so it keeps its 10px gap instead of being overlapped.
            x: win.width - width - PillBus.reach
            height: root.pillHeight
            width: root.collapsedWidth
            // Standalone pill: rounded on every corner (the 10px gap on the
            // right sets it apart from the icon row).
            radius: 8
            color: "#040404"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: btopProc.running = true
            }

            HoverHandler {
                id: hover
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.cpuGlyph
                    color: root.cpuColor
                    // The row's glyphs come from Material Design Icons (like
                    // the battery / wifi / bluetooth pills).
                    font.family: "Material Design Icons"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.cpuPercent + "%"
                    color: root.cpuColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignLeft
                    // Normally the fixed pctWidth; only "100%" widens it, so
                    // the extra digit can't run into the RAM glyph. The gap to
                    // the RAM group is just the Row spacing.
                    width: Math.max(root.pctWidth, implicitWidth)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.ramGlyph
                    color: root.ramColor
                    font.family: "Material Design Icons"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.memPercent + "%"
                    color: root.ramColor
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignLeft
                    width: Math.max(root.pctWidth, implicitWidth)
                }
            }
        }
    }
}
