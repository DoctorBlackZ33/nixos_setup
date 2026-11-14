{ config, lib, pkgs, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  cfg = config.fuzzel;
  keyValue = lib.generators.toKeyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } "=";
  };
in
{
  options.fuzzel = helpers.mkProgramOptions { name = "fuzzel"; package = pkgs.fuzzel; };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    fuzzel.sections.defaults = {
      order = helpers.orders.defaults;
      text = builtins.readFile ./defaults/fuzzel.ini;
    };

    fuzzel.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = helpers.orders.defaults + 10;
      text = keyValue cfg.settings;
    };

    files."fuzzel/fuzzel.ini".text = helpers.renderSections {
      sections = cfg.sections;
      comment = "#";
    };
  };
}
