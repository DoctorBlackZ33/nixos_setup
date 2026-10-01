{
  description = "Black's modular desktop and laptop NixOS and Home Manager configuration";

  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz";

    home-manager = {
      url = "https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-cachyos-kernel.url = "https://github.com/xddxdd/nix-cachyos-kernel/archive/dbae8dc454556968710401643aa2c6867d166440.tar.gz";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.home-manager.flakeModules.home-manager
        ./system/modules/flake-module.nix
        ./system/accounts/flake-module.nix
        ./system/hosts/vm/flake-module.nix
        ./home/modules/flake-module.nix
        ./home/profiles/flake-module.nix
        ./home/policies/flake-module.nix
        ./home/users/black/flake-module.nix
        ./deployments/flake-module.nix
      ];
    };
}
