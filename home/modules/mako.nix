{ config, lib, pkgs, ... }:

let
  cfg = config.myHome.mako;
in {
  options.myHome.mako.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the native Mako notification configuration.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.mako ];
    home.file.".config/mako/config".source = ../config/mako/config;
  };
}
