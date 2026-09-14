{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.zoxide;
in {
  options.myHome.zoxide = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Zoxide and its Fish integration.";
    };

    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zoxide's Fish integration.";
    };

    options = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["--cmd=cd"];
      description = "Command-line options passed to zoxide init.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
      enableFishIntegration = cfg.enableFishIntegration;
      options = cfg.options;
    };
  };
}
