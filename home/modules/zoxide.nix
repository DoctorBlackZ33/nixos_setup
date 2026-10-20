{config, lib, ... }:
let
  cfg = config.homeMod.zoxide;
  fish = config.homeMod.fish;
in
{
  options.homeMod.zoxide = {
    enable = lib.mkEnableOption "enable zoxide home module";

    shellIntegration = lib.mkOption {
      type = lib.types.bool;
      example = "true";
      description = "Enables shell integration";
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
      options = [ "--no-cmd" ];
    } // (lib.optionalAttrs fish.enable {
      enableFishIntegration = cfg.shellIntegration;
    });
  };
}
