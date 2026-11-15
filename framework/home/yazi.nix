{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.yazi;
  format = pkgs.formats.toml { };
  yazi = if cfg.package != null then lib.getExe cfg.package else "yazi";
in
{
  options.yazi = {
    enable = lib.mkEnableOption "yazi";
    package = lib.mkPackageOption pkgs "yazi" { nullable = true; };

    settings = mkOption {
      inherit (format) type;
      default = { };
      example = { mgr.show_hidden = true; };
      description = "Contents of ~/.config/yazi/yazi.toml.";
    };

    enableFishIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Add the `y` wrapper (cd on exit) when the fish module is enabled.";
    };

    fishKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "ctrl-x";
      description = "Fish key bound to the `y` wrapper; null binds nothing.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    files = lib.mkIf (cfg.settings != { }) {
      ".config/yazi/yazi.toml".source = format.generate "yazi.toml" cfg.settings;
    };

    fish.sections.yazi = lib.mkIf (config.fish.enable && cfg.enableFishIntegration) {
      text = ''
        function y
          set -l tmp (mktemp -t "yazi-cwd.XXXXX")
          command ${lib.escapeShellArg yazi} $argv --cwd-file="$tmp"
          if read cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
          end
          rm -f -- "$tmp"
        end
      '' + lib.optionalString (cfg.fishKey != null) ''
        if status is-interactive
          bind ${lib.escapeShellArg cfg.fishKey} y repaint
        end
      '';
    };
  };
}
