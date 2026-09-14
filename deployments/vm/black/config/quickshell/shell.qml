import QtQuick
import Quickshell
import "deployment"
import "shared/profiles"
import "shared/themes"
import "user"

ShellRoot {
    DefaultTheme { id: defaults }

    HostSettings { id: host }

    UserSettings {
        id: settings
        theme: defaults
        property string label: host.label
        barHeight: host.barHeight
        clockFormat: defaults.clockFormat
        clockPrecision: SystemClock.Minutes
    }

    VmBlackShell {
        id: deployment
        config: settings

        DesktopShell {
            config: deployment.config
        }
    }
}
