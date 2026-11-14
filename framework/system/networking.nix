{ config, lib, ... }:
{
  config = lib.mkIf (config.facts.managed == "nixos") {
    networking.networkmanager.enable = true;
    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [ 22 ];
    services.openssh.enable = true;
  };
}
