{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.git;
in {
  options.myHome.git = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Git for this home profile.";
    };
    userName = lib.mkOption {
      type = lib.types.str;
      default = "DoctorBlackZ33";
      description = "The username to commit to git with";
    };
    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "lukas.zuercher05@gmail.com";
      description = "The email address used to commit to git";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = cfg.userName;
          email = cfg.userEmail;
        };
      };
    };
  };
}
