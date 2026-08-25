{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.gh;
in {
  options.myHome.gh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable gh for Github CLI interactions";
    };

    gitCredentialHelper = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enables the use of gh alongside homemanager git credentials";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gh = {
      enable = true;
      gitCredentialHelper = cfg.gitCredentialHelper;
    };
  };
}
