# Hjem user module: embeds the homeMod class and maps its output onto Hjem.
# Hjem hands the NixOS config in as `osConfig`; that is how host facts reach
# the user layer. This adapter is the only place that sees both sides.
{ config, lib, pkgs, osConfig, framework, moduleArgs, ... }:
let
  cfg = config.homeMod;
in
{
  options.homeMod = lib.mkOption {
    type = framework.home.submodule {
      inherit pkgs moduleArgs;
      inherit (osConfig.contract) facts secretsDirectory;
    };
    description = "Portable user configuration, delivered by the active adapter.";
  };

  config = {
    files = lib.mapAttrs (_: source: { inherit source; }) (framework.home.materialise pkgs cfg.files);
    packages = cfg.packages;
    environment.sessionVariables = cfg.environment;
  };
}
