{ config, inputs, ... }:

let
  modules = config.flake.modules.nixos;
in {
  flake.nixosConfigurations = {
    desktop = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        modules.host-desktop
        modules.account-black
        modules.kernel-stock
        modules.system-k3s
        modules.system-tailscale
      ];
    };

    laptop = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        modules.host-laptop
        modules.account-black
        modules.kernel-stock
      ];
    };
  };
}
