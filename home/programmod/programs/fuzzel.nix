{ config, lib, pkgs, ... }:

let
  cfg = config.fuzzel;
  toKeyValue = lib.generators.toKeyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } "=";
  };
in
{
  options.fuzzel = lib.programmod.mkProgramOptions {
    name = "fuzzel";
    package = pkgs.fuzzel;
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    fuzzel.sections.defaults = lib.programmod.dag.entryBefore [ "settings" ]
      (builtins.readFile ../../config/fuzzel/fuzzel.ini);
    fuzzel.sections.settings = lib.mkIf (cfg.settings != { })
      (lib.programmod.dag.entryAfter [ "defaults" ] (toKeyValue cfg.settings));

    files."fuzzel/fuzzel.ini".text = lib.programmod.renderSections {
      inherit (cfg) sections;
      comment = "#";
    };
  };
}
