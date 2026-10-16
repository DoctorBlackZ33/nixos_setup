{ config, lib, ... }:
let
  cfg = config.homeMod.yazi;
in
{
  options.homeMod.yazi = {
    enable = lib.mkEnableOption "enable yazi home module";
    
    shellIntegration = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "fish" ]);
      default = null;
      example = "fish";
      description = "Choose with which shell yazi should interact, enables things like navigation via yazi";
    };
    
    shellKey = lib.mkOption {
      type = lib.types.str;
      default = "ctrl-x";
      description = "Keybind to open yazi via its wrapper as a tui in the current terminal, see shellIntegration for using it for navigation";
    };

    shellCommand = lib.mkOption { 
      type = lib.types.str;
      default = "y";
      description = "The command that runs Yazi via its binding";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
    } // (lib.optionalAttrs (cfg.shellIntegration == "fish") {
      enableFishIntegration = true;
    });
    
    programs.fish = lib.mkIf (cfg.shellIntegration == "fish") {
      binds.${cfg.shellKey} = {
        command = cfg.shellCommand;
      };
    };
  };
}
