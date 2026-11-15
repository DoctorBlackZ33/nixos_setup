# Installs a package that exists only when an overlay defines it.
{ lib, pkgs, ... }:
{
  environment.systemPackages = lib.optional (pkgs ? fleetMarker) pkgs.fleetMarker;
}
