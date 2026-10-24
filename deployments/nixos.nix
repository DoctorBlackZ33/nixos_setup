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

    k3-vm-1 = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        modules.host-k3-vm-1
        modules.account-admin
        modules.kernel-stock
        modules.system-home-admin
        modules.system-tailscale
      ];
    };

    k3-vm-2 = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        modules.host-k3-vm-2
        modules.account-admin
        modules.kernel-stock
        modules.system-home-admin
        modules.system-tailscale
      ];
    };
  };
}
