{ config, lib, ... }:
let
  cfg = config.homeMod.hyprland;
in 
{
  options.homeMod.hyprland = {
    enable = lib.mkEnableOption "Enable Hyprland and its config generation";
    fragments = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
      default = [];
      description = "Loads lua fragments as strings or from files to add functionality to Hyprland";
    };
    fragmentConfigs = lib.mkOption {
      type = lib.types.attrListOf lib.types.str;
      default =  {};
      description = "Takes a list of attributes that map to settings in the homeMod.hyprland.fragments";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland.enable = true;
  };
}
