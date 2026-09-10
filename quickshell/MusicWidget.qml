import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Floating "now playing" widget replacing the eww window: same spot
// (bottom-left, 2% / 3% margins, 20% x 20%), same stacking (Bottom layer) so
// it stays under normal windows and never takes keyboard focus.
//
// The look deliberately mirrors the eww widget — pink box, dark text, chunky
// 2px-bordered buttons — with progress control, shuffle/repeat on-states and
// the cava visualizer added on top.
Scope {
    id: root

    readonly property real sizeFraction: 0.20
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

        implicitWidth: Math.round(root.screenW * root.sizeFraction)
        implicitHeight: Math.round(root.screenH * root.sizeFraction)
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:music-widget"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card
            anchors.fill: parent
            color: MusicStyle.bg

            readonly property int artSize: Math.round(height * 0.44)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                // ---------- cover art + track info + controls ----------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: card.artSize
                        Layout.preferredHeight: card.artSize
                        Layout.alignment: Qt.AlignTop
                        color: Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.15)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: MusicState.coverPath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }

                        // Click the cover to open the library browser.
                        Process {
                            id: openLibraryProc
                            command: ["qs", "ipc", "call", "music", "library"]
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: openLibraryProc.running = true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 4

                        // Title, in an eww-style bordered text box.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: titleText.implicitHeight + 4
                            color: "transparent"
                            border.width: 2
                            border.color: MusicStyle.border

                            Text {
                                id: titleText
                                anchors.fill: parent
                                anchors.margins: 2
                                text: MusicState.displayTitle
                                color: MusicStyle.fg
                                font.family: MusicStyle.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // Artist, same treatment.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: artistText.implicitHeight + 4
                            color: "transparent"
                            border.width: 2
                            border.color: MusicStyle.border

                            Text {
                                id: artistText
                                anchors.fill: parent
                                anchors.margins: 2
                                text: MusicState.displayArtist
                                color: MusicStyle.fg
                                font.family: MusicStyle.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // ---------- progress ----------
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 1
                            spacing: 6

                            Text {
                                text: MusicState.fmtTime(MusicState.elapsed)
                                color: MusicStyle.fg
                                font.family: MusicStyle.fontFamily
                                font.pixelSize: 9
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12

                                Rectangle {
                                    id: progressTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 6
                                    color: Qt.rgba(MusicStyle.fg.r, MusicStyle.fg.g, MusicStyle.fg.b, 0.25)
                                    border.width: 1
                                    border.color: MusicStyle.border
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: progressTrack.width * MusicState.progress
                                    height: 6
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
                                font.pixelSize: 9
                            }
                        }

                        // ---------- controls ----------
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 1
                            spacing: 4

                            MusicButton {
                                // md-skip_previous U+F04AE
                                glyph: "\udb81\udcae"
                                onClicked: MusicState.previous()
                            }

                            MusicButton {
                                // md-pause U+F03E4 / md-play U+F040A
                                glyph: MusicState.playing ? "\udb80\udfe4" : "\udb81\udc0a"
                                active: MusicState.playing
                                onClicked: MusicState.toggle()
                            }

                            MusicButton {
                                // md-skip_next U+F04AD
                                glyph: "\udb81\udcad"
                                onClicked: MusicState.next()
                            }

                            Item { Layout.fillWidth: true }

                            MusicButton {
                                // md-shuffle U+F049D
                                glyph: "\udb81\udc9d"
                                active: MusicState.random
                                onClicked: MusicState.toggleRandom()
                            }

                            MusicButton {
                                // md-repeat_once U+F0458 / md-repeat U+F0456
                                glyph: MusicState.single ? "\udb81\udc58" : "\udb81\udc56"
                                active: MusicState.repeat
                                onClicked: MusicState.cycleRepeat()
                            }
                        }
                    }
                }

                // ---------- time-synced lyrics ----------
                LyricsView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                // ---------- cava visualizer in a dark inset ----------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    color: MusicStyle.fg
                    clip: true

                    Visualizer {
                        anchors.fill: parent
                        anchors.margins: 2
                    }
                }
            }
        }
    }
}
