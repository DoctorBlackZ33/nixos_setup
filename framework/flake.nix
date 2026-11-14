{
  description = "Framework flake (Mod): homeMod/systemMod modules, contract, reconcile and adapters";

  inputs = {
    # Consumers override this with `inputs.nixpkgs.follows = "nixpkgs"`.
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ ./checks ];

      flake.framework = {
        lib = {
          contract = ./lib/contract.nix;
          reconcile = ./lib/reconcile.nix;
          helpers = ./lib/helpers.nix;
        };

        homeModules = {
          core = ./home/core.nix;
          hyprland = ./home/hyprland.nix;
          fish = ./home/fish.nix;
          git = ./home/git.nix;
          gh = ./home/gh.nix;
          direnv = ./home/direnv.nix;
          yazi = ./home/yazi.nix;
          zoxide = ./home/zoxide.nix;
          fuzzel = ./home/fuzzel.nix;
          mako = ./home/mako.nix;
          quickshell = ./home/quickshell.nix;
          nvf = ./home/nvf.nix;
        };

        systemModules = {
          base = ./system/base.nix;
          nix-settings = ./system/nix-settings.nix;
          development = ./system/development.nix;
          networking = ./system/networking.nix;
          desktop = ./system/desktop.nix;
          locale = ./system/locale.nix;
          greeter = ./system/greeter.nix;
          accounts = ./system/accounts.nix;
        };

        adapters = {
          contract = ./adapters/contract.nix;
          hjem = ./adapters/hjem.nix;
          hjem-register = ./adapters/hjem-register.nix;
          nixos = ./adapters/nixos.nix;
          standalone = ./adapters/standalone.nix;
        };
      };
    };
}
