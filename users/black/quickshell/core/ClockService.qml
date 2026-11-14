import QtQuick
import Quickshell

Item {
    visible: false
    property int clockPrecision: SystemClock.Seconds
    readonly property date currentTime: clock.date

    SystemClock {
        id: clock
        precision: clockPrecision
    }
}
