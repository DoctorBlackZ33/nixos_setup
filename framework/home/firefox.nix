{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.firefox;
in
{
  options.firefox = {
    enable = lib.mkEnableOption "the Firefox user configuration";
    package = lib.mkPackageOption pkgs "firefox" { nullable = true; };
    #TODO: add settings and sections if userChrome.css is wanted

    AppAutoUpdate = mkOption {
      type = types.bool;
      default = false;
      description = "Enables auto updates in general";
    };

    BackgroundAppUpdate = mkOption {
      type = types.bool;
      default = false;
      description = "Enables auto updates in the background";
    };

    DisableTelemetry = mkOption {
      type = types.bool;
      default = true;
      description = "Disables the Telemetry of Firefox";
    };
    
    HardwareAcceleration = mkOption {
      type = types.bool;
      default = true;
      description = "Enables hardware acceleration";
    };
    
    Extensions = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption {
            type = types.str;
            example = "\"uBlock0@raymondhill.net\"";
            description = "the firefox internal id for policies-schema.json";
          };

          name = mkOption {
            type = types.str;
            example = "\"ublock-origin\"";
            description = "Selects the extension to download via https://addons.mozilla.org/firefox/downloads/latest/EXTENSIONNAME/latest.xpi";
          };

          configuration = mkOption { 
            type = types.attrsOf types.anything;
            default = {};
            description = "the extension specific attribute set mapped to its own config schema by the extension itself";
          };
        };
      });
      default = { };
      description = "An attribute set containing submodules for each extension to install";
    };
    DefaultSearchEngine = mkOption {
      type = types.str;
      default = "ddg";
      description = "sets the default search engine for both normal and private tabs";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;
    programs.firefox = {
      AppAutoUpdate = cfg.AppAutoUpdate;
      BackgroundAppUpdate = cfg.BackgroundAppUpdate;
      DisableTelemetry = cfg.DisableTelemetry;
      HardwareAcceleration = cfg.HardwareAcceleration;
      
      ExtensionSettings = let
        moz = short: "https://addons.mozilla.org/firefox/downloads/latest/${short}/latest.xpi";
      in (lib.concatMapAttrs (key: value: {
        ${value.id} = {
          install_url = moz value.name;
          installation_mode = "force_installed";
          updates_disabled = true;
        };
      }) cfg.Extensions) // { "*".installation_mode = "blocked"; };
      
      "3rdparty".Extensions = lib.concatMapAttrs (key: value: {
        ${value.id} = value.configuration;
      }) cfg.Extensions;

      profiles.default.search = {
        force = true;
        default = cfg.DefaultSearchEngine;
        privateDefault = cfg.DefaultSearchEngine;
      };
    };
  };
}
