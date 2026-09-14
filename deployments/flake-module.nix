{ ... }:

{
  imports = [
    ./standalone/black.nix
    ./vm/default.nix
    ./vm/black/flake-module.nix
  ];
}
