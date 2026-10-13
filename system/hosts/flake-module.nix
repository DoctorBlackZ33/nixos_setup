{ config, ... }:
let
  modules = config.flake.modules.nixos;
in 
{
  flake.modules.nixos = {
    hostMod-devVM = {
      import = [
        ./vm/shared-imports.nix
        ./vm/variables.nix
        ./vm/hardware.nix
      ];
    };
  };
}
