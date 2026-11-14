{ config, lib, pkgs, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  cfg = config.yazi;
  toToml = settings: builtins.readFile ((pkgs.formats.toml { }).generate "yazi-settings.toml" settings);
  yaziExe = if cfg.package != null then lib.getExe cfg.package else "yazi";

  fishIntegration = ''
    function y
      set -l tmp (mktemp -t "yazi-cwd.XXXXX")
      command ${lib.escapeShellArg yaziExe} $argv --cwd-file="$tmp"
      if read cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
      end
      rm -f -- "$tmp"
    end
    if status is-interactive
      bind ${lib.escapeShellArg cfg.fishKey} ${lib.escapeShellArg cfg.fishCommand}${lib.optionalString cfg.fishRepaint " repaint"}
    end
  '';
in
{
  options.yazi = helpers.mkProgramOptions { name = "yazi"; package = pkgs.yazi; } // {
    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Yazi's Fish function and key binding.";
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
    packages = lib.optional (cfg.package != null) cfg.package;

    yazi.settings.mgr.show_hidden = lib.mkDefault true;
    yazi.settings.mgr.sort_by = lib.mkDefault "natural";
    yazi.settings.mgr.sort_dir_first = lib.mkDefault true;

    yazi.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = helpers.orders.settings;
      text = toToml cfg.settings;
    };

    files."yazi/yazi.toml".text = helpers.renderSections {
      sections = cfg.sections;
      comment = "#";
    };

    fish.sections.yazi = lib.mkIf (config.fish.enable && cfg.enableFishIntegration) {
      order = helpers.orders.integrations + 200;
      text = fishIntegration;
    };
  };
}
