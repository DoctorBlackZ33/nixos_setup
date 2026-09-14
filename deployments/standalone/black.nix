{ config, inputs, withSystem, ... }:

let
  modules = config.flake.modules.homeManager;
  lib = inputs.nixpkgs.lib;
  override = lib.optional
    (builtins.pathExists ../../home/users/black/config/hypr/override.lua)
    ../../home/users/black/config/hypr/override.lua;
  production = {
    myHome.hyprland = {
      fragments = [
        ../../home/config/hypr/base.lua
        ../../home/config/hypr/features/keybinds.lua
        ../../home/config/hypr/features/session.lua
        ../../home/config/hypr/themes/default.lua
      ] ++ override;
      startupCommands = [ "quickshell --config black" ];
    };
    myHome.quickshell = {
      activeConfig = "black";
      files = {
        "shell.qml" = {
          source = ./black/config/quickshell/shell.qml;
          recursive = false;
        };
        deployment = {
          source = ./black/config/quickshell/deployment;
          recursive = false;
        };
        shared = {
          source = ../../home/config/quickshell;
          recursive = false;
        };
        user = {
          source = ../../home/users/black/config/quickshell;
          recursive = false;
        };
      };
    };
  };
in {
  flake.homeConfigurations.black = withSystem "x86_64-linux" ({ pkgs, ... }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ modules.user-black production ];
    });
}
