{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.gh;
  format = pkgs.formats.yaml { };
  helper = "${lib.getExe cfg.package} auth git-credential";
in
{
  options.gh = {
    enable = lib.mkEnableOption "the GitHub CLI";
    package = lib.mkPackageOption pkgs "gh" { nullable = true; };

    settings = mkOption {
      inherit (format) type;
      default = { };
      description = "Contents of ~/.config/gh/config.yml.";
    };

    gitCredentialHelper = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Use gh as the Git credential helper when the git module is enabled.";
      };
      hosts = mkOption {
        type = types.listOf types.str;
        default = [ "https://github.com" "https://gist.github.com" ];
        description = "Hosts served by the gh credential helper.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    gh.settings.version = lib.mkDefault "1";

    files.".config/gh/config.yml".source = format.generate "gh-config.yml" cfg.settings;

    # The empty first entry resets helpers inherited from system git config.
    git.settings.credential = lib.mkIf
      (config.git.enable && cfg.gitCredentialHelper.enable && cfg.package != null)
      (lib.genAttrs cfg.gitCredentialHelper.hosts (_: { helper = [ "" helper ]; }));
  };
}
