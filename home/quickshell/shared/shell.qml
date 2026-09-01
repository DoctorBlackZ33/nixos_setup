import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  anchors {
    top: true
    left: true
    right: true
  }
  implicitHeight: Generated.barHeight
  exclusiveZone: implicitHeight
  color: "transparent"

  Rectangle {
    anchors.fill: parent
    color: Generated.background

    Text {
      anchors.centerIn: parent
      color: Generated.foreground
      text: Generated.label
    }
  }
}
