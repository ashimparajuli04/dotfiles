import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

ColumnLayout {
    id: row

    property var node
    property bool isStream: false
    property bool isInput: false
    property bool isDefault: false
    property var sinks: []
    property bool pickerOpen: false

    signal moveRequested(var sink)

    Layout.fillWidth: true
    spacing: 4

    readonly property bool ready: row.node !== null && row.node !== undefined
    readonly property real volume: (row.ready && row.node.audio) ? row.node.audio.volume : 0
    readonly property bool muted: (row.ready && row.node.audio) ? row.node.audio.muted : false
    readonly property bool canMove: row.isStream && row.ready
        && row.prop("object.serial") !== undefined && row.prop("object.serial") !== null

    function prop(name) {
        return (row.ready && row.node.properties) ? row.node.properties[name] : undefined
    }

    function modelValues(m) {
        if (!m)
            return []
        if (m.values !== undefined)
            return m.values
        var out = []
        var n = m.length !== undefined ? m.length : 0
        for (var i = 0; i < n; i++)
            out.push(m[i])
        return out
    }

    function sinkLabel(s) {
        if (!s)
            return "?"
        return s.description || s.nickname || s.name
    }

    function title() {
        if (!row.ready)
            return ""
        if (row.isStream)
            return row.prop("application.name") || row.node.description || row.node.name
        return row.node.description || row.node.nickname || row.node.name
    }

    readonly property string appIconName: row.isStream ? (row.prop("application.icon-name") || "") : ""
    readonly property string appIconPath: (row.appIconName !== "" && Quickshell.hasThemeIcon(row.appIconName))
        ? Quickshell.iconPath(row.appIconName) : ""

    function deviceGlyph() {
        if (row.isStream)
            return "󰝚"
        var d = ((row.prop("device.icon-name") || "") + " " + (row.ready ? row.node.name : "") + " "
            + (row.ready ? row.node.description : "")).toLowerCase()
        if (d.indexOf("headphone") !== -1 || d.indexOf("headset") !== -1 || d.indexOf("earbud") !== -1)
            return "󰋋"
        if (d.indexOf("hdmi") !== -1 || d.indexOf("display") !== -1)
            return "󰍹"
        if (row.isInput)
            return "󰍬"
        return "󰓃"
    }

    // Current output of a stream, from the global link group model.
    readonly property var currentSink: {
        if (!row.isStream || !row.ready)
            return null
        var groups = row.modelValues(Pipewire.linkGroups)
        for (var i = 0; i < groups.length; i++) {
            var g = groups[i]
            if (g.source && g.source.id === row.node.id && g.target && !g.target.isStream
                && (g.target.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
                return g.target
        }
        return null
    }

    // ---- main row ----
    Rectangle {
        id: main
        Layout.fillWidth: true
        implicitHeight: 44
        radius: 12
        color: hover.hovered ? Theme.bgAlt : "transparent"

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (row.isStream || !row.ready)
                    return
                if (row.isInput)
                    Pipewire.preferredDefaultAudioSource = row.node
                else
                    Pipewire.preferredDefaultAudioSink = row.node
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Text {
                visible: !row.isStream || row.appIconPath === ""
                text: row.deviceGlyph()
                color: (!row.isStream && row.isDefault) ? Theme.accent : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 18
            }

            Image {
                visible: row.isStream && row.appIconPath !== ""
                source: row.appIconPath
                sourceSize.width: 18
                sourceSize.height: 18
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                Layout.fillWidth: true
                text: row.title()
                color: (!row.isStream && row.isDefault) ? Theme.accent : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Rectangle {
                id: chip
                visible: row.canMove
                Layout.preferredWidth: Math.min(chipText.implicitWidth + 14, 120)
                Layout.preferredHeight: 22
                radius: 11
                color: chipHover.hovered ? Qt.lighter(Theme.bgAlt, 1.35) : Theme.bgAlt

                HoverHandler {
                    id: chipHover
                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: row.pickerOpen = !row.pickerOpen
                }

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    width: parent.width - 12
                    text: "→ " + row.sinkLabel(row.currentSink)
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            VolumeSlider {
                Layout.preferredWidth: 100
                value: row.volume
                onMoved: function (v) {
                    if (row.ready && row.node.audio)
                        row.node.audio.volume = v
                }
            }

            Text {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: (row.ready && row.node.audio) ? Math.round(row.volume * 100) + "%" : ""
                color: row.muted ? Theme.muted : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Text {
                id: muteBtn
                text: row.isInput ? (row.muted ? "󰍭" : "󰍬") : (row.muted ? "󰖁" : "󰕾")
                color: row.muted ? Theme.muted : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 16

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.ready && row.node.audio)
                            row.node.audio.muted = !row.node.audio.muted
                    }
                }
            }
        }
    }

    // ---- output picker (streams only) ----
    Rectangle {
        Layout.fillWidth: true
        visible: row.pickerOpen
        implicitHeight: pickerCol.implicitHeight + 12
        radius: 12
        color: Theme.bgAlt

        ColumnLayout {
            id: pickerCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 6
            }
            spacing: 2

            Repeater {
                model: row.sinks
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 8
                    color: pickHover.hovered ? Qt.lighter(Theme.bgAlt, 1.35) : "transparent"

                    HoverHandler {
                        id: pickHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            row.pickerOpen = false
                            row.moveRequested(modelData)
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        text: row.sinkLabel(modelData)
                        color: (row.currentSink && row.currentSink.id === modelData.id) ? Theme.accent : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
