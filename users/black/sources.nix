# User-owned sources: ordered Hyprland fragments, Quickshell trees and the
# session startup command.
{ ... }:
{
  hyprland.fragments = [
    ./hypr/base.lua
    ./hypr/features/keybinds.lua
    ./hypr/features/session.lua
    ./hypr/themes/default.lua
  ];
  hyprland.startupCommands = [ "quickshell --config black" ];

  quickshell = {
    activeConfig = "black";
    files = {
      "shell.qml".source = ./quickshell/shell.qml;
      shared.source = ./quickshell;
      user.source = ./quickshell-user;
    };
  };
}
