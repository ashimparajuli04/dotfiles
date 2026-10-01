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
    BrightnessPill {}
    SoundPill {}
    BluetoothPill {}
    WifiPill {}
    BatteryPill {}
    TrayWidget {}
    MusicWidget {}
    DiscordVoicePill {}

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

    // Calendar owns the always-visible clock chip, so it stays eager.
    CalendarPanel {}
}
