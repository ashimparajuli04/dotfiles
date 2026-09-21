import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Floating "now playing" widget replacing the eww window: same spot
// (bottom-left, 2% / 3% margins) and same stacking (Bottom layer, never takes
// focus). Sized to the original eww widget: dark backdrop, 150 px cover,
// 2px-bordered text boxes, controls below, lyrics underneath.
Scope {
    id: root

    readonly property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenW: root.targetScreen ? root.targetScreen.width : 1920
    readonly property real screenH: root.targetScreen ? root.targetScreen.height : 1080

    PanelWindow {
        id: widget
        screen: root.targetScreen

        anchors {
            bottom: true
            left: true
        }
        margins {
            left: Math.round(root.screenW * 0.02)
            bottom: Math.round(root.screenH * 0.03)
        }

        implicitWidth: MusicStyle.widgetWidth
        implicitHeight: col.implicitHeight + MusicStyle.widgetPadding * 2
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:music-widget"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // ---------- dark backdrop ----------
        Rectangle {
            anchors.fill: parent
            color: MusicStyle.fg
            radius: 10

            ColumnLayout {
                id: col
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: MusicStyle.widgetPadding
                }
                spacing: MusicStyle.cardGap

                // ---------- pink card ----------
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: cardCol.implicitHeight + MusicStyle.cardPadding * 2
                    color: MusicStyle.bg

                    ColumnLayout {
                        id: cardCol
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: MusicStyle.cardPadding
                        }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            // cover art (click opens the library panel)
                            Rectangle {
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 150
                                color: Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.15)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: MusicState.coverPath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        PillBus.musicTab = 0
                                        PillBus.show("music")
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 8

                                // title, in a bordered text box like the original
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: titleText.implicitHeight + 8
                                    color: "transparent"
                                    border.width: 2
                                    border.color: MusicStyle.border

                                    Text {
                                        id: titleText
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        text: MusicState.displayTitle
                                        color: MusicStyle.fg
                                        font.family: MusicStyle.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                // artist, same treatment
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: artistText.implicitHeight + 8
                                    color: "transparent"
                                    border.width: 2
                                    border.color: MusicStyle.border

                                    Text {
                                        id: artistText
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        text: MusicState.displayArtist
                                        color: MusicStyle.fg
                                        font.family: MusicStyle.fontFamily
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                // progress
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: MusicState.fmtTime(MusicState.elapsed)
                                        color: MusicStyle.fg
                                        font.family: MusicStyle.fontFamily
                                        font.pixelSize: 11
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 14

                                        Rectangle {
                                            id: progressTrack
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            height: 7
                                            color: Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.25)
                                            border.width: 1
                                            border.color: MusicStyle.border
                                        }

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: progressTrack.width * MusicState.progress
                                            height: 7
                                            color: MusicStyle.fg
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function (mouse) {
                                                MusicState.seek(mouse.x / width)
                                            }
                                        }
                                    }

                                    Text {
                                        text: MusicState.fmtTime(MusicState.length)
                                        color: MusicStyle.fg
                                        font.family: MusicStyle.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }

                        // ---------- controls (full card width) ----------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MusicButton {
                                Layout.fillWidth: true
                                implicitHeight: MusicStyle.buttonHeight
                                glyphSize: 26
                                // md-skip_previous U+F04AE
                                glyph: "\udb81\udcae"
                                onClicked: MusicState.previous()
                            }

                            MusicButton {
                                Layout.fillWidth: true
                                implicitHeight: MusicStyle.buttonHeight
                                glyphSize: 26
                                // md-pause U+F03E4 / md-play U+F040A
                                glyph: MusicState.playing ? "\udb80\udfe4" : "\udb81\udc0a"
                                active: MusicState.playing
                                onClicked: MusicState.toggle()
                            }

                            MusicButton {
                                Layout.fillWidth: true
                                implicitHeight: MusicStyle.buttonHeight
                                glyphSize: 26
                                // md-skip_next U+F04AD
                                glyph: "\udb81\udcad"
                                onClicked: MusicState.next()
                            }

                            MusicButton {
                                Layout.fillWidth: true
                                implicitHeight: MusicStyle.buttonHeight
                                glyphSize: 26
                                // md-shuffle U+F049D
                                glyph: "\udb81\udc9d"
                                active: MusicState.random
                                onClicked: MusicState.toggleRandom()
                            }

                            MusicButton {
                                Layout.fillWidth: true
                                implicitHeight: MusicStyle.buttonHeight
                                glyphSize: 26
                                // md-repeat_once U+F0458 / md-repeat U+F0456
                                glyph: MusicState.single ? "\udb81\udc58" : "\udb81\udc56"
                                active: MusicState.repeat
                                onClicked: MusicState.cycleRepeat()
                            }
                        }
                    }
                }

                // ---------- lyrics on the dark backdrop ----------
                LyricsView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: MusicStyle.lyricsHeight
                }
            }
        }
    }
}
