{
  description = "Framework flake (Mod): user and system modules, contract, reconcile and adapters";

  # The framework names every dependency its adapters and modules need. A
  # config flake pins them by making each one follow its own input, so its
  # lock file is the single source of truth for what gets deployed.
  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz";

    flake-parts.url = "github:hercules-ci/flake-parts";

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The release branch must match the nixpkgs release.
    system-manager = {
      url = "github:numtide/system-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { flake-parts, nixpkgs, ... }:
    let
      framework = import ./lib {
        inherit (nixpkgs) lib;
        inherit inputs;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [ flake-parts.flakeModules.modules ];

      flake = {
        # For config flakes: `imports = [ inputs.framework.flakeModules.default ];`
        flakeModules.default = import ./flake-module.nix { frameworkInputs = inputs; };

        lib = framework;

        # The same module sets the adapters import, for reuse and
        # `disabledModules`.
        modules = {
          homeMod = framework.home.modules;
          nixos = framework.modules.discover ./system/common // framework.modules.discover ./system/nixos;
          systemManager = framework.modules.discover ./system/common;
        };
      };

      perSystem = { pkgs, system, ... }: {
        checks = import ./checks {
          inherit pkgs system nixpkgs inputs;
        };

        formatter = pkgs.alejandra;
      };
    };
}
