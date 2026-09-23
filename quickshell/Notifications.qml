import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

// Desktop notifications drawn by Quickshell, replacing the dunst daemon
// (Quickshell now owns org.freedesktop.Notifications). Cards stack top-right
// under the bar, styled with the New Wave theme. Normal/low urgency auto-expire
// (default 10 s, matching dunstrc); critical stays until clicked. Click a card
// to dismiss it, right-click to dismiss all. See changes.md §41.
Scope {
    id: root

    readonly property int defaultTimeout: 10000

    NotificationServer {
        id: server

        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        actionsSupported: true

        // Retain each notification so the popup can render it; the per-card
        // timer calls expire()/dismiss() to remove it again.
        onNotification: function (n) {
            n.tracked = true
        }
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            right: true
        }

        margins {
            top: 4
            right: 8
        }

        implicitWidth: 340
        implicitHeight: Math.min(cards.implicitHeight, 640)
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:notifications"

        visible: server.trackedNotifications.values.length > 0

        Column {
            id: cards
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    width: cards.width
                    implicitHeight: body.implicitHeight + 24
                    radius: 14
                    color: Theme.bg
                    border.width: 1
                    border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.accent
                        : (modelData.urgency === NotificationUrgency.Low ? "#2C2C2E" : Theme.active)

                    function timeoutMs() {
                        if (modelData.urgency === NotificationUrgency.Critical)
                            return 0
                        if (modelData.expireTimeout === 0)
                            return 0
                        return modelData.expireTimeout > 0 ? modelData.expireTimeout : root.defaultTimeout
                    }

                    Column {
                        id: body
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        spacing: 4

                        Row {
                            spacing: 8

                            Image {
                                visible: modelData.appIcon !== ""
                                source: modelData.appIcon
                                width: 20
                                height: 20
                                sourceSize.width: 20
                                sourceSize.height: 20
                                smooth: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.appName
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            width: parent.width
                            visible: modelData.summary !== ""
                            text: modelData.summary
                            textFormat: Text.PlainText
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            visible: modelData.body !== ""
                            text: modelData.body
                            textFormat: Text.PlainText
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton)
                                modelData.dismiss()
                            else
                                modelData.dismiss()
                        }
                    }

                    Timer {
                        interval: Math.max(1, card.timeoutMs())
                        running: card.timeoutMs() > 0
                        onTriggered: modelData.expire()
                    }
                }
            }
        }
    }
}
