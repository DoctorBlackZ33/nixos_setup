# Contradicts its own facts: the inventory would validate one name while the
# machine carries another.
{ ... }:
{
  imports = [ ../common/nixos.nix ];

  networking.hostName = "something-else";
}
