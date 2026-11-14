{ config, lib, pkgs, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  cfg = config.git;
in
{
  options.git = helpers.mkProgramOptions { name = "git"; package = pkgs.git; };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    git.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = helpers.orders.settings;
      text = lib.generators.toGitINI cfg.settings;
    };

    files."git/config".text = helpers.renderSections {
      sections = cfg.sections;
      comment = "#";
    };
  };
}
