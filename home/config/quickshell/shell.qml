import QtQuick
import Quickshell
import "."
import "shared/profiles"
import "shared/themes"
import "user"

ShellRoot {
    DefaultTheme { id: defaults }
    DesktopPolicy { id: role }

    UserSettings {
        id: settings
        theme: defaults
        label: role.label
        barHeight: defaults.barHeight
        clockFormat: role.clockFormat
        clockPrecision: role.clockPrecision
    }

    DesktopShell {
        config: settings
    }
}
