{ config, ... }:

let
  modules = config.flake.modules.programmod;
in {
  flake.modules.programmod = {
    user-black = {
      imports = [
        modules.profile-base
        modules.profile-development
        modules.profile-desktop
        modules.preferences-black
        modules.sources-black
      ];
    };

    preferences-black = {
      nvf.enable = true;

      environment = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      git.settings = {
        user.name = "DoctorBlack Z 33";
        user.email = "72605982+DoctorBlackZ33@users.noreply.github.com";
        init.defaultBranch = "main";
      };
    };

    sources-black = ./sources.nix;
  };
}
