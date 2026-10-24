{ config, inputs, ... }:

{
  flake.modules.nixos = {
    system-base = ./base.nix;
    system-desktop = ./desktop.nix;
    system-development = ./development.nix;
    system-home-admin = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.admin.imports = [ config.flake.modules.homeManager.home-admin ];
      };
    };
    system-k3s = ./k3s.nix;
    system-tailscale = ./tailscale.nix;
    platform-x86_64-linux = ./platforms/x86_64-linux.nix;
    kernel-stock = { pkgs, ... }: {
      boot.kernelPackages = pkgs.linuxPackages;
    };
    kernel-cachy = { pkgs, ... }: {
      nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
      boot.kernelPackages =
        pkgs.cachyosKernels."linuxPackages-cachyos-latest-lto-x86_64-v4";
    };
  };

  perSystem = { pkgs, ... }: {
    formatter = pkgs.alejandra;
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        alejandra
        git
        nil
        nixd
      ];
    };
  };
}
