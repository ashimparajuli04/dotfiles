import QtQuick
import Quickshell

// One entry in the Quickshell tray context menu (TrayMenu.qml). Renders a
// separator, a check/radio indicator, an optional icon, the label and a
// submenu arrow. `entry` is a QsMenuEntry (from QsMenuOpener.children).
Item {
    id: root

    property var entry

    signal activated()
    signal hovered()
    signal submenuRequested()

    readonly property bool sep: root.entry ? root.entry.isSeparator : false
    readonly property bool usable: root.entry ? root.entry.enabled : false
    readonly property bool hasSub: root.entry ? root.entry.hasChildren : false
    readonly property bool hasCheck: root.entry
        ? root.entry.buttonType !== QsMenuButtonType.None : false
    readonly property bool hasIcon: root.entry ? root.entry.icon !== "" : false

    implicitWidth: label.implicitWidth + 56 + (root.hasCheck ? 20 : 0) + (root.hasIcon ? 22 : 0)
    implicitHeight: root.sep ? 9 : 28

    // Hover highlight.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        visible: !root.sep && hover.hovered && root.usable
        radius: 6
        color: Theme.active
    }

    // Separator line.
    Rectangle {
        visible: root.sep
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: Theme.muted
        opacity: 0.35
    }

    Text {
        id: check
        visible: !root.sep && root.hasCheck
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        text: !root.entry ? "" : root.entry.buttonType === QsMenuButtonType.RadioButton
            ? (root.entry.checkState === Qt.Checked ? "●" : "")
            : (root.entry.checkState === Qt.Checked ? "✓" : "")
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Image {
        id: icon
        visible: !root.sep && root.hasIcon
        anchors.left: root.hasCheck ? check.right : parent.left
        anchors.leftMargin: root.hasCheck ? 6 : 10
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        source: root.entry ? root.entry.icon : ""
        sourceSize.width: 16
        sourceSize.height: 16
        smooth: true
    }

    Text {
        id: label
        visible: !root.sep
        anchors.left: root.hasIcon ? icon.right
            : (root.hasCheck ? check.right : parent.left)
        anchors.leftMargin: (root.hasIcon || root.hasCheck) ? 8 : 10
        anchors.right: arrow.visible ? arrow.left : parent.right
        anchors.rightMargin: arrow.visible ? 6 : 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.entry ? root.entry.text : ""
        // Some apps (e.g. Discord) put markup like <u> </u> in labels.
        textFormat: Text.StyledText
        elide: Text.ElideRight
        color: root.usable ? Theme.fg : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Text {
        id: arrow
        visible: !root.sep && root.hasSub
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅂"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered && root.usable && !root.sep)
            root.hovered()
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.sep && root.usable
        cursorShape: (!root.sep && root.usable) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.hasSub)
                root.submenuRequested()
            else
                root.activated()
        }
    }
}
