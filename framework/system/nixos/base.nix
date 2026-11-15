# Store maintenance and privilege policy for every NixOS host.
{ lib, ... }:
{
  nix.settings.auto-optimise-store = true;
  nix.optimise.automatic = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  networking.firewall.enable = lib.mkDefault true;
  security.sudo.wheelNeedsPassword = lib.mkDefault true;
}
