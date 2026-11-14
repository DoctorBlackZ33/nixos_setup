{ config, lib, pkgs, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  cfg = config.mako;
  keyValue = lib.generators.toKeyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } "=";
  };
in
{
  options.mako = helpers.mkProgramOptions { name = "mako"; package = pkgs.mako; };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    mako.sections.defaults = {
      order = helpers.orders.defaults;
      text = builtins.readFile ./defaults/mako-config;
    };

    mako.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = helpers.orders.defaults + 10;
      text = keyValue cfg.settings;
    };

    files."mako/config".text = helpers.renderSections {
      sections = cfg.sections;
      comment = "#";
    };
  };
}
