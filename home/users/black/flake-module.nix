{ config, ... }:

let
  modules = config.flake.modules.homeManager;
  identity = {
    username = "black";
    homeDirectory = "/home/black";
    stateVersion = "26.05";
  };
in {
  flake.modules.homeManager.user-black = {
    imports = [
      modules.module-set
      modules.profile-base
      modules.profile-development
      modules.profile-desktop
    ];

    home.username = identity.username;
    home.homeDirectory = identity.homeDirectory;
    home.stateVersion = identity.stateVersion;
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

  flake.modules.nixos.user-black-account = { pkgs, ... }:
    {
      users.mutableUsers = false;
      users.users.${identity.username} = {
        isNormalUser = true;
        description = "Black";
        shell = pkgs.fish;
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "input"
        ];
        # Bootstrap-only VM password. Change this value before using the VM
        # for anything sensitive.
        hashedPassword = "$6$nixosdev$QyqUycwLZRiiEsmZ4jzHtrAwIZ8EdPikwJnmrFAygYLP9/LO2wGcFGF4UrykL8niiDRN76b8ayhPtTAG/Pj7x1";
      };
    };
}
