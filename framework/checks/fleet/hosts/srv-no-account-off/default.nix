# A deployed user still needs an account when home delivery is disabled.
{ ... }:
{
  imports = [ ../common/nixos.nix ];
  hjem.users.erin.enable = false;
}
