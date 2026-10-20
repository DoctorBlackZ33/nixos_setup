{ config, lib, ... }: 
let
  cfg = config.homeMod.fish;
in {
  options.homeMod.fish = {
    enable = lib.mkEnableOption "Enable the fish shell";

    commandColor = lib.mkOption {
      type = lib.types.str;
      default = "brcyan";
      description = "Fish command color.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        set -g fish_color_command ${cfg.commandColor}
      '';
    };
  };
}
