{ config, lib, pkgs, framework, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.direnv;
  format = pkgs.formats.toml { };
  direnv = if cfg.package != null then lib.getExe cfg.package else "direnv";
in
{
  options.direnv = {
    enable = lib.mkEnableOption "direnv";
    package = lib.mkPackageOption pkgs "direnv" { nullable = true; };

    settings = mkOption {
      inherit (format) type;
      default = { };
      description = "Contents of ~/.config/direnv/direnv.toml.";
    };

    nixDirenv.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the nix-direnv library.";
    };

    enableFishIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Hook direnv into fish when the fish module is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    files = lib.mkMerge [
      (lib.mkIf (cfg.settings != { }) {
        ".config/direnv/direnv.toml".source = format.generate "direnv.toml" cfg.settings;
      })
      (lib.mkIf cfg.nixDirenv.enable {
        ".config/direnv/lib/nix-direnv.sh".source = "${pkgs.nix-direnv}/share/nix-direnv/direnvrc";
      })
    ];

    # After the other integrations: the hook must wrap the final `cd`.
    fish.sections.direnv = lib.mkIf (config.fish.enable && cfg.enableFishIntegration) {
      order = framework.sections.order.after;
      text = ''
        if status is-interactive
          if not functions -q __direnv_export_eval
            ${direnv} hook fish | source
          end
        end
      '';
    };
  };
}
