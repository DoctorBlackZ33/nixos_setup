# Locale mechanism only. The values are host-specific and have no defaults
# here; unset options leave the NixOS defaults alone.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.sysMod.locale;
in
{
  options.sysMod.locale = {
    timeZone = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "Europe/Zurich";
    };
    defaultLocale = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "en_US.UTF-8";
    };
    extraLocales = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "de_CH.UTF-8/UTF-8" ];
    };
    keyMap = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "us";
      description = "Console keymap.";
    };
  };

  config = {
    time.timeZone = lib.mkIf (cfg.timeZone != null) cfg.timeZone;
    i18n.defaultLocale = lib.mkIf (cfg.defaultLocale != null) cfg.defaultLocale;
    i18n.extraLocales = cfg.extraLocales;
    console.keyMap = lib.mkIf (cfg.keyMap != null) cfg.keyMap;
  };
}
