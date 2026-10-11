pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Waybar and the Quickshell bar pills live on different wlroots layers. Waybar
// is on the Top layer, so a fullscreen window is composited over it and every
// Waybar-drawn module (workspaces, music, weather, …) disappears — but every
// Quickshell pill is on the Overlay layer, which stays above a fullscreen
// window. Without this watcher the calendar chip and the right-hand pill
// cluster keep floating over the fullscreen window while the rest of the bar
// is gone.
//
// This singleton watches sway for a fullscreen window on the output the bar is
// pinned to; each always-visible pill binds `visible` to
// `!FullscreenWatch.covering`, so the whole bar leaves and returns together.
//
// State is event-driven (one long-lived `swaymsg -t subscribe`) for an instant
// hide, with a slow poll as a safety net in case the subscription ever dies
// (e.g. a sway restart drops the socket).
QtObject {
    id: root

    // True while a fullscreen window covers the output the bar is pinned to.
    // A globally-fullscreen window (fullscreen_mode 2) covers every output, so
    // it hides the bar too.
    property bool covering: false

    // One in-flight `get_tree` at a time; if events arrive while it runs, run
    // again once it exits so the final state is never missed.
    property bool pending: false

    function recheck() {
        if (treeProc.running) {
            root.pending = true
            return
        }
        treeProc.running = true
    }

    // Long-lived sway event stream. Any window/workspace/output change can move
    // a fullscreen window onto (or off) the bar's output, so re-read the tree
    // on each event. `-r` keeps every event on a single line for SplitParser.
    property Process subscribeProc: Process {
        command: ["swaymsg", "-t", "subscribe", "-r", "-m",
            "[\"window\",\"workspace\",\"output\"]"]
        running: true
        stdout: SplitParser {
            onRead: root.recheck()
        }
        onExited: root.restartTimer.start()
    }

    // The subscription exits when sway reloads/restarts (or the socket drops);
    // bring it back so the bar doesn't go blind to fullscreen changes.
    property Timer restartTimer: Timer {
        interval: 1000
        onTriggered: if (!root.subscribeProc.running)
            root.subscribeProc.running = true
    }

    // Reads the sway tree and updates `covering`.
    property Process treeProc: Process {
        command: ["swaymsg", "-t", "get_tree", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.covering = root.hasFullscreen(text)
        }
        onExited: {
            if (root.pending) {
                root.pending = false
                root.recheck()
            }
        }
    }

    // Safety net: re-read on a slow cadence so a missed event (or a dead
    // subscription) can never leave the bar stuck over a fullscreen window.
    // Also seeds the initial state at startup.
    property Timer poll: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.recheck()
    }

    // Re-target immediately when the display wizard moves the bar to another
    // output, instead of waiting for the next poll.
    property Connections barScreenConn: Connections {
        target: BarScreen
        function onPreferredNameChanged() {
            root.recheck()
        }
    }

    // True if the `get_tree` reply contains a fullscreen container that is
    // actually visible on the bar's output (or a globally-fullscreen one).
    // Containers on hidden workspaces are ignored: a fullscreen window on
    // another workspace must not hide the bar.
    function hasFullscreen(json) {
        var outputName = BarScreen.screen ? BarScreen.screen.name : ""
        var tree
        try {
            tree = JSON.parse(String(json))
        } catch (e) {
            return root.covering // keep the last good value on a bad reply
        }
        var found = false
        function walk(node, outName) {
            if (found)
                return
            if (node.type === "output")
                outName = node.name
            if ((node.type === "con" || node.type === "floating_con")
                    && node.fullscreen_mode > 0 && node.visible === true
                    && (node.fullscreen_mode === 2 || outName === outputName))
                found = true
            var kids = node.nodes || []
            for (var i = 0; i < kids.length; i++)
                walk(kids[i], outName)
            var floats = node.floating_nodes || []
            for (var j = 0; j < floats.length; j++)
                walk(floats[j], outName)
        }
        walk(tree, null)
        return found
    }
}
