# Framework library. `inputs` are the framework flake's own inputs; they are
# handed to user-layer modules so that program modules can reach their
# upstream flakes without adapters knowing any program by name.
{ lib, inputs }:
let
  capabilities = import ./capabilities.nix { inherit lib; };

  self = {
    inherit capabilities;
    contract = import ./contract.nix { inherit lib capabilities; };
    reconcile = import ./reconcile.nix { inherit lib capabilities; };
    sections = import ./sections.nix { inherit lib; };
    modules = import ./modules.nix { inherit lib; };
    inventory = import ./inventory.nix { inherit lib; };
    facts = import ./facts.nix { inherit lib; framework = self; };
    home = import ./home.nix { inherit lib inputs; framework = self; };
  };
in
self
