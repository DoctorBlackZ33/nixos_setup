{ ... }:
{
  flake.modules.nixos.account-admin = ./admin.nix;
  flake.modules.nixos.account-black = ./black.nix;
}
