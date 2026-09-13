pragma Singleton

// Event-driven MPD client state for the Quickshell music widget.
//
// A single long-lived `mpc idleloop` process reports mpd events; each event
// triggers short `mpc` queries. There is no polling: while playing, elapsed
// time is computed from a wall-clock anchor, so idle CPU is ~0%.
//
// mpc 0.35 notes (verified against the man page and source):
//  - `status` takes a POSITIONAL format string; `-f` is ignored for it.
//  - `|` is an alternation operator in format strings, so `\n` separates keys.
//  - CLI queue positions are 1-based (mpc subtracts 1 before hitting mpd).

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    readonly property string musicDir: "/home/ashim/Music"
    readonly property string lyricsDir: "/home/ashim/.local/share/lyrics"
    readonly property string coverCache: "/tmp/quickshell-music-cover.png"
    readonly property string fallbackCover: "file://" + Quickshell.shellDir + "/assets/fallback.png"

    // ---------- playback state ----------
    property string state: "stopped"       // playing | paused | stopped
    property string artist: ""
    property string title: ""
    property string album: ""
    property string file: ""
    property bool random: false
    property bool repeat: false
    property bool single: false
    property int songPos: 0                // 1-based, 0 = none
    property int queueLength: 0
    property real length: 0                // seconds
    property real elapsed: 0               // seconds, updated by the ticker

    readonly property bool playing: state === "playing"
    readonly property bool hasTrack: file !== ""
    readonly property string displayTitle: title !== "" ? title
        : (file !== "" ? file.replace(/\.[^.\/]+$/, "").replace(/^.*\//, "") : "Nothing playing")
    readonly property string displayArtist: artist !== "" ? artist : (file !== "" ? "Unknown artist" : "mpd")
    readonly property real progress: length > 0 ? Math.min(1, elapsed / length) : 0

    // ---------- lists ----------
    property var queueFiles: []            // in queue order; index i = position i+1
    property var libraryFiles: []          // relative to musicDir, sorted
    property bool libraryLoaded: false

    // ---------- cover ----------
    property string coverPath: fallbackCover
    property int coverRev: 0
    property bool coverBusy: false
    property bool coverPending: false

    // ---------- internals ----------
    property real elapsedBase: 0
    property real anchorWall: 0
    property string pendingPlayFile: ""

    // ================= parsing helpers =================

    function parseKV(text) {
        var map = ({})
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            var eq = line.indexOf("=")
            if (eq > 0)
                map[line.substring(0, eq)] = line.substring(eq + 1)
        }
        return map
    }

    function parseTime(t) {
        if (!t)
            return 0
        var parts = String(t).split(":")
        if (parts.length === 3)
            return parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60 + parseFloat(parts[2])
        if (parts.length === 2)
            return parseInt(parts[0]) * 60 + parseFloat(parts[1])
        return 0
    }

    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0)
            sec = 0
        sec = Math.floor(sec)
        var m = Math.floor(sec / 60)
        var s = sec % 60
        if (m >= 60) {
            var h = Math.floor(m / 60)
            m = m % 60
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        }
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // ================= event plumbing =================

    function onEvent(name) {
        if (name === "player") {
            refreshStatus()
            refreshCurrent()
        } else if (name === "options") {
            refreshStatus()
        } else if (name === "playlist") {
            refreshStatus()   // queue length
            refreshQueue()
        } else if (name === "update") {
            refreshLibrary()
        }
    }

    function refresh() {
        refreshStatus()
        refreshCurrent()
    }

    function refreshStatus() { statusProc.running = true }
    function refreshCurrent() { currentProc.running = true }
    function refreshQueue() { queueProc.running = true }
    function refreshLibrary() { libraryProc.running = true }

    // ================= commands =================

    function exec(args) { Quickshell.execDetached(args) }

    function toggle() { exec(["mpc", "-q", "toggle"]) }
    function next() { exec(["mpc", "-q", "next"]) }
    function previous() { exec(["mpc", "-q", "prev"]) }
    function toggleRandom() { exec(["mpc", "-q", "random"]) }

    function cycleRepeat() {
        if (!root.repeat) {
            exec(["mpc", "-q", "repeat", "on"])
        } else if (!root.single) {
            exec(["mpc", "-q", "single", "on"])
        } else {
            exec(["mpc", "-q", "repeat", "off"])
            exec(["mpc", "-q", "single", "off"])
        }
    }

    function seek(fraction) {
        if (!root.hasTrack)
            return
        exec(["mpc", "-q", "seek", Math.round(Math.max(0, Math.min(1, fraction)) * 100) + "%"])
    }

    function playQueueIndex(i) {
        // i is a 0-based index into queueFiles; mpc positions are 1-based
        exec(["mpc", "-q", "play", String(i + 1)])
    }

    function removeQueueIndex(i) {
        exec(["mpc", "-q", "del", String(i + 1)])
    }

    function queueFile(f) {
        exec(["mpc", "-q", "add", f])
    }

    // Left click in the library: jump to the track if it is already queued,
    // otherwise append it and play it as soon as mpd confirms the addition.
    function playFile(f) {
        var idx = root.queueFiles.indexOf(f)
        if (idx >= 0)
            root.playQueueIndex(idx)
        else {
            root.pendingPlayFile = f
            root.queueFile(f)
        }
    }

    function shuffleAll() {
        exec(["bash", "-c", "mpc clear && mpc add / >/dev/null && mpc random on && mpc play"])
    }

    // ================= processes =================

    // Long-lived event source.
    Process {
        id: idleProc
        command: ["mpc", "idleloop", "player", "options", "playlist", "update"]
        stdout: SplitParser {
            onRead: function (line) { root.onEvent(line) }
        }
        onExited: idleRestart.start()
    }

    Timer {
        id: idleRestart
        interval: 2000
        onTriggered: idleProc.running = true
    }

    Process {
        id: statusProc
        command: ["mpc", "status",
            "ST=%state%\nCT=%currenttime%\nTT=%totaltime%\nSP=%songpos%\nLN=%length%\nRD=%random%\nRP=%repeat%\nSG=%single%"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.log("[music] mpc status: " + text.trim())
        }
    }

    Process {
        id: currentProc
        command: ["mpc", "current", "-f", "AR=%artist%\nTI=%title%\nAL=%album%\nFL=%file%"]
        stdout: StdioCollector {
            onStreamFinished: root.applyCurrent(text)
        }
    }

    Process {
        id: queueProc
        command: ["mpc", "playlist", "-f", "%file%"]
        stdout: StdioCollector {
            onStreamFinished: root.applyQueue(text)
        }
    }

    Process {
        id: libraryProc
        command: ["mpc", "listall"]
        stdout: StdioCollector {
            onStreamFinished: root.applyLibrary(text)
        }
    }

    Process {
        id: coverProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.log("[music] cover ffmpeg: " + text.trim())
        }
        onExited: function (exitCode, exitStatus) {
            root.coverBusy = false
            if (exitCode === 0) {
                root.coverRev++
                root.coverPath = "file://" + root.coverCache + "?v=" + root.coverRev
            } else {
                root.coverPath = root.fallbackCover
            }
            if (root.coverPending) {
                root.coverPending = false
                root.updateCover()
            }
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.playing
        onTriggered: root.elapsed = root.elapsedBase + (Date.now() - root.anchorWall) / 1000
    }

    // ================= apply handlers =================

    function applyStatus(text) {
        var map = root.parseKV(text)
        var st = map["ST"]
        root.state = (st === "playing" || st === "paused") ? st : "stopped"
        root.length = root.parseTime(map["TT"])
        var ct = root.parseTime(map["CT"])
        root.elapsedBase = ct
        root.anchorWall = Date.now()
        root.elapsed = ct
        root.songPos = parseInt(map["SP"]) || 0
        root.queueLength = parseInt(map["LN"]) || 0
        root.random = map["RD"] === "on"
        root.repeat = map["RP"] === "on"
        root.single = map["SG"] === "on" || map["SG"] === "once"
    }

    function applyCurrent(text) {
        var map = root.parseKV(text)
        root.artist = map["AR"] || ""
        root.title = map["TI"] || ""
        root.album = map["AL"] || ""
        var f = map["FL"] || ""
        if (f !== root.file) {
            root.file = f
            root.updateCover()
        }
    }

    function applyQueue(text) {
        var t = text.replace(/\n$/, "")
        root.queueFiles = t === "" ? [] : t.split("\n")
        if (root.pendingPlayFile !== "") {
            var idx = root.queueFiles.indexOf(root.pendingPlayFile)
            if (idx >= 0) {
                root.pendingPlayFile = ""
                root.playQueueIndex(idx)
            }
        }
    }

    function applyLibrary(text) {
        var t = text.replace(/\n$/, "")
        var arr = t === "" ? [] : t.split("\n")
        arr.sort(function (a, b) { return a.toLowerCase().localeCompare(b.toLowerCase()) })
        root.libraryFiles = arr
        root.libraryLoaded = true
    }

    // ================= cover extraction =================

    function updateCover() {
        if (root.file === "") {
            root.coverPath = root.fallbackCover
            root.coverPending = false
            return
        }
        if (root.coverBusy) {
            root.coverPending = true
            return
        }
        root.coverBusy = true
        coverProc.command = ["ffmpeg", "-y", "-loglevel", "error",
            "-i", root.musicDir + "/" + root.file, root.coverCache]
        coverProc.running = true
    }

    // ================= startup =================

    Component.onCompleted: {
        idleProc.running = true
        refresh()
        refreshQueue()
        refreshLibrary()
    }
}
