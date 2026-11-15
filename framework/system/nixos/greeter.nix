# greetd + tuigreet login. The session command follows the compositor the
# system actually runs, so there is no second compositor setting to drift.
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.sysMod.greeter;

  compositorCommand =
    if config.programs.hyprland.enable then "start-hyprland"
    else if config.programs.niri.enable then "niri-session"
    else null;

  command = if cfg.command != null then cfg.command else compositorCommand;
in
{
  options.sysMod.greeter = {
    enable = lib.mkEnableOption "a greetd + tuigreet login session";

    user = mkOption {
      type = types.str;
      default = "greeter";
      description = "Unprivileged account the greeter itself runs as.";
    };

    command = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Session started after login. Defaults to the enabled compositor.";
    };

    arguments = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--time" "--remember" ];
      description = "Extra tuigreet arguments (appearance and behaviour).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = command != null;
        message = ''
          host '${config.contract.facts.name}': sysMod.greeter is enabled but no compositor
          is enabled and `sysMod.greeter.command` is unset, so there is nothing to start.
        '';
      }
    ];

    services.greetd = {
      enable = true;
      settings.default_session = {
        inherit (cfg) user;
        command = lib.concatStringsSep " " (
          [ (lib.getExe pkgs.tuigreet) ]
          ++ map lib.escapeShellArg cfg.arguments
          ++ [ "--cmd" (toString command) ]
        );
      };
    };
  };
}
