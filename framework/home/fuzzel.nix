{ config, lib, pkgs, ... }:
let
  cfg = config.fuzzel;
  format = pkgs.formats.ini { };
in
{
  options.fuzzel = {
    enable = lib.mkEnableOption "fuzzel";
    package = lib.mkPackageOption pkgs "fuzzel" { nullable = true; };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      example = {
        main.width = 50;
        colors.background = "202124ee";
      };
      description = "Contents of ~/.config/fuzzel/fuzzel.ini, by section.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    files = lib.mkIf (cfg.settings != { }) {
      ".config/fuzzel/fuzzel.ini".source = format.generate "fuzzel.ini" cfg.settings;
    };
  };
}
