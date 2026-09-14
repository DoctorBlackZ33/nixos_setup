import QtQuick

Text {
    required property var config

    color: config.foreground
    font.pixelSize: config.fontSize
    text: "network"
}
