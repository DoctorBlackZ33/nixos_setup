# Installs whatever the fleet's package policy makes available: a package
# that only an overlay defines, and one gated on nixpkgs config.
{ lib, pkgs, ... }:
{
  packages =
    lib.optional (pkgs ? fleetMarker) pkgs.fleetMarker
    ++ lib.optional (pkgs.config.allowUnfree or false) pkgs.cowsay;
}
