import QtQuick
import Quickshell
import "deployment"
import "shared/profiles"
import "shared/themes"
import "user"

Item {
    DefaultTheme { id: defaults }

    UserSettings {
        id: settings
        theme: defaults
    }

    BlackShell {
        id: deployment
        config: settings

        DesktopShell {
            config: deployment.config
        }
    }
}
