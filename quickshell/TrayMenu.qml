import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Context menu for a system tray item, rendered by Quickshell itself.
//
// Qt's platform menu (QsMenuAnchor + `//@ pragma UseQApplication`) cannot be
// used here: it creates a QMenu popup that must attach as an xdg_popup, and a
// layer-shell surface (the tray pill) can't be an xdg_popup parent — Wayland
// rejects it and the menu closes instantly. So we walk the item's DBusMenu
// with QsMenuOpener and draw the entries ourselves. One submenu level is
// supported (enough for real tray menus). See changes.md §36.
//
// Opened by TrayWidget.qml on right-click (or left-click on menu-only items).
Scope {
    id: root

    property bool opened: false
    property var menuHandle: null      // a QsMenuHandle (the tray item's .menu)
    property var subEntry: null        // the QsMenuEntry whose children are shown
    property real anchorRight: 6       // screen-right → menu's right edge
    property int labelCap: 240         // longest label before eliding

    function open(handle, right) {
        if (!handle)
            return
        // Close any other open popover first (mirrors the panel behaviour) —
        // in-process via PillBus (no `qs ipc` subprocesses). See PillBus.qml.
        PillBus.hideOthers("")
        root.subEntry = null
        root.menuHandle = handle
        root.anchorRight = right
        root.opened = true
    }

    function close() {
        root.opened = false
        root.menuHandle = null
        root.subEntry = null
    }

    QsMenuOpener { id: mainOpener; menu: root.menuHandle }
    QsMenuOpener { id: subOpener; menu: root.subEntry }

    readonly property bool subVisible: root.subEntry !== null
        && subOpener.children && subOpener.children.values.length > 0

    readonly property real mainWidth: Math.min(root.labelCap + 60,
        Math.max(190, mainColumn.implicitWidth + 8))
    readonly property real subWidth: Math.min(root.labelCap + 60,
        Math.max(150, subColumn.implicitWidth + 8))

    // Transparent click-catcher: closes the menu on any click outside it.
    // Starts below the 31px bar so the bar stays clickable.
    PanelWindow {
        visible: root.opened
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
        WlrLayershell.namespace: "quickshell:tray-menu-catcher"

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    PanelWindow {
        id: win
        visible: root.opened

        anchors {
            top: true
            right: true
        }
        margins {
            top: 6
            right: root.anchorRight
        }

        implicitWidth: mainColumn.width + (root.subVisible ? subColumn.width + 4 : 0) + 16
        implicitHeight: Math.max(mainColumn.implicitHeight, subColumn.implicitHeight) + 16
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:tray-menu"
        WlrLayershell.keyboardFocus: root.opened
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Rectangle {
            id: frame
            anchors.fill: parent
            focus: true
            color: Theme.bg
            radius: 10
            border.color: "#1F1F1F"
            border.width: 1

            Keys.onEscapePressed: root.close()

            Column {
                id: mainColumn
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 8
                width: root.mainWidth

                Repeater {
                    model: mainOpener.children

                    delegate: TrayMenuRow {
                        width: mainColumn.width
                        entry: modelData
                        onHovered: root.subEntry = modelData.hasChildren ? modelData : null
                        onSubmenuRequested: root.subEntry = modelData
                        onActivated: {
                            modelData.triggered()
                            root.close()
                        }
                    }
                }
            }

            Column {
                id: subColumn
                visible: root.subVisible
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.left: mainColumn.right
                anchors.leftMargin: 4
                width: root.subWidth

                Repeater {
                    model: root.subEntry ? subOpener.children : []

                    delegate: TrayMenuRow {
                        width: subColumn.width
                        entry: modelData
                        // Deeper nesting than one submenu level is not
                        // supported; sub-submenu parents just do nothing.
                        onActivated: {
                            modelData.triggered()
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
