{ ... }:
{
  imports = [ ../common/nixos.nix ];

  sysMod.greeter.enable = true;
  sysMod.development.enable = true;
}
