{ config, lib, ... }: 
let
  cfg = config.homeMod.gh;
in {
  options.homeMod.gh = {
    enable = lib.mkEnableOption "Enable gh for github authentication";

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
      gitCredentialHelper.enable = cfg.gitCredentialHelper.enable;
    };
  };
}
