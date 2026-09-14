{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.fish;
in {
  options.myHome.fish = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the shared Fish configuration.";
    };

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
