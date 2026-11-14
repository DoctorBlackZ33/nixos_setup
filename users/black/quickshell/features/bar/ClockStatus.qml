import QtQuick

Text {
    required property var clockService
    required property var config

    color: config.foreground
    font.pixelSize: config.fontSize
    text: clockService.currentTime.toLocaleString(Qt.locale(), config.clockFormat)
}
