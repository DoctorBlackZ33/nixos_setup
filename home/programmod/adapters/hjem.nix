{ config, lib, pkgs, ... }:
let
  programmod = import ../default.nix { inherit lib; };
  cfg = config.homeMod;
in
{
  options.homeMod = lib.mkOption {
    type = programmod.submoduleFor pkgs;
    default = { };
    description = "The user's portable program configuration.";
  };

  config = {
    xdg.config.files = lib.mapAttrs (_: source: { inherit source; }) cfg.build.files;
    packages = cfg.packages;
    environment.sessionVariables = cfg.environment;

  };
}
