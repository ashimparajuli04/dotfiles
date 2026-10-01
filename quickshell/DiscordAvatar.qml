import QtQuick
import QtQuick.Effects

// Circular Discord avatar with a speaking ring and a mute/deafen badge.
// Shared by DiscordVoicePill.qml (the bar strip) and DiscordVoicePanel.qml
// (the popover). The circular crop uses QtQuick.Effects' MultiEffect
// (Qt 6.12 here; Qt5Compat.GraphicalEffects is not installed).
Item {
    id: root

    property string userId: ""
    property string avatarHash: ""
    property string fallbackName: ""
    property int size: 18
    property color ringColor: "transparent"
    property bool showBadge: false
    property bool muted: false
    property bool deafened: false

    implicitWidth: size
    implicitHeight: size

    readonly property string src: DiscordVoice.avatarUrl(userId, avatarHash)

    // Fallback circle (also the default-avatar background when the hash is
    // empty): colour derived from the user id so it is stable per user.
    Rectangle {
        id: fallback
        anchors.fill: parent
        radius: width / 2
        color: {
            var h = 0
            for (var i = 0; i < root.userId.length; i++)
                h = (h * 31 + root.userId.charCodeAt(i)) % 360
            return Qt.hsla(h / 360, 0.45, 0.40, 1)
        }
        visible: avatarImg.status !== Image.Ready
    }

    Text {
        anchors.centerIn: fallback
        visible: fallback.visible
        text: root.fallbackName ? root.fallbackName.charAt(0).toUpperCase() : "?"
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.size * 0.5)
        font.bold: true
    }

    // Avatar image, rendered through MultiEffect so it is clipped to a circle.
    Image {
        id: avatarImg
        anchors.fill: parent
        source: root.src
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: false
        layer.enabled: true
    }

    Rectangle {
        id: maskRect
        anchors.fill: parent
        radius: width / 2
        color: "white"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: avatarImg
        maskSource: maskRect
        maskEnabled: true
        visible: avatarImg.status === Image.Ready
    }

    // Speaking / mute ring.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.ringColor

        Behavior on border.color {
            ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    // Mute / deafen badge.
    Rectangle {
        visible: root.showBadge
        width: Math.max(9, Math.round(root.size * 0.5))
        height: width
        radius: width / 2
        color: "#e78284"
        // A dark outline keeps the badge legible against bright avatar art.
        border.width: 1
        border.color: "#040404"
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Text {
            anchors.centerIn: parent
            // Nerd Font glyphs: microphone-slash / volume-off.
            text: root.deafened ? "\uf026" : "\uf131"
            color: "#040404"
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(parent.width * 0.7)
        }
    }
}
