import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Discord voice popover, opened by clicking the avatar strip
// (DiscordVoicePill.qml) or `qs ipc call discord toggle`. Same popover
// pattern as BatteryPanel.qml: click-catcher, Escape close, only one panel
// open at a time (PillBus). Lazy-loaded by shell.qml.
Scope {
    id: root

    property bool panelOpen: true

    readonly property int rowHeight: 38

    // ---------- popover plumbing ----------
    onPanelOpenChanged: PillBus.discordOpen = root.panelOpen

    function ringFor(user) {
        var muted = user.self_mute || user.mute
        var deaf = user.self_deaf || user.deaf
        if (muted || deaf)
            return "#e78284"
        if (DiscordVoice.speakingUsers[user.id] === true)
            return Theme.accent
        return "transparent"
    }

    // Transparent click-catcher: closes the popover when clicking anywhere
    // outside of it. Starts below the 29px Waybar so the bar stays clickable.
    PanelWindow {
        screen: BarScreen.screen
        id: catcher
        visible: root.panelOpen

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        margins {
            top: 31
        }

        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:discord-catcher"

        MouseArea {
            anchors.fill: parent
            onClicked: root.panelOpen = false
        }
    }

    PanelWindow {
        screen: BarScreen.screen
        id: panel
        visible: root.panelOpen

        anchors {
            top: true
            right: true
        }
        margins {
            top: 6
            right: 6
        }

        implicitWidth: 320
        implicitHeight: frame.implicitHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:discord-panel"
        WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: frame
            anchors.fill: parent
            focus: true
            color: Theme.bg
            radius: Theme.radius
            implicitHeight: col.implicitHeight + 28

            Keys.onEscapePressed: root.panelOpen = false

            ColumnLayout {
                id: col
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 14
                }
                spacing: 10

                // ---- Header ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "\u{f1ff}"   // Nerd Font (FA brands): discord
                        color: Theme.active
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Discord Voice"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: DiscordVoice.inVoice && DiscordVoice.currentChannel
                                ? DiscordVoice.currentChannel.name
                                : (DiscordVoice.authenticated ? "Not in a call" : "Not connected")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                // ---- Not authenticated ----
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !DiscordVoice.authenticated
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: DiscordVoice.authError !== ""
                            ? DiscordVoice.authError
                            : "Connect to Discord to show voice-channel participants and control mute/deafen."
                        color: DiscordVoice.authError !== "" ? "#e78284" : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: authLabel.implicitWidth + 28
                        implicitHeight: 34
                        radius: 8
                        color: Theme.active

                        Text {
                            id: authLabel
                            anchors.centerIn: parent
                            text: "Authorize Discord"
                            color: "#040404"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DiscordVoice.authorize()
                        }
                    }
                }

                // ---- Authenticated, in voice ----
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: DiscordVoice.authenticated && DiscordVoice.inVoice
                    spacing: 6

                    Repeater {
                        model: DiscordVoice.voiceUsers

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: root.rowHeight
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.05)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                DiscordAvatar {
                                    Layout.alignment: Qt.AlignVCenter
                                    size: 26
                                    userId: modelData.id
                                    avatarHash: modelData.avatar
                                    fallbackName: modelData.nick || modelData.username
                                    ringColor: root.ringFor(modelData)
                                    showBadge: modelData.self_mute || modelData.mute
                                        || modelData.self_deaf || modelData.deaf
                                    muted: modelData.self_mute || modelData.mute
                                    deafened: modelData.self_deaf || modelData.deaf
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: modelData.nick || modelData.username || "Unknown"
                                    color: Theme.fg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: modelData.self_mute || modelData.mute
                                    text: "\uf131"   // microphone-slash
                                    color: "#e78284"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: modelData.self_deaf || modelData.deaf
                                    text: "\uf026"   // volume-off
                                    color: "#e78284"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }

                    // ---- Controls ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 8
                            color: DiscordVoice.isMuted ? "#e78284" : Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: (DiscordVoice.isMuted ? "\uf131  Unmute" : "\uf130  Mute")
                                color: DiscordVoice.isMuted ? "#040404" : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DiscordVoice.toggleMute()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 8
                            color: DiscordVoice.isDeafened ? "#e78284" : Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: (DiscordVoice.isDeafened ? "\uf026  Undeafen" : "\uf025  Deafen")
                                color: DiscordVoice.isDeafened ? "#040404" : Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DiscordVoice.toggleDeafen()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "Hang up"
                            color: "#e78284"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: DiscordVoice.hangup()
                        }
                    }
                }

                // ---- Authenticated, not in voice ----
                Text {
                    Layout.fillWidth: true
                    visible: DiscordVoice.authenticated && !DiscordVoice.inVoice
                    text: "No active Discord call"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
