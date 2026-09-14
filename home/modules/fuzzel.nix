{ config, lib, pkgs, ... }:

let
  cfg = config.myHome.fuzzel;
in {
  options.myHome.fuzzel.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the native Fuzzel configuration.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.fuzzel ];
    home.file.".config/fuzzel/fuzzel.ini".source = ../config/fuzzel/fuzzel.ini;
  };
}
