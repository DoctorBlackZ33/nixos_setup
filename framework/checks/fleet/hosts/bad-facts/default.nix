# Tries to change a fact from inside the system evaluation.
{ lib, ... }:
{
  imports = [ ../common/nixos.nix ];

  contract.facts.kind = lib.mkForce "workstation";
}
