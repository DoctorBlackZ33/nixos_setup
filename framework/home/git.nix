{ config, lib, pkgs, ... }:
let
  cfg = config.git;
  format = pkgs.formats.gitIni { listsAsDuplicateKeys = true; };
in
{
  options.git = {
    enable = lib.mkEnableOption "git";
    package = lib.mkPackageOption pkgs "git" { nullable = true; };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      example = { init.defaultBranch = "main"; };
      description = "Contents of ~/.config/git/config.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    files.".config/git/config".source = format.generate "git-config" cfg.settings;
  };
}
