{ config, inputs, withSystem, ... }:

let
  modules = config.flake.modules.homeManager;
  lib = inputs.nixpkgs.lib;
  overridePath = ../../../home/users/black/config/hypr/override.lua;
  productionOverride = lib.optional (builtins.pathExists overridePath) overridePath;
  liveOverride = lib.optional
    (builtins.pathExists "/etc/nixos/home/users/black/config/hypr/override.lua")
    "/etc/nixos/home/users/black/config/hypr/override.lua";
  production = {
    myHome.hyprland = {
      fragments = [
        ../../../home/config/hypr/base.lua
        ../../../home/config/hypr/features/keybinds.lua
        ../../../home/config/hypr/features/session.lua
        ../../../home/config/hypr/themes/default.lua
      ] ++ productionOverride ++ [ ./config/hypr/host.lua ];
      startupCommands = [ "quickshell --config vm-black" ];
      startupCommandsBeforeLastFragment = true;
    };
    myHome.quickshell = {
      activeConfig = "vm-black";
      files = {
        "shell.qml" = {
          source = ./config/quickshell/shell.qml;
          recursive = false;
        };
        deployment = {
          source = ./config/quickshell/components;
          recursive = false;
        };
        shared = {
          source = ../../../home/config/quickshell;
          recursive = false;
        };
        user = {
          source = ../../../home/users/black/config/quickshell;
          recursive = false;
        };
      };
    };
  };
  live = { config, ... }: {
    myHome.hyprland = {
      fragments = [
        "/etc/nixos/home/config/hypr/base.lua"
        "/etc/nixos/home/config/hypr/features/keybinds.lua"
        "/etc/nixos/home/config/hypr/features/session.lua"
        "/etc/nixos/home/config/hypr/themes/default.lua"
      ] ++ liveOverride ++ [ "/etc/nixos/deployments/vm/black/config/hypr/host.lua" ];
      startupCommands = [ "quickshell --config vm-black" ];
      startupCommandsBeforeLastFragment = true;
    };
    myHome.quickshell = {
      activeConfig = "vm-black";
      files = {
        "shell.qml" = {
          source = config.lib.file.mkOutOfStoreSymlink
            "/etc/nixos/deployments/vm/black/config/quickshell/shell.qml";
          recursive = false;
        };
        deployment = {
          source = config.lib.file.mkOutOfStoreSymlink
            "/etc/nixos/deployments/vm/black/config/quickshell/components";
          recursive = false;
        };
        shared = {
          source = config.lib.file.mkOutOfStoreSymlink
            "/etc/nixos/home/config/quickshell";
          recursive = false;
        };
        user = {
          source = config.lib.file.mkOutOfStoreSymlink
            "/etc/nixos/home/users/black/config/quickshell";
          recursive = false;
        };
      };
    };
  };
in {
  flake.homeConfigurations."black@vm" = withSystem "x86_64-linux" ({ pkgs, ... }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ modules.user-black production ];
    });

  flake.homeConfigurations."black@vm-live" = withSystem "x86_64-linux" ({ pkgs, ... }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ modules.user-black live ];
    });
}
