import QtQuick
import "../core"
import "../features/bar"

Item {
    id: shell
    required property var config

    property var clockService: clockServiceObject
    ClockService {
        id: clockServiceObject
        clockPrecision: shell.config.clockPrecision
    }

    Bar {
        config: shell.config
        clockService: shell.clockService
    }
}
