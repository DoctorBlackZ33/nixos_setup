{ config, inputs, ... }:
let
  modules = config.flake.modules.nixos;
in 
{
  flake.nixosConfigurations = {
    vm = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        modules.account-black
        modules.hostMod-vm
      ];
    };
  };
}
  
