{ config, lib, pkgs, ... }:

let
  cfg = config.mako;
  toKeyValue = lib.generators.toKeyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } "=";
  };
in
{
  options.mako = lib.programmod.mkProgramOptions {
    name = "mako";
    package = pkgs.mako;
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    mako.sections.defaults = lib.programmod.dag.entryBefore [ "settings" ]
      (builtins.readFile ../../config/mako/config);
    mako.sections.settings = lib.mkIf (cfg.settings != { })
      (lib.programmod.dag.entryAfter [ "defaults" ] (toKeyValue cfg.settings));

    files."mako/config".text = lib.programmod.renderSections {
      inherit (cfg) sections;
      comment = "#";
    };
  };
}
