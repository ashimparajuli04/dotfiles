import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland

// The system tray (Discord, qBittorrent, …) re-created as a Quickshell
// overlay so it lives on the SAME animation clock as the hover-expanding
// pills. Waybar's native `tray` module used to be shoved left by a FIFO-fed
// spacer (the old §35 trayshift hack): discrete 10px Waybar relayouts that
// stepped and lagged behind the smooth QML pill animation. Now the tray is
// just another Quickshell pill pushed by PillBus.reach, so a hover expansion
// slides it left in one smooth motion. See changes.md §36.
//
// Geometry: sits on the transparent `custom/tray` Waybar spacer, immediately
// left of the brightness pill (the leftmost joined pill). Its right edge is
// pinned `rightMargin` from the screen's right edge and it slides left by
// PillBus.reach, exactly like BrightnessPill.qml.
//
// Caveats (documented in changes.md §36):
//  * SNI-only — legacy XEmbed tray icons will not appear (Waybar's tray
//    could host those). Everything on this machine (Discord, qBittorrent)
//    is SNI.
//  * The Waybar spacer reserves a FIXED width, so a very large number of
//    tray icons could overflow the reserved slot (icons are right-aligned
//    and grow leftward).
Scope {
    id: root

    // ---------- geometry ----------
    // The brightness pill's collapsed left edge is 179px from the screen's
    // right edge (its rightMargin 152 + width 27), so 189 leaves the same
    // 10px gap the old Waybar `#tray { margin-right: 10px }` had.
    readonly property int rightMargin: 180
    readonly property int pillHeight: 24
    readonly property int iconSize: 16
    readonly property int iconSpacing: 6
    readonly property int padH: 8
    readonly property int radius: 8

    // The tray pill's content width: every icon + the gaps between them +
    // the horizontal padding.
    readonly property int contentWidth: trayRow.implicitWidth + root.padH * 2

    // With no registered items the pill would otherwise still paint its
    // horizontal padding as a ~16px dark blob. Hide it (and its input mask)
    // entirely until something registers.
    readonly property bool hasItems: trayIcons.count > 0

    // Publish our live left edge (from the screen's right edge) so the Discord
    // voice pill to our left tracks our real width and never collides — the
    // tray grows leftward as icons register, so a fixed reserved width would
    // eventually overlap it.
    Binding {
        target: PillBus
        property: "trayLeftInset"
        value: root.hasItems ? (root.rightMargin + root.contentWidth) : root.rightMargin
    }

    // The tray item context menu (right-click / menu-only items).
    TrayMenu { id: trayMenu }

    PanelWindow {
        id: win

        anchors {
            top: true
            right: true
        }

        margins {
            top: -24
            right: root.rightMargin
        }

        // Wide enough for the content plus the cluster's full leftward
        // reach, so the pill can slide left without clipping.
        implicitWidth: root.contentWidth + PillBus.maxReach
        implicitHeight: root.pillHeight
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:tray"

        // Only the pill itself takes input; the rest of the surface
        // stays click-through (neighbouring Waybar modules stay clickable).
        mask: Region {
            x: pill.x
            y: pill.y
            width: pill.width
            height: pill.height
            radius: root.radius
        }

        Rectangle {
            id: pill
            anchors.top: parent.top
            // Right edge pinned `rightMargin` from the screen edge; slides
            // left by the live cluster reach while a pill expands. The
            // brightness pill shifts by the same amount, so the 10px gap
            // between them stays constant through the whole animation.
            x: win.width - width - PillBus.reach
            height: root.pillHeight
            width: root.hasItems ? root.contentWidth : 0
            visible: root.hasItems
            radius: root.radius
            color: "#040404"

            Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: root.iconSpacing

                Repeater {
                    id: trayIcons
                    model: SystemTray.items

                    delegate: Item {
                        id: itemRoot
                        width: root.iconSize
                        height: root.iconSize

                        // Needs-attention backdrop, mirroring Waybar's
                        // `#tray > .needs-attention` highlight.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            visible: modelData.status === Status.NeedsAttention
                            radius: 4
                            color: "#eb4d4b"
                            z: -1
                        }

                        Image {
                            anchors.fill: parent
                            source: modelData.icon
                            sourceSize.width: root.iconSize
                            sourceSize.height: root.iconSize
                            smooth: true
                            // Passive items are dimmed, mirroring Waybar's
                            // `#tray > .passive { -gtk-icon-effect: dim; }`.
                            opacity: modelData.status === Status.Passive ? 0.5 : 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor

                            function openMenu() {
                                trayMenu.open(modelData.menu,
                                    root.rightMargin + PillBus.reach)
                            }

                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    if (modelData.hasMenu)
                                        openMenu()
                                } else if (mouse.button === Qt.MiddleButton) {
                                    modelData.secondaryActivate()
                                } else if (modelData.onlyMenu && modelData.hasMenu) {
                                    // Menu-only items have no primary action.
                                    openMenu()
                                } else {
                                    modelData.activate()
                                }
                            }

                            onWheel: function (wheel) {
                                var d = wheel.angleDelta.y
                                if (d !== 0)
                                    modelData.scroll(d > 0 ? 1 : -1, false)
                                wheel.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}
