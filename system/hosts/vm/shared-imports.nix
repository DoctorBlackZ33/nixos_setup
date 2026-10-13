{ config, ... }:
let
  modules = config.flake.modules.nixos;
in 
{
  imports = [
    modules.sysMod-nix-settings
    modules.sysMod-desktop
    modules.sysMod-development
    modules.sysMod-networking
    modules.sysMod-tty
  ];
}

