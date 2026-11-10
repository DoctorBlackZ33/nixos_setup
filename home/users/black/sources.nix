{ ... }:
{
  hyprland = {
    fragments = [
      ../../../home/config/hypr/base.lua
      ../../../home/config/hypr/features/keybinds.lua
      ../../../home/config/hypr/features/session.lua
      ../../../home/config/hypr/themes/default.lua
      ../../../home/config/hypr/host-vm.lua
    ];
    startupCommands = [ "quickshell --config black" ];
  };

  quickshell = {
    activeConfig = "black";
    files = {
      "shell.qml".source = ../../../home/config/quickshell/shell.qml;
      shared.source = ../../../home/config/quickshell;
      user.source = ./config/quickshell;
    };
  };
}
