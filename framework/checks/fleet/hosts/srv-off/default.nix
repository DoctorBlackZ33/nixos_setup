# carol is deployed here but switched off in Hjem: what she asks for must not
# count.
{ ... }:
{
  imports = [ ../common/nixos.nix ];

  hjem.users.carol.enable = false;
}
