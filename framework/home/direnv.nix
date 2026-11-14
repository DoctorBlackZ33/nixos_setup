{ config, lib, pkgs, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  cfg = config.direnv;
  toToml = settings: builtins.readFile ((pkgs.formats.toml { }).generate "direnv-settings.toml" settings);
  direnvExe = if cfg.package != null then lib.getExe cfg.package else "direnv";

  fishIntegration = ''
    if status is-interactive
      if not functions -q __direnv_export_eval
        ${direnvExe} hook fish | source
      end
    end
  '';
in
{
  options.direnv = helpers.mkProgramOptions { name = "direnv"; package = pkgs.direnv; } // {
    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable direnv's Fish integration.";
    };
    nixDirenv = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nix-direnv integration.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    fish.sections.direnv = lib.mkIf (config.fish.enable && cfg.enableFishIntegration) {
      order = helpers.orders.integrations + 100;
      text = fishIntegration;
    };

    direnv.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = helpers.orders.settings;
      text = toToml cfg.settings;
    };

    files = lib.mkMerge [
      (lib.mkIf (cfg.sections != { }) {
        "direnv/direnv.toml".text = helpers.renderSections {
          sections = cfg.sections;
          comment = "#";
        };
      })
      (lib.mkIf cfg.nixDirenv.enable {
        "direnv/lib/nix-direnv.sh".source = "${pkgs.nix-direnv}/share/nix-direnv/direnvrc";
      })
    ];
  };
}
