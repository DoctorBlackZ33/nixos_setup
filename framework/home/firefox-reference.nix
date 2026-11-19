# Opt-in homeMod reference; firefox.nix remains the automatically imported module.
# In a userConf/homeMod module, select this replacement explicitly:
#   { framework, inputs, ... }: {
#     disabledModules = [ framework.home.modules.firefox ];
#     imports = [ (inputs.self.outPath + "/home/firefox-reference.nix") ];
#   }
# `inputs.self` here is the framework flake, not the config flake. The disabled
# path is exactly framework/home/firefox.nix from that same framework input;
# importing a second copy without disabling the original duplicates its options.
#
# `extraPolicies` is a nixpkgs Firefox package-wrapper argument, not a NixOS,
# Home Manager or Hjem option. The wrapper creates the application's
# lib/firefox/distribution/policies.json (libName can vary). Firefox loads that
# Mozilla enterprise-policy file for every profile; ~/.mozilla/policies.json is
# not a supported per-user policy location. No profile files are needed here.
# Host administrator policies (for example /etc/firefox/policies/policies.json)
# can take precedence over the package file; inspect about:policies in Firefox.
# Existing wrapper arguments/policies are retained; this module's policy values
# take precedence within the wrapper. Nix-managed binaries update through Nix,
# regardless of AppAutoUpdate; BackgroundAppUpdate is a Windows-only policy.
#
# SearchEngines works in release Firefox >=139 and ESR >=60. `ddg` is the Home
# Manager alias for `DuckDuckGo`; other values must be installed engine display
# names, not engine IDs or aliases. Mozilla applies these defaults when the policy
# is first applied or its value changes, not on every activation; users can
# subsequently change them. This is not Home Manager's search.force behavior.
# https://firefox-admin-docs.mozilla.org/reference/policies/searchengines/
#
# The nullable package option is preserved verbatim for interface compatibility.
# This enabled reference requires a nixpkgs wrapper-capable package: null fails
# explicitly rather than silently dropping policies for an external Firefox.
# Set enable = false to emit no package or configuration.
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.firefox;
  searchEngine = if cfg.DefaultSearchEngine == "ddg" then "DuckDuckGo" else cfg.DefaultSearchEngine;
  policies = {
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

    SearchEngines = {
      Default = searchEngine;
      DefaultPrivate = searchEngine;
    };
  };
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
    packages = [
      (if cfg.package == null then
        throw "firefox-reference: firefox.enable requires a nixpkgs Firefox wrapper package; firefox.package = null cannot install enterprise policies. Set firefox.enable = false to emit no package or configuration."
      else cfg.package.override (previous: {
        extraPolicies = lib.recursiveUpdate (previous.extraPolicies or { }) policies;
      }))
    ];
  };
}
