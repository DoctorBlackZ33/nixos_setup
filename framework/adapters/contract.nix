# Shared NixOS/system-manager contract options. The adapters read these; the
# modules only ever write them.
{ lib, ... }:
let
  contract = import ../lib/contract.nix { inherit lib; };
in
{
  options.facts = lib.mkOption {
    type = contract.factsType;
    description = "Fixed host facts. Flows host -> user (R2); homeMod never derives them.";
  };

  options.provides = lib.mkOption {
    type = contract.providesType;
    default = contract.emptyProvides;
    description = ''
      Capabilities this host supplies. The NixOS adapter computes them from its
      own config; the standalone adapter uses the values declared here.
    '';
  };

  options.requires = lib.mkOption {
    type = contract.requiresType;
    default = contract.emptyRequires;
    description = "Capabilities systemMod modules need from the hardware.";
  };

  options.homeModRequires = lib.mkOption {
    type = contract.requiresType;
    readOnly = true;
    description = "Union of systemMod and every enabled user's homeMod requirements.";
  };
}
