import QtQuick
import QtQml
import Quickshell

QtObject {
    required property var theme

    property string label: theme.label
    property int barHeight: theme.barHeight
    property color background: "#141418eb"
    property color foreground: "#e6e6e6"
    property color accent: "#5e81ac"
    property color muted: "#888888"
    property int fontSize: 13
    property int padding: 10
    property int spacing: 4
    property string clockFormat: "yyyy-MM-dd HH:mm:ss"
    property int clockPrecision: SystemClock.Seconds
}
