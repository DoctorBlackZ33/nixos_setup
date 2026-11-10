{
  description = "Black's modular NixOS and programmod configuration";

  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz";

    hjem = {
      url = "github:feel-co/hjem";
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
        ./system/modules/flake-module.nix
        ./system/accounts/flake-module.nix
        ./system/hosts/vm/flake-module.nix
        ./home/programmod/flake-module.nix
        ./home/profiles/flake-module.nix
        ./home/policies/flake-module.nix
        ./home/users/black/flake-module.nix
        ./deployments/flake-module.nix
      ];
    };
}
