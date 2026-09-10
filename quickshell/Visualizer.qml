import QtQuick
import Quickshell
import Quickshell.Io

// Neon cava spectrum strip.
//
// One long-lived cava process (cava.conf) emits raw ascii frames: each line
// is ';'-separated 0..100 values. Bars are plain solid-colour Rectangles so a
// frame only updates item geometry in the scene graph (no Canvas repaints,
// no per-bar gradients — all bars batch into one draw call).
//
// Frames are dropped while the spectrum is silent: after 2 s of zeros no new
// frame is pushed to the UI, so an idle/paused player costs no repaints at
// all. As soon as sound returns, updates resume.
Item {
    id: root

    property var values: []
    property bool idle: true
    property int barGap: 1
    readonly property int barCount: Math.max(1, root.values.length)
    readonly property real barWidth: Math.max(1, (width - (root.barCount - 1) * root.barGap) / root.barCount)

    readonly property string cavaConfig: Quickshell.shellDir + "/cava.conf"

    function pushFrame(v) {
        var peak = 0
        for (var i = 0; i < v.length; i++) {
            var n = parseInt(v[i]) || 0
            if (n > peak)
                peak = n
        }
        if (peak > 0) {
            root.idle = false
            silenceTimer.stop()
            root.values = v
        } else if (!root.idle) {
            // keep decaying bars visible briefly, then freeze the repaints
            root.values = v
            silenceTimer.restart()
        }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", root.cavaConfig]
        running: true
        stdout: SplitParser {
            onRead: function (line) {
                if (line === "")
                    return
                var v = line.split(";")
                if (v.length > 0 && v[v.length - 1] === "")
                    v.pop()
                root.pushFrame(v)
            }
        }
        onExited: cavaRestart.start()
    }

    Timer {
        id: cavaRestart
        interval: 2000
        onTriggered: cavaProc.running = true
    }

    Timer {
        id: silenceTimer
        interval: 2000
        onTriggered: {
            root.values = []
            root.idle = true
        }
    }

    Item {
        id: bars
        anchors.fill: parent

        Repeater {
            model: root.values.length

            Rectangle {
                required property int index

                readonly property real level: Math.min(100, Math.max(0, parseInt(root.values[index]) || 0)) / 100

                x: index * (root.barWidth + root.barGap)
                y: bars.height - height
                width: root.barWidth
                height: Math.max(1, level * bars.height * 0.95)

                color: {
                    var t = root.barCount > 1 ? index / (root.barCount - 1) : 0
                    return Qt.rgba(
                        MusicStyle.neonA.r + (MusicStyle.neonB.r - MusicStyle.neonA.r) * t,
                        MusicStyle.neonA.g + (MusicStyle.neonB.g - MusicStyle.neonA.g) * t,
                        MusicStyle.neonA.b + (MusicStyle.neonB.b - MusicStyle.neonA.b) * t,
                        1)
                }
            }
        }
    }
}
