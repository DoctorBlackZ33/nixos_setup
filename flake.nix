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

  outputs = inputs@{
    self,
    nixpkgs,
    home-manager,
    nix-cachyos-kernel,
    ...
  }:
    let
      system = "x86_64-linux";

      mkSystem = kernelProfile: nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit self kernelProfile nix-cachyos-kernel;
        };

        modules = [
          ./hosts/vm
          ./modules/base.nix
          ./modules/desktop.nix
          ./modules/development.nix
          ./modules/kernel.nix
          ./modules/rice.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              users.black = import ./home/black.nix;
              extraSpecialArgs = { inherit self; };
            };
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        nixos-dev = mkSystem "stock";
        nixos-dev-cachy = mkSystem "cachy";
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;

      devShells.${system}.default =
        let
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
