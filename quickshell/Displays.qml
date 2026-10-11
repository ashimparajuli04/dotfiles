pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Display setup wizard — state machine + persistence for external monitors.
//
// On connect, a display that has never been configured opens the wizard
// (DisplayPanel.qml) in the middle of the screen; a display that has a saved
// setup has it applied silently. The wizard can be re-opened any time from
// the power menu's Display button. Choices are persisted per output name in
// ~/.local/state/newwave/displays.json.
//
// Sway has no native output mirroring, so "Mirror" launches wl-mirror
// fullscreened on the external (see applyConfig); everything else is plain
// `swaymsg output …`.
//
// The bar (Waybar + Quickshell) is pinned to the chosen main display through
// BarScreen.preferredName + bin/waybar-output.
Scope {
    id: root

    readonly property string internalName: "eDP-1"

    // ---------- persisted setups ----------
    // output name -> { mode, main, side, name, model }
    property var configs: ({})

    // ---------- live output state (from `swaymsg -t get_outputs`) ----------
    property var outputs: ({})        // name -> sway output object
    property var knownNames: []       // names seen so far, for hotplug diffing
    property bool booted: false

    // First connected non-internal output (enabled or not). Prefer sway's
    // output list (it carries the model), but fall back to Quickshell's own
    // screens: if `swaymsg` is unavailable (e.g. a stale SWAYSOCK) `outputs`
    // stays empty, yet Quickshell still knows the real screens directly — so
    // the wizard can at least detect that an external is connected.
    readonly property string externalName: {
        var s = root.outputs
        for (var n in s)
            if (root.isExternal(n))
                return n
        var sc = Quickshell.screens
        for (var i = 0; i < sc.length; i++)
            if (root.isExternal(sc[i].name))
                return sc[i].name
        return ""
    }
    readonly property bool hasExternal: externalName !== ""

    // ---------- wizard state ----------
    property bool promptOpen: false
    property int step: 0              // 0 = mode, 1 = main, 2 = side
    property string deviceName: ""
    property string deviceModel: ""
    property string chosenMode: ""
    property string chosenMain: internalName
    property string chosenSide: ""

    // Expand is applied in two phases: enable both + place the main at the
    // origin, then (once the output settles) read its size and place the other.
    property var pendingExpand: null

    readonly property string stateBase: Quickshell.env("XDG_STATE_HOME")
        || ((Quickshell.env("HOME") || "/home") + "/.local/state")
    readonly property string stateDir: stateBase + "/newwave"
    readonly property string storePath: stateDir + "/displays.json"

    // ---------- persistence ----------
    FileView {
        id: store
        path: root.storePath
        blockLoading: true
        printErrors: false
    }

    function loadConfigs() {
        try {
            var t = store.text()
            root.configs = (t && t.length) ? JSON.parse(t) : ({})
        } catch (e) {
            root.configs = ({})
        }
    }

    function saveConfigs() {
        store.setText(JSON.stringify(root.configs, null, 2) + "\n")
    }

    // ---------- processes ----------
    // Every swaymsg below is prefixed with this: it resolves the *live* sway
    // socket before running. Quickshell can inherit a stale SWAYSOCK/I3SOCK
    // (after a sway restart the watchdog may still hold the old path — see
    // bin/quickshell-watchdog), and a stale socket makes every `swaymsg`
    // silently fail: the wizard sees no outputs and every apply command is a
    // no-op. Re-resolving here is belt-and-braces so the wizard keeps working
    // even if the environment is wrong.
    readonly property string swayEnv: 'for f in "$XDG_RUNTIME_DIR"/sway-ipc.*.sock; do '
        + 'SWAYSOCK=$f I3SOCK=$f swaymsg -t get_version >/dev/null 2>&1 '
        + '&& { export SWAYSOCK=$f I3SOCK=$f; break; }; done; '

    Process { id: mkdirProc }

    Process { id: cmdProc }

    Process {
        id: outputsProc
        command: ["sh", "-c", root.swayEnv + "swaymsg -t get_outputs"]
        stdout: StdioCollector {
            onStreamFinished: root.parseOutputs(text)
        }
    }

    Process {
        id: subscribeProc
        running: true
        command: ["sh", "-c", root.swayEnv
            + "exec swaymsg -t subscribe -m '[\"output\"]'"]
        stdout: SplitParser {
            onRead: root.refreshOutputs()
        }
    }

    function run(cmd) {
        cmdProc.command = ["sh", "-c", root.swayEnv + cmd]
        cmdProc.running = true
    }

    // NOTE: sway commands are always written as `swaymsg -- output …`.
    // Without the `--`, a negative coordinate (up/left, e.g. `position 0 -1080`)
    // is parsed by swaymsg as a command-line option and the command fails —
    // which silently left the external on the right. Keep the `--`.

    function refreshOutputs() {
        outputsProc.running = true
    }

    // ---------- helpers ----------
    function isExternal(name) {
        return name !== "" && name !== root.internalName
    }

    function screenByName(name) {
        var s = Quickshell.screens
        for (var i = 0; i < s.length; i++)
            if (s[i].name === name)
                return s[i]
        return null
    }

    function modelOf(name) {
        var o = root.outputs[name]
        return o ? (o.model || "") : ""
    }

    // ---------- output parsing / hotplug ----------
    function parseOutputs(text) {
        var arr
        try {
            arr = JSON.parse(String(text))
        } catch (e) {
            return
        }
        if (!arr || arr.length === undefined)
            return

        var map = ({})
        var names = []
        for (var i = 0; i < arr.length; i++) {
            var o = arr[i]
            if (!o || !o.name)
                continue
            map[o.name] = o
            names.push(o.name)
        }
        root.outputs = map

        if (!root.booted) {
            root.booted = true
            root.knownNames = names
            // Apply saved setups to already-connected displays, no prompt.
            for (i = 0; i < names.length; i++)
                if (root.isExternal(names[i]) && root.configs[names[i]])
                    root.applyConfig(names[i], root.configs[names[i]], false)
            return
        }

        var fresh = []
        for (i = 0; i < names.length; i++)
            if (root.isExternal(names[i]) && root.knownNames.indexOf(names[i]) === -1)
                fresh.push(names[i])

        var gone = []
        for (i = 0; i < root.knownNames.length; i++)
            if (names.indexOf(root.knownNames[i]) === -1)
                gone.push(root.knownNames[i])

        root.knownNames = names

        // A removed output orphans the overlay windows that were on it — they
        // do NOT re-map on their own, which left the bar half-empty (missing
        // every Quickshell pill) until a manual reload. Reload the shell so all
        // windows re-map to the surviving screen.
        if (gone.length > 0)
            reloadTimer.restart()

        for (i = 0; i < gone.length; i++) {
            if (!root.isExternal(gone[i]))
                continue
            if (root.promptOpen && root.deviceName === gone[i])
                root.cancel()
            // External unplugged: make sure the internal is back and the bar
            // returns to it (sway usually re-enables it, but be explicit).
            BarScreen.preferredName = root.internalName
            root.run("pkill -x wl-mirror 2>/dev/null; "
                + "swaymsg -- output " + root.internalName + " enable; "
                + "swaymsg -- output " + root.internalName + " position 0 0; "
                + root.barCmd(root.internalName))
        }

        for (i = 0; i < fresh.length; i++) {
            var n = fresh[i]
            if (root.configs[n])
                root.applyConfig(n, root.configs[n], false)
            else
                root.openWizard(n)
        }
    }

    // ---------- bar host ----------
    // The bar host is written to the Waybar include file and BarScreen by the
    // wizard. This returns the shell snippet that re-pins Waybar.
    function barCmd(name) {
        return "$HOME/.local/bin/waybar-output " + name
    }

    // ---------- apply a setup ----------
    function applyConfig(name, cfg, save) {
        if (!name || !cfg)
            return

        var cmds = []
        var barHost = root.internalName

        if (cfg.mode === "only-laptop") {
            cmds.push("swaymsg -- output " + name + " disable")
            barHost = root.internalName
        } else if (cfg.mode === "only-external") {
            cmds.push("swaymsg -- output " + name + " enable")
            cmds.push("swaymsg -- output " + name + " position 0 0")
            cmds.push("swaymsg -- output " + root.internalName + " disable")
            barHost = name
        } else if (cfg.mode === "mirror") {
            cmds.push("swaymsg -- output " + name + " enable")
            cmds.push("swaymsg -- output " + name + " position 0 0")
            cmds.push("pkill -x wl-mirror 2>/dev/null")
            cmds.push("command -v wl-mirror >/dev/null && setsid wl-mirror "
                + root.internalName + " --fullscreen-output " + name
                + " --fullscreen >/dev/null 2>&1 &")
            barHost = root.internalName
        } else if (cfg.mode === "expand") {
            root.startExpand(name, cfg.main || root.internalName, cfg.side || "right", save)
            return
        }

        BarScreen.preferredName = barHost
        cmds.push(root.barCmd(barHost))
        root.run(cmds.join("\n"))

        if (save) {
            root.configs[name] = cfg
            root.saveConfigs()
        }
    }

    function startExpand(name, main, side, save) {
        root.pendingExpand = { name: name, main: main, side: side, save: save }
        BarScreen.preferredName = main
        root.run("swaymsg -- output " + name + " enable\n"
            + "swaymsg -- output " + root.internalName + " enable\n"
            + "swaymsg -- output " + main + " position 0 0\n"
            + root.barCmd(main))
        expandTimer.restart()
    }

    Timer {
        id: expandTimer
        interval: 700
        onTriggered: {
            var pe = root.pendingExpand
            if (!pe)
                return
            root.pendingExpand = null
            root.refreshOutputs()
            root.finishExpand(pe)
        }
    }

    // Re-map the bar overlays after an output is removed (see parseOutputs).
    // Deferred a moment so the current handler finishes before the shell
    // reloads itself; a soft reload re-parents the existing windows.
    Timer {
        id: reloadTimer
        interval: 300
        onTriggered: Quickshell.reload(false)
    }

    function finishExpand(pe) {
        var otherName = (pe.main === root.internalName) ? pe.name : root.internalName
        var ms = root.screenByName(pe.main)
        var os = root.screenByName(otherName)
        var mw = ms ? ms.width : 1920
        var mh = ms ? ms.height : 1080
        var ow = os ? os.width : 1920
        var oh = os ? os.height : 1080

        var x = 0
        var y = 0
        if (pe.side === "right") {
            x = mw; y = 0
        } else if (pe.side === "left") {
            x = -ow; y = 0
        } else if (pe.side === "up") {
            x = 0; y = -oh
        } else if (pe.side === "down") {
            x = 0; y = mh
        }

        root.run("swaymsg -- output " + pe.main + " position 0 0; "
            + "swaymsg -- output " + otherName + " position " + x + " " + y)

        if (pe.save) {
            root.configs[pe.name] = {
                mode: "expand",
                main: pe.main,
                side: pe.side,
                name: pe.name,
                model: root.modelOf(pe.name)
            }
            root.saveConfigs()
        }
    }

    // ---------- wizard ----------
    function openWizard(name) {
        var n = name || root.externalName
        root.deviceName = n
        root.deviceModel = root.modelOf(n)
        root.step = 0
        root.chosenMode = ""
        root.chosenMain = root.internalName
        root.chosenSide = ""
        root.promptOpen = true
        PillBus.closeAll()
    }

    function chooseMode(mode) {
        root.chosenMode = mode
        if (mode === "expand") {
            root.step = 1
            return
        }
        root.commit()
    }

    function chooseMain(main) {
        root.chosenMain = main
        root.step = 2
    }

    function chooseSide(side) {
        root.chosenSide = side
        root.commit()
    }

    function back() {
        if (root.step > 0)
            root.step -= 1
    }

    function cancel() {
        root.promptOpen = false
        root.pendingExpand = null
    }

    function commit() {
        var cfg = {
            mode: root.chosenMode,
            main: root.chosenMain,
            side: root.chosenSide,
            name: root.deviceName,
            model: root.deviceModel
        }
        root.applyConfig(root.deviceName, cfg, true)
        root.promptOpen = false
    }

    // ---------- init ----------
    Component.onCompleted: {
        mkdirProc.command = ["mkdir", "-p", root.stateDir]
        mkdirProc.running = true
        root.loadConfigs()
        root.refreshOutputs()
    }
}
