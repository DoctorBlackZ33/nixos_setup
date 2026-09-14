import QtQuick
import Quickshell.Hyprland

Row {
    id: workspaceList
    required property var theme
    spacing: workspaceList.theme.spacing

    Repeater {
        model: 10
        WorkspaceButton {
            required property int index
            config: workspaceList.theme
            workspace: index + 1
            active: Hyprland.focusedWorkspace != null
                && Hyprland.focusedWorkspace.id === workspace
        }
    }
}
