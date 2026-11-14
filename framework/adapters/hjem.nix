# Hjem user module: declares the homeMod class and maps its output onto Hjem.
# Hjem evaluates this once per user via `hjem.extraModules`, and hands the
# NixOS config in as `osConfig`, which is how facts reach the user layer.
args@{ config, lib, pkgs, osConfig, ... }:
let
  homeModuleFiles = builtins.filter (path: lib.hasSuffix ".nix" (toString path))
    (lib.mapAttrsToList (name: _: ../home + "/${name}") (builtins.readDir ../home));

  materialise = path: file:
    if file.text != null then pkgs.writeText (baseNameOf path) file.text else file.source;

  cfg = config.homeMod;
in
{
  options.homeMod = lib.mkOption {
    type = lib.types.submoduleWith {
      class = "homeMod";
      specialArgs = { inherit (osConfig) facts; inherit pkgs; } // lib.optionalAttrs (args ? nvf) { inherit (args) nvf; };
      modules = homeModuleFiles;
    };
    default = { };
    description = "Portable user configuration, delivered by the active adapter.";
  };

  config = {
    xdg.config.files = lib.mapAttrs (path: file: { source = materialise path file; }) cfg.files;
    packages = cfg.packages;
    environment.sessionVariables = cfg.environment;
  };
}
