{ config, lib, pkgs, ... }:

let
  cfg = config.git;
in
{
  options.git = lib.programmod.mkProgramOptions {
    name = "git";
    package = pkgs.git;
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    git.sections.settings = lib.mkIf (cfg.settings != { })
      (lib.generators.toGitINI cfg.settings);

    files."git/config".text = lib.programmod.renderSections {
      inherit (cfg) sections;
      comment = "#";
    };
  };
}
