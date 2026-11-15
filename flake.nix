{
  description = "Config flake (Conf): hosts, users and the inventory";

  # Every external dependency is pinned here; the framework follows these
  # inputs, so this lock file decides what is deployed.
  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz";

    flake-parts.url = "github:hercules-ci/flake-parts";

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    system-manager = {
      url = "github:numtide/system-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    framework = {
      url = "path:./framework";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.hjem.follows = "hjem";
      inputs.nvf.follows = "nvf";
      inputs.system-manager.follows = "system-manager";
      inputs.agenix.follows = "agenix";
      inputs.agenix-rekey.follows = "agenix-rekey";
    };
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.framework.flakeModules.default ];

      framework = {
        root = ./.;
        deployments = import ./deployments.nix;

        # Secrets stay off until a master identity exists; then:
        #   secrets = {
        #     directory = ./secrets;
        #     masterIdentities = [ ./secrets/identities/yubikey.pub ];
        #     extraEncryptionPubkeys = [ "ssh-ed25519 AAAA... 1Password" ];
        #   };
      };
    };
}
