pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history backend for the clipboard popover.
//
// cliphist (extra/cliphist) owns the history: a `wl-paste --watch cliphist
// store` process (systemd/user/cliphist-watch.service) appends every new
// clipboard selection to ~/.cache/cliphist/db. We only read it:
//   cliphist list              -> "<id>\t<preview>" per line, newest first
//   cliphist decode <id>       -> raw bytes (piped to wl-copy)
//   cliphist list | ... | cliphist delete  -> remove matching entries
//   cliphist wipe              -> clear the history
//
// Quickshell's own Quickshell.clipboardText is NOT used here: under Wayland it
// is empty unless a Quickshell window is focused, so it cannot observe the
// clipboard globally. cliphist (over wl-clipboard's wlr-data-control support)
// can. See ClipboardPanel.qml.
Scope {
    id: hist

    // [{ id: string, preview: string, isImage: bool, mime: string }]
    property var entries: []

    // Image thumbnails, id -> decoded file path. Reassigned (not mutated) so
    // the panel's bindings re-evaluate as each decode finishes.
    property var thumbs: ({})

    // Where decoded image previews are cached (per-shell cache dir).
    readonly property string cacheDir: Quickshell.cachePath("clipboard")

    // Only decode the newest few images; older ones stay as text rows.
    readonly property int thumbCap: 30

    // ---- thumbnail decode queue (one cliphist decode at a time) ----
    property var queue: []
    property var current: null

    function entryById(id) {
        for (var i = 0; i < hist.entries.length; i++) {
            if (hist.entries[i].id === id)
                return hist.entries[i]
        }
        return null
    }

    // cliphist's binary preview is "[[ binary data 117 B png 40x30 ]]", so the
    // format token (png/jpeg/…) is the only MIME hint available. Map the ones
    // wl-copy understands; anything else is restored as raw text.
    function mimeFor(format) {
        switch (String(format).toLowerCase()) {
        case "png": return "image/png"
        case "jpeg":
        case "jpg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "svg": return "image/svg+xml"
        }
        return ""
    }

    function mimeExt(mime) {
        switch (mime) {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        case "image/bmp": return "bmp"
        case "image/svg+xml": return "svg"
        }
        return "img"
    }

    function parse(text) {
        var out = []
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line === "")
                continue
            var tab = line.indexOf("\t")
            if (tab < 0)
                continue
            var id = line.slice(0, tab)
            var prev = line.slice(tab + 1)
            var isImage = prev.indexOf("[[ binary data") === 0
            var mime = ""
            if (isImage) {
                var m = prev.match(/^\[\[ binary data .*?\s([A-Za-z0-9.+-]+)\s+\d+x\d+\s*\]\]$/)
                if (m)
                    mime = hist.mimeFor(m[1])
            }
            out.push({ "id": id, "preview": prev, "isImage": isImage, "mime": mime })
        }
        hist.entries = out

        // Queue thumbnails for the newest image entries.
        var n = 0
        for (var j = 0; j < out.length && n < hist.thumbCap; j++) {
            if (out[j].isImage) {
                hist.queueThumb(out[j])
                n++
            }
        }
    }

    function queueThumb(e) {
        if (!e.isImage || e.mime === "")
            return
        if (hist.thumbs[e.id] !== undefined)
            return
        if (hist.current && hist.current.id === e.id)
            return
        for (var i = 0; i < hist.queue.length; i++) {
            if (hist.queue[i].id === e.id)
                return
        }
        hist.queue.push({ "id": e.id, "path": hist.cacheDir + "/" + e.id + "." + hist.mimeExt(e.mime) })
        hist.pump()
    }

    function pump() {
        if (hist.current || hist.queue.length === 0)
            return
        hist.current = hist.queue.shift()
        thumbProc.command = ["sh", "-c",
            "cliphist decode '" + hist.current.id + "' > '" + hist.current.path + "'"]
        thumbProc.running = true
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true
    }

    function copy(id) {
        var e = hist.entryById(id)
        var cmd = "cliphist decode " + id + " | wl-copy"
        if (e && e.isImage && e.mime !== "")
            cmd += " --type " + e.mime
        copyProc.command = ["sh", "-c", cmd]
        copyProc.running = true
    }

    function remove(id) {
        // awk keeps the id match exact without shell-quoting a literal tab.
        delProc.command = ["sh", "-c",
            "cliphist list | awk -F '\\t' -v id='" + id + "' '$1==id' | cliphist delete"]
        delProc.running = true
    }

    function wipe() {
        wipeProc.running = true
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: hist.parse(text)
        }
    }

    Process {
        id: copyProc
        command: ["true"]
    }

    Process {
        id: delProc
        command: ["true"]
        onExited: hist.refresh()
    }

    Process {
        id: thumbProc
        command: ["true"]

        onExited: {
            var cur = hist.current
            if (cur) {
                var t = {}
                for (var k in hist.thumbs)
                    t[k] = hist.thumbs[k]
                t[cur.id] = cur.path
                hist.thumbs = t
            }
            hist.current = null
            hist.pump()
        }
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]

        onExited: {
            hist.thumbs = ({})
            hist.queue = []
            hist.refresh()
        }
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", hist.cacheDir]
    }

    Component.onCompleted: {
        mkdirProc.running = true
        hist.refresh()
    }
}
