{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.yazi;
in {
  options.myHome.yazi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Yazi and its Fish integration.";
    };

    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Yazi's Fish integration.";
    };

    showHidden = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show hidden files in Yazi.";
    };

    sortBy = lib.mkOption {
      type = lib.types.str;
      default = "natural";
      description = "Yazi sort field.";
    };

    sortDirFirst = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Place directories before files in Yazi.";
    };

    fishKey = lib.mkOption {
      type = lib.types.str;
      default = "ctrl-x";
      description = "Fish key bound to the Yazi wrapper.";
    };

    fishCommand = lib.mkOption {
      type = lib.types.str;
      default = "y";
      description = "Command run by the Yazi Fish binding.";
    };

    fishRepaint = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Repaint Fish after the Yazi binding runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      enableFishIntegration = cfg.enableFishIntegration;
      settings.mgr = {
        show_hidden = cfg.showHidden;
        sort_by = cfg.sortBy;
        sort_dir_first = cfg.sortDirFirst;
      };
    };

    programs.fish.binds.${cfg.fishKey} = {
      command = cfg.fishCommand;
      repaint = cfg.fishRepaint;
    };
  };
}
