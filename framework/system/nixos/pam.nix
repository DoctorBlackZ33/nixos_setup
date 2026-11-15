# Provider for `pam.<service>`: creates the requested PAM services and reports
# every service the system has.
{ config, lib, ... }:
let
  inherit (config.contract) wanted;
in
{
  security.pam.services = lib.mkIf (wanted.pam != { }) (lib.mapAttrs (_: _: { }) wanted.pam);

  contract.provides.pam = lib.mapAttrs (_: _: true) config.security.pam.services;
}
