# Server baseline: nothing a headless machine does not need. Every value is a
# default, so a host can still override it.
{ config, lib, ... }:
{
  config = lib.mkIf (config.contract.facts.kind == "server") {
    time.timeZone = lib.mkDefault "UTC";

    documentation.nixos.enable = lib.mkDefault false;
    fonts.fontconfig.enable = lib.mkDefault false;
    programs.command-not-found.enable = lib.mkDefault false;

    # A remote machine must not wait at an emergency prompt nobody can reach.
    systemd.enableEmergencyMode = lib.mkDefault false;
  };
}
