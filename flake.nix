#notice this is all wrapped in one {}, this is boilerplate syntax that says this is metadata and the actual attribute set handed to nix cli is the return from output
{
  /* 
  inputs is an attribute set of attribute sets, it is a variable that holds:
  { {}; {}; {}; }
  the outer {} is the attribute set of input, the inner {} are instructions for nix on how to fetch dependencies
  these dependencies just provide names, their attribute sets are only evaluated as needed when creating the output return
  this is due to the lazy nature of nix
  dependencies are usually flakes and if not one should use flake = false
  flake = false allowes pinning and other nice functionality of flakes to work on arbitrary dependencies
  also see here https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake.html#flake-inputs
  */
  inputs = {
    #i could pin a specific revision via a tarball, this would make it faster but would mean i need to manually update this link on each update
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      #this means that home-manager.inputs.nixpkgs follows the inputs.nixpkgs to avoid duplication and lock drift
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  /*
  @ means a pattern match, outputs is what this flake actually returns, 
  it is a function that returns the final attribute set that will be handed off to nix cli to build the system
  inputs @ { flake-parts, ... }: means that inputs becomes associated with all inputs inside the {}
  ... means that it accepts arbitrary input. inputs @ has a triple function:
  1. it makes everything passed to {} locally available so flake-parts can be called directly without inputs.flake-parts
  2. it uses ... to ignore all other inputs so they are only available through inputs.dependency 
  3. it is a pattern match and ensures that flake-parts is part of the parameters
     if inputs didnt have flake-parts.url it would fail, it forces a flake-parts argument
  */
  outputs = inputs @ { flake-parts, ... }:
    #mkFlake returns an attribute set which contains things like nixosConfiguration as long as its declared somewhere in the imports.
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
      ];
    };
  
}
