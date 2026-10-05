import QtQuick
import Quickshell
import Quickshell.Wayland

// Discord voice participants as a strip of circular avatars in the bar.
//
// Sits on the invisible `custom/discordvoice` Waybar slot — the leftmost
// module of the right group. Everything to its right (tray + the five pills +
// powermenu) is fixed-width, so the strip's position is stable; it slides
// left with PillBus.reach while the pill cluster hover-expands. Clicking it
// opens the Discord panel (DiscordVoicePanel.qml). See changes.md.
Scope {
    id: root

    // ---------- geometry ----------
    // Tuned against the real bar with screenshots (see BatteryPill.qml §25).
    readonly property int avatarSize: 18
    readonly property int pillHeight: 24
    readonly property int padX: 8
    readonly property int spacing: 2
    readonly property int maxAvatars: 5

    // Room for the "+N" overflow label when more than maxAvatars are talking.
    readonly property int overflowWidth: 26

    // Fixed layer-shell surface width. The surface must NEVER change size:
    // resizing it emits wl_surface configure events, and Qt's Wayland client
    // handling of those (applyConfigure -> sendExposeEvent -> sync/render)
    // deadlocks against the Mesa/Vulkan present path (quickshell issue #919) —
    // the GUI thread waits on the render thread while the render thread waits
    // on a Wayland event the GUI thread can no longer dispatch. Every other
    // pill keeps a constant surface width for exactly this reason; we reserve
    // room for the widest strip and only animate the inner pill/content.
    readonly property int reservedWidth: padX * 2
        + maxAvatars * avatarSize
        + Math.max(0, maxAvatars - 1) * spacing
        + overflowWidth

    // Gap between this pill and the tray pill to its right (matches the ~10px
    // the other pills use).
    readonly property int trayGap: 11

    // Right edge tracks the tray pill's live left edge (PillBus.trayLeftInset,
    // published by TrayWidget.qml) plus the gap. Right-anchored, so the gap
    // stays constant no matter how many avatars are shown, and it never
    // collides when tray icons are added or removed.
    readonly property int baseRightMargin: Math.round(PillBus.trayLeftInset) + trayGap

    // ---------- state ----------
    readonly property var shownUsers: {
        if (!DiscordVoice.inVoice)
            return []
        var u = DiscordVoice.voiceUsers
        return u.length > maxAvatars ? u.slice(0, maxAvatars) : u
    }
    readonly property int overflow: DiscordVoice.inVoice
        ? Math.max(0, DiscordVoice.voiceUsers.length - maxAvatars) : 0
    // Only materialise the pill when there is something to show:
    //  * active participants while in a call, or
    //  * an authorization prompt — but only while Discord is actually running,
    //    so a closed Discord doesn't leave a stranded placeholder in the bar.
    readonly property bool notAuthed: !DiscordVoice.authenticated
    readonly property bool shown: (DiscordVoice.inVoice && shownUsers.length > 0)
        || (root.notAuthed && DiscordVoice.discordRunning)

    function ringFor(user) {
        var muted = user.self_mute || user.mute
        var deaf = user.self_deaf || user.deaf
        if (muted || deaf)
            return "#e78284"
        if (DiscordVoice.speakingUsers[user.id] === true)
            return Theme.accent
        return "transparent"
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            right: true
        }

        margins {
            top: -24
            right: root.baseRightMargin + PillBus.reach
        }

        // Constant surface width (see reservedWidth above). The visible pill
        // is right-anchored inside and animates its own width, so the usable
        // area still grows/shrinks with the participant count without ever
        // resizing the layer surface.
        implicitWidth: root.reservedWidth
        implicitHeight: root.pillHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:discord-voice-pill"

        // Only the pill takes input; the rest of the surface stays
        // click-through. Width 0 while hidden => no input region.
        mask: Region {
            x: pill.x
            y: pill.y
            width: pill.width
            height: pill.height
            radius: pill.radius
        }

        Rectangle {
            id: pill
            anchors.top: parent.top
            anchors.right: parent.right
            height: root.pillHeight
            width: root.shown ? (content.implicitWidth + root.padX * 2) : 0
            radius: 10
            color: "#040404"
            opacity: root.shown ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: PillBus.toggleOpen("discord")
            }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: root.spacing

                // Placeholder shown until Discord is authorized: a glyph that
                // opens the panel so the user can click Authorize.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.notAuthed
                    text: "\uf1ff"   // Nerd Font (FA brands): discord
                    color: DiscordVoice.authError !== "" ? "#e78284" : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }

                Repeater {
                    model: root.notAuthed ? [] : root.shownUsers

                    DiscordAvatar {
                        anchors.verticalCenter: parent.verticalCenter
                        size: root.avatarSize
                        userId: modelData.id
                        avatarHash: modelData.avatar
                        fallbackName: modelData.nick || modelData.username
                        ringColor: root.ringFor(modelData)
                        showBadge: modelData.self_mute || modelData.mute
                            || modelData.self_deaf || modelData.deaf
                        muted: modelData.self_mute || modelData.mute
                        deafened: modelData.self_deaf || modelData.deaf
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.notAuthed && root.overflow > 0
                    text: "+" + root.overflow
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
