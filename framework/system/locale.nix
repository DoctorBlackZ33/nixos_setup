{ config, lib, ... }:
let
  cfg = config.sysMod.locale;
in
{
  options.sysMod.locale = {
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Zurich";
      description = "System time zone.";
    };
    defaultLocale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "Default locale.";
    };
    extraLocales = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "en_US.UTF-8/UTF-8" ];
      description = "Additional locales.";
    };
    keyMap = lib.mkOption {
      type = lib.types.str;
      default = "us";
      description = "Console keymap.";
    };
  };

  config = lib.mkIf (config.facts.managed == "nixos") {
    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = cfg.defaultLocale;
    i18n.extraLocales = cfg.extraLocales;
    console.keyMap = cfg.keyMap;
  };
}
