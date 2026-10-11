import Quickshell

// New Wave Quickshell shell — one component per pill/panel. See changes.md.
//
// The popovers are LAZY: shell.qml instantiates them only while PillBus says
// they are open, so a closed popover costs ~0 (its whole QML tree is torn
// down). The bar (pills / tray / music widget) and the always-visible calendar
// clock chip stay eager, and external `qs ipc call` is served by the eager
// PanelIpc. See changes.md §39.
ShellRoot {
    // External IPC — must exist even while every popover is closed.
    PanelIpc {}

    // Always-visible bar.
    ResourcePill {}
    BrightnessPill {}
    SoundPill {}
    BluetoothPill {}
    WifiPill {}
    BatteryPill {}
    TrayWidget {}
    MusicWidget {}
    // Only materialised while Discord is running: the pill (and its layer
    // surface / avatar strip) costs nothing when Discord is closed, matching the
    // lazily-gated discord_bridge.py process in DiscordVoice.qml.
    LazyLoader { active: DiscordVoice.discordRunning; DiscordVoicePill {} }

    // Owns org.freedesktop.Notifications — must stay eager.
    Notifications {}

    // Popovers — instantiated on demand, destroyed when closed.
    LazyLoader { active: PillBus.soundOpen; SoundPanel {} }
    LazyLoader { active: PillBus.batteryOpen; BatteryPanel {} }
    LazyLoader { active: PillBus.bluetoothOpen; BluetoothPanel {} }
    LazyLoader { active: PillBus.wifiOpen; WifiPanel {} }
    LazyLoader { active: PillBus.musicOpen; MusicPanel {} }
    LazyLoader { active: PillBus.powermenuOpen; PowermenuPanel {} }
    LazyLoader { active: PillBus.discordOpen; DiscordVoicePanel {} }
    LazyLoader { active: PillBus.clipboardOpen; ClipboardPanel {} }

    // Display setup wizard: opened automatically when a new external display
    // is connected, or from the power menu's Display button. See Displays.qml.
    LazyLoader { active: Displays.promptOpen; DisplayPanel {} }

    // Calendar owns the always-visible clock chip, so it stays eager.
    CalendarPanel {}
}
