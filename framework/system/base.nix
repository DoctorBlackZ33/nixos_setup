# Shared NixOS policy. Everything here is NixOS-only, so it is gated on the
# host fact instead of being conditionally imported (R1).
{ config, lib, ... }:
{
  config = lib.mkIf (config.facts.managed == "nixos") {
    nix.settings.auto-optimise-store = true;
    nix.settings.builders-use-substitutes = true;
    security.sudo.wheelNeedsPassword = true;
  };
}
