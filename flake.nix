{
  description = "Black's declarative NixOS development VM and rice foundation";

  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz";

    home-manager = {
      url = "https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CachyOS's Nix flake provides patched kernels, CachyOS config defaults,
    # and linuxPackages attrsets. The archive URL is pinned to a commit so
    # updates are explicit and reviewable in flake.lock.
    nix-cachyos-kernel.url = "https://github.com/xddxdd/nix-cachyos-kernel/archive/dbae8dc454556968710401643aa2c6867d166440.tar.gz";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    nix-cachyos-kernel,
    ...
  }: let
    system = "x86_64-linux";

    mkSystem = {
      hostModule,
      kernelProfile,
      homeModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit self kernelProfile nix-cachyos-kernel;
        };

        modules = [
          hostModule
          ./system/modules/base.nix
          ./system/modules/desktop.nix
          ./system/modules/development.nix
          ./system/modules/kernel.nix
          ./system/modules/rice.nix
          home-manager.nixosModules.home-manager
          ({config, ...}: {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              users.black = {
                imports = [./home/black.nix] ++ homeModules;
              };
              extraSpecialArgs = {
                inherit self;
                homeContext = {
                  rice = {
                    sourceRoot = config.rice.sourceRoot;
                    devMode = config.rice.devMode;
                  };
                };
              };
            };
          })
        ];
      };
  in {
    nixosConfigurations = {
      nixos-dev = mkSystem {
        hostModule = ./hosts/vm;
        kernelProfile = "stock";
        homeModules = [./home/hosts/vm.nix];
      };
      nixos-dev-cachy = mkSystem {
        hostModule = ./hosts/vm;
        kernelProfile = "cachy";
        homeModules = [./home/hosts/vm.nix];
      };
    };

    # Kept for nixd Home Manager option metadata. Integrated NixOS Home
    # Manager remains the only activation owner.
    homeConfigurations.black = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        homeContext = {
          rice = {
            sourceRoot = "/etc/nixos";
            devMode = false;
          };
        };
      };
      modules = [./home/black.nix ./home/hosts/vm.nix];
    };

    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

    devShells.${system}.default = let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      pkgs.mkShell {
        packages = with pkgs; [
          alejandra
          git
          nil
          nixd
        ];
      };
  };
}
