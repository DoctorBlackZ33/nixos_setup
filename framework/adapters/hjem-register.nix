# Registers the homeMod class with Hjem. Kept separate from the adapter that
# reads `config.hjem.users`: the users option type is built from
# `hjem.extraModules`, so defining both in one module is a fixed-point cycle.
{ ... }:
{
  hjem.extraModules = [ ./hjem.nix ];
}
