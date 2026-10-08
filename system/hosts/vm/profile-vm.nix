{ config, ... }:
let
  modules = config.flake.modules.nixos;
in 
{
  flake.modules.nixos = {
    hostMod-vm.hardware = ./hardware.nix;
    hostMod-vm.variables = ./variables.nix;
    imports = [
      modules.sysMod-nix-settings
      modules.sysMod-desktop
      modules.sysMod-development
      modules.sysMod-networking
      modules.sysMod-tty
    ];
  };
}

