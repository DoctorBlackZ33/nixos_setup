import QtQuick
import Quickshell.Hyprland

Rectangle {
    required property var config
    required property int workspace
    required property bool active

    color: active ? config.accent : "transparent"
    implicitWidth: 28
    implicitHeight: config.barHeight

    Text {
        anchors.centerIn: parent
        color: config.foreground
        text: workspace
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspace + " })")
    }
}
