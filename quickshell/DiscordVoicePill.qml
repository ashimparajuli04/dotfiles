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

    // Distance from the screen's right edge to this slot's right edge. Right-
    // anchored, so this fixes the gap to the tray pill regardless of how many
    // avatars are shown. 222 leaves the same ~10px gap the other pills use
    // (the tray pill's left edge sits at ~1708). TUNE BY SCREENSHOT.
    readonly property int baseRightMargin: 222

    // ---------- state ----------
    readonly property var shownUsers: {
        if (!DiscordVoice.inVoice)
            return []
        var u = DiscordVoice.voiceUsers
        return u.length > maxAvatars ? u.slice(0, maxAvatars) : u
    }
    readonly property int overflow: DiscordVoice.inVoice
        ? Math.max(0, DiscordVoice.voiceUsers.length - maxAvatars) : 0
    // Show while in a call, and also while not yet authorized (a small
    // placeholder glyph) so the pill is clickable to open the Authorize panel.
    // Hidden only in the steady idle state: authorized + not in a call.
    readonly property bool notAuthed: !DiscordVoice.authenticated
    readonly property bool shown: root.notAuthed
        || (DiscordVoice.inVoice && shownUsers.length > 0)

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

        implicitWidth: root.shown ? (content.implicitWidth + root.padX * 2) : 0
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
