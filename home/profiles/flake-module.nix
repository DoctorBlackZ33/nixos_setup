{ config, ... }:

let
  modules = config.flake.modules.homeManager;
in {
  flake.modules.homeManager = {
    profile-base = ./base.nix;
    profile-cli = {
      imports = [
        modules.profile-base
        modules.profile-development
        ./cli.nix
      ];
    };
    profile-desktop = ./desktop.nix;
    profile-development = ./development.nix;
  };
}
