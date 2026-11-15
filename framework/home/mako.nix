{ config, lib, pkgs, ... }:
let
  cfg = config.mako;
  format = pkgs.formats.iniWithGlobalSection { };
in
{
  options.mako = {
    enable = lib.mkEnableOption "mako";
    package = lib.mkPackageOption pkgs "mako" { nullable = true; };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      example = { globalSection.default-timeout = 3000; };
      description = "Contents of ~/.config/mako/config: `globalSection` plus criteria `sections`.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    files = lib.mkIf (cfg.settings != { }) {
      ".config/mako/config".source = format.generate "mako-config" cfg.settings;
    };
  };
}
