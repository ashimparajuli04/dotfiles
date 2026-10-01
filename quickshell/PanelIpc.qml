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
    IpcHandler {
        target: "sound"
        function toggle() { PillBus.toggleOpen("sound") }
        function show() { PillBus.show("sound") }
        function hide() { PillBus.close("sound") }
    }

    IpcHandler {
        target: "battery"
        function toggle() { PillBus.toggleOpen("battery") }
        function show() { PillBus.show("battery") }
        function hide() { PillBus.close("battery") }

        // Dev/test: pop an alert word without waiting for a real discharge,
        // e.g. `qs ipc call battery alertpop "Final moments"`.
        function alertpop(word: string) { BatteryAlert.testPop(word) }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle() { PillBus.toggleOpen("bluetooth") }
        function show() { PillBus.show("bluetooth") }
        function hide() { PillBus.close("bluetooth") }
    }

    IpcHandler {
        target: "wifi"
        function toggle() { PillBus.toggleOpen("wifi") }
        function show() { PillBus.show("wifi") }
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
}
