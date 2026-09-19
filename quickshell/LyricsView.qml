import QtQuick
import Quickshell
import Quickshell.Io

// Time-synced lyrics for the music widget: a rolling window centred on the
// currently playing line (Apple Music style), fed by the same wall-clock
// elapsed time that drives the progress bar — no polling, no helper process.
//
// Port of the former scripts/lyrics-view helper: reads
// ~/.local/share/lyrics/<stem>.lrc and falls back to the Genius plain text
// at ~/Music/.lyrics/lyrics.txt.
Item {
    id: root

    property var lines: []          // [{ t: seconds, text: string }]
    property int activeIdx: -1
    property bool useLrc: false
    property string fallbackText: ""

    // ================= LRC parsing =================

    function parseLrc(content) {
        var out = []
        var offset = 0
        var rows = content.split("\n")
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            var om = row.match(/^\[offset:([+-]?\d+)\]/)
            if (om) {
                offset = parseInt(om[1]) / 1000
                continue
            }
            if (/^\[(ti|ar|al|by|re|ve|length|offset):/.test(row))
                continue
            var tsre = /\[(\d+):(\d+(?:\.\d+)?)\]/g
            var times = []
            var m
            while ((m = tsre.exec(row)) !== null)
                times.push(parseInt(m[1]) * 60 + parseFloat(m[2]) + offset)
            if (times.length === 0)
                continue
            var txt = row.replace(/\[(\d+):(\d+(?:\.\d+)?)\]/g, "").trim()
            for (var j = 0; j < times.length; j++)
                out.push({ t: times[j], text: txt })
        }
        out.sort(function (a, b) { return a.t - b.t })
        return out
    }

    function findActive(pos) {
        var idx = -1
        for (var i = 0; i < root.lines.length; i++) {
            if (root.lines[i].t <= pos)
                idx = i
            else
                break
        }
        return idx
    }

    function updateActive() {
        if (root.useLrc)
            root.activeIdx = root.findActive(MusicState.elapsed)
    }

    function updateForTrack() {
        var stem = MusicState.file.replace(/^.*\//, "").replace(/\.[^.]+$/, "")
        if (stem !== "") {
            root.useLrc = true
            lrcFile.path = MusicState.lyricsDir + "/" + stem + ".lrc"
        } else {
            root.useLrc = false
            root.lines = []
            root.activeIdx = -1
        }
    }

    Connections {
        target: MusicState
        function onFileChanged() { root.updateForTrack() }
        function onElapsedChanged() { root.updateActive() }
    }

    // Per-track timed lyrics.
    FileView {
        id: lrcFile
        watchChanges: true
        printErrors: false
        onTextChanged: if (root.useLrc) {
            root.lines = root.parseLrc(lrcFile.text())
            root.updateActive()
        }
        onLoadFailed: function (error) {
            root.useLrc = false
            root.lines = []
            root.activeIdx = -1
        }
        onFileChanged: lrcFile.reload()
    }

    // Genius plain-text fallback, rewritten by mpd-lyricsd on track change.
    FileView {
        id: fallbackFile
        path: MusicState.musicDir + "/.lyrics/lyrics.txt"
        watchChanges: true
        printErrors: false
        onTextChanged: root.fallbackText = fallbackFile.text()
        onFileChanged: fallbackFile.reload()
    }

    // ================= rolling window =================

    ListView {
        id: lyricList
        anchors.fill: parent
        visible: root.useLrc && root.lines.length > 0
        model: root.lines
        clip: true
        spacing: 3
        interactive: false
        currentIndex: root.activeIdx >= 0 ? root.activeIdx : 0

        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Center)

        delegate: Text {
            required property var modelData
            required property int index

            width: lyricList.width
            horizontalAlignment: Text.AlignLeft
            text: (index === root.activeIdx ? "▶ " : "  ") + modelData.text
            color: index === root.activeIdx ? MusicStyle.bg : MusicStyle.lyrics
            font.family: MusicStyle.fontFamily
            font.pixelSize: 13
            font.bold: index === root.activeIdx
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    // ================= plain-text fallback =================

    Flickable {
        id: fallbackFlick
        anchors.fill: parent
        visible: !root.useLrc || root.lines.length === 0
        contentWidth: width
        contentHeight: fallbackTextItem.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Text {
            id: fallbackTextItem
            width: fallbackFlick.width
            text: root.fallbackText !== "" ? root.fallbackText : "No lyrics"
            color: MusicStyle.lyrics
            font.family: MusicStyle.fontFamily
            font.pixelSize: 13
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }
    }

    Component.onCompleted: root.updateForTrack()
}
