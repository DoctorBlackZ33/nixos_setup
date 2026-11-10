{ config, lib, pkgs, ... }:

let
  cfg = config.direnv;
  toToml = settings: builtins.readFile ((pkgs.formats.toml { }).generate "direnv-settings.toml" settings);
  direnvExe = if cfg.package != null then lib.getExe cfg.package else "direnv";
in
{
  options.direnv = lib.programmod.mkProgramOptions {
    name = "direnv";
    package = pkgs.direnv;
  } // {
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

    fish.sections.direnv = lib.mkIf cfg.enableFishIntegration (lib.mkDefault
      (lib.programmod.dag.entryAfter [ "settings" "programmod-environment" "zoxide" ] ''
        if status is-interactive
          if not functions -q __direnv_export_eval
            ${direnvExe} hook fish | source
          end
        end
      '')
    );

    direnv.sections.settings = lib.mkIf (cfg.settings != { }) (toToml cfg.settings);

    files = lib.mkMerge [
      (lib.mkIf (cfg.sections != { }) {
        "direnv/direnv.toml".text = lib.programmod.renderSections {
          inherit (cfg) sections;
          comment = "#";
        };
      })
      (lib.mkIf cfg.nixDirenv.enable {
        "direnv/lib/nix-direnv.sh".source = "${pkgs.nix-direnv}/share/nix-direnv/direnvrc";
      })
    ];
  };
}
