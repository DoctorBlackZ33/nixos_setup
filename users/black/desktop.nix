# Graphical session, on workstations only: Hyprland, Quickshell bar, launcher
# and notifications, with the user-owned sources and looks they use.
{ lib, pkgs, facts, ... }:
{
  config = lib.mkIf (facts.kind == "workstation") {
    packages = with pkgs; [
      bashInteractive
      grim
      kitty
      wl-clipboard
    ];

    hyprland = {
      enable = true;
      fragments = [
        ./hypr/base.lua
        ./hypr/features/keybinds.lua
        ./hypr/features/session.lua
        ./hypr/themes/default.lua
      ];
      startupCommands = [ "quickshell --config black" ];
      # A host may pick another chord.
      floatingToggleChord = lib.mkDefault "SUPER + V";
    };

    quickshell = {
      enable = true;
      activeConfig = "black";
      files = {
        "shell.qml".source = ./quickshell/shell.qml;
        shared.source = ./quickshell;
        user.source = ./quickshell-user;
      };
    };

    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "Sans:size=12";
          width = 40;
          lines = 12;
          horizontal-pad = 16;
          vertical-pad = 10;
          inner-pad = 8;
        };
        colors = {
          background = "202124ee";
          text = "eeeeeeff";
          match = "88c0d0ff";
          selection = "5e81acff";
          border = "5e81acff";
        };
        border.width = 2;
      };
    };

    mako = {
      enable = true;
      settings.globalSection = {
        font = "Sans 11";
        background-color = "#202124ee";
        text-color = "#eeeeee";
        border-color = "#5e81ac";
        border-size = 2;
        border-radius = 8;
        padding = 10;
        default-timeout = 5000;
      };
    };
  };
}
