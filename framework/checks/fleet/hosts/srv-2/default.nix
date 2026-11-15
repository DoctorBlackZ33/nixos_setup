{ ... }:
{
  imports = [ ../common/nixos.nix ];

  # No fish on this server, whatever bob prefers elsewhere.
  sysMod.accounts.bob.shell = "bash";
}
