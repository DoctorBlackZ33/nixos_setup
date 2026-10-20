{ config, lib, ... }:
let
  cfg = config.homeMod.yazi;
  fish = config.homeMod.fish;
in
{
  options.homeMod.yazi = {
    enable = lib.mkEnableOption "enable yazi home module";
    
    shellIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = "true";
      description = "Enables shell integration";
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
    } // (lib.optionalAttrs fish.enable {
      enableFishIntegration = true;
    });
    
    programs.fish = lib.mkIf fish.enable {
      binds.${cfg.shellKey} = {
        command = cfg.shellCommand;
      };
    };
  };
}
