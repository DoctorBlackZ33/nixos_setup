{ ... }:

{
  # Shared security and store policy. Hosts own users, locale, networking,
  # and service assignments.
  nix.settings.auto-optimise-store = true;
  nix.settings.builders-use-substitutes = true;
  security.sudo.wheelNeedsPassword = true;
}
