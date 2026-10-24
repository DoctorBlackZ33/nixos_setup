{ config, ... }:

let
  modules = config.flake.modules.homeManager;
in {
  flake.modules.homeManager.home-admin = {
    imports = [
      modules.module-set-cli
      modules.profile-cli
    ];

    home.username = "admin";
    home.homeDirectory = "/home/admin";
    home.stateVersion = "26.05";
  };
}
