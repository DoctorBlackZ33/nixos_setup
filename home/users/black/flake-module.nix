{ config, ... }:

let
  modules = config.flake.modules.homeManager;
  homeTarget = {
    username = "black";
    homeDirectory = "/home/black";
    stateVersion = "26.05";
  };
in {
  flake.modules.homeManager = {
    home-black = {
      home.username = homeTarget.username;
      home.homeDirectory = homeTarget.homeDirectory;
      home.stateVersion = homeTarget.stateVersion;
    };

    preferences-black = {
      imports = [
        modules.module-set
        modules.profile-base
        modules.profile-development
        modules.profile-desktop
      ];

      myHome.nvf.enable = true;

      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      programs.git.settings = {
        user.name = "DoctorBlack Z 33";
        user.email = "72605982+DoctorBlackZ33@users.noreply.github.com";
        init.defaultBranch = "main";
      };
    };

    sources-black = ./sources.nix;
  };
}
