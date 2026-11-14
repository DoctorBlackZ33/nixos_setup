# Login session. The compositor command is derived from the merged capability
# requirements instead of a second compositor enum that could drift.
{ config, lib, pkgs, ... }:
let
  cfg = config.sysMod.greeter;

  requiredServices = config.homeModRequires.services;

  compositorCommand =
    if builtins.hasAttr "hyprland" requiredServices then "start-hyprland"
    else if builtins.hasAttr "niri" requiredServices then "niri-session"
    else null;

  command = if cfg.command != null then cfg.command else compositorCommand;
in
{
  options.sysMod.greeter = {
    enable = lib.mkEnableOption "a greetd + tuigreet login session";
    user = lib.mkOption {
      type = lib.types.str;
      default = "black";
      description = "User the greeter runs as.";
    };
    command = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Command started after login. Defaults to the required compositor.";
    };
  };

  config = lib.mkIf (cfg.enable && config.facts.managed == "nixos") {
    services.greetd = {
      enable = true;
      settings.default_session = {
        inherit (cfg) user;
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${toString command}";
      };
    };
  };
}
