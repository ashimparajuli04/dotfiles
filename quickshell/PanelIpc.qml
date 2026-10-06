import Quickshell
import Quickshell.Io

// Always-on IPC surface for the popover panels. The panels themselves are
// lazy-loaded by shell.qml (so they cost ~0 while closed), which means their
// own IpcHandlers would disappear when unloaded. These handlers live outside
// the loaders and forward external `qs ipc call <target> …` into PillBus
// state, which the LazyLoaders watch. See changes.md §39.
//
// `calendar` is NOT here — CalendarPanel owns an always-visible clock chip and
// stays eager, so it keeps its own IpcHandler.
Scope {
    // Preview popovers (sound / bluetooth / wifi / battery): opening via IPC
    // counts as "latched", so they stay until an outside click (like clicking
    // the pill). Closing via hide() lets PillBus.previewReset clear the latch.
    // See PillBus.qml for the shared preview coordinator.
    IpcHandler {
        target: "sound"
        function toggle() {
            if (PillBus.soundOpen) {
                PillBus.close("sound")
            } else {
                PillBus.show("sound")
                PillBus.panelLatched = true
            }
        }
        function show() { PillBus.show("sound"); PillBus.panelLatched = true }
        function hide() { PillBus.close("sound") }
    }

    IpcHandler {
        target: "battery"
        function toggle() {
            if (PillBus.batteryOpen) {
                PillBus.close("battery")
            } else {
                PillBus.show("battery")
                PillBus.panelLatched = true
            }
        }
        function show() { PillBus.show("battery"); PillBus.panelLatched = true }
        function hide() { PillBus.close("battery") }

        // Dev/test: pop an alert word without waiting for a real discharge,
        // e.g. `qs ipc call battery alertpop "Final moments"`.
        function alertpop(word: string) { BatteryAlert.testPop(word) }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle() {
            if (PillBus.bluetoothOpen) {
                PillBus.close("bluetooth")
            } else {
                PillBus.show("bluetooth")
                PillBus.panelLatched = true
            }
        }
        function show() { PillBus.show("bluetooth"); PillBus.panelLatched = true }
        function hide() { PillBus.close("bluetooth") }
    }

    IpcHandler {
        target: "wifi"
        function toggle() {
            if (PillBus.wifiOpen) {
                PillBus.close("wifi")
            } else {
                PillBus.show("wifi")
                PillBus.panelLatched = true
            }
        }
        function show() { PillBus.show("wifi"); PillBus.panelLatched = true }
        function hide() { PillBus.close("wifi") }
    }

    IpcHandler {
        target: "music"
        function toggle() {
            // Open on the library tab (the "selector"); only a fresh open
            // resets the tab, so toggling closed doesn't clobber a chosen tab.
            if (!PillBus.musicOpen)
                PillBus.musicTab = 0
            PillBus.toggleOpen("music")
        }
        function show() { PillBus.show("music") }
        function hide() { PillBus.close("music") }
        function library() {
            PillBus.musicTab = 0
            PillBus.show("music")
        }
        function queue() {
            PillBus.musicTab = 1
            PillBus.show("music")
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle() { PillBus.toggleOpen("powermenu") }
        function show() { PillBus.show("powermenu") }
        function hide() { PillBus.close("powermenu") }
    }

    // Discord voice: opens the panel and forwards voice controls. The bridge
    // state itself lives in DiscordVoice.qml (always eager).
    IpcHandler {
        target: "discord"
        function toggle() { PillBus.toggleOpen("discord") }
        function show() { PillBus.show("discord") }
        function hide() { PillBus.close("discord") }
        function toggleMute() { DiscordVoice.toggleMute() }
        function toggleDeafen() { DiscordVoice.toggleDeafen() }
        function hangup() { DiscordVoice.hangup() }
        function status(): string { return DiscordVoice.status() }
    }

    // Clipboard: opens the popover, clears the history, or copies an entry by
    // id. The history itself lives in ClipboardHistory.qml. The pill is drawn
    // by Waybar (#custom/clipboard, left-click) — this handler backs that and
    // the Mod+Shift+V keybind. The panel closes on an outside click or Esc.
    IpcHandler {
        target: "clipboard"

        function toggle() {
            if (PillBus.clipboardOpen) {
                PillBus.clipboardPinned = false
                PillBus.close("clipboard")
            } else {
                PillBus.show("clipboard")
                ClipboardHistory.refresh()
            }
        }

        function show() {
            PillBus.show("clipboard")
            ClipboardHistory.refresh()
        }

        function hide() {
            PillBus.clipboardPinned = false
            PillBus.close("clipboard")
        }

        function wipe() { ClipboardHistory.wipe() }
        function copy(id: string) { ClipboardHistory.copy(id) }
        // Debug/status: reports the panel state machine.
        function state(): string {
            return (PillBus.clipboardOpen ? "open" : "closed")
                + "/" + (PillBus.clipboardPinned ? "pinned" : "unpinned")
        }
    }

    // Display setup wizard. Opened automatically on hotplug and from the power
    // menu's Display button; these handlers are for manual testing.
    IpcHandler {
        target: "display"
        function show() { Displays.openWizard() }
        function hide() { Displays.cancel() }
        function toggle() {
            if (Displays.promptOpen)
                Displays.cancel()
            else
                Displays.openWizard()
        }
        function state(): string {
            return (Displays.promptOpen ? "open" : "closed")
                + "/step" + Displays.step
                + "/ext=" + (Displays.externalName || "-")
        }
        function debug(): string {
            var names = []
            var s = Quickshell.screens
            for (var i = 0; i < s.length; i++)
                names.push(s[i].name)
            return "pref=" + BarScreen.preferredName
                + " screens=[" + names.join(",") + "]"
                + " barScreen=" + (BarScreen.screen ? BarScreen.screen.name : "null")
        }
    }
}
