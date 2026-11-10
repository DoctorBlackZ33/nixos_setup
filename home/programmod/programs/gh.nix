{ config, lib, pkgs, ... }:

let
  cfg = config.gh;
  credentialSettings = builtins.listToAttrs (map (host: {
    name = host;
    value.helper = [
      ""
      "${cfg.package}/bin/gh auth git-credential"
    ];
  }) cfg.gitCredentialHelper.hosts);
in
{
  options.gh = lib.programmod.mkProgramOptions {
    name = "GitHub CLI";
    package = pkgs.gh;
  } // {
    gitCredentialHelper = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Configure Git to use gh as a credential helper.";
      };
      hosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "https://github.com" "https://gist.github.com" ];
        description = "GitHub hosts using the gh Git credential helper.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    gh.sections.settings = lib.generators.toYAML { }
      ({ version = "1"; } // cfg.settings);

    files."gh/config.yml".text = lib.programmod.renderSections {
      inherit (cfg) sections;
      comment = "#";
    };

    git.settings.credential = lib.mkIf (cfg.gitCredentialHelper.enable && cfg.package != null)
      (lib.mkDefault credentialSettings);
  };
}
