# Registers the homeMod class with Hjem. Kept apart from the module that
# reads `config.hjem.users`: Hjem builds the users option type from
# `hjem.extraModules`, so one module doing both is a fixed-point cycle that
# silently yields empty requirements.
{ framework, ... }:
{
  hjem.extraModules = [ ./hjem.nix ];
  hjem.specialArgs = { inherit framework; };
}
