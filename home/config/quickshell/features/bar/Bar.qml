import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property var config
    required property var clockService

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: bar.config.barHeight
    color: bar.config.background

    Row {
        id: contents
        anchors.fill: parent
        anchors.leftMargin: bar.config.padding
        anchors.rightMargin: bar.config.padding
        spacing: bar.config.spacing

        WorkspaceList { theme: bar.config }
        Item { Layout.fillWidth: true }
        Text {
            color: bar.config.foreground
            font.pixelSize: bar.config.fontSize
            text: bar.config.label
        }
        NetworkStatus { config: bar.config }
        VolumeStatus { config: bar.config }
        ClockStatus {
            config: bar.config
            clockService: bar.clockService
        }
    }
}
