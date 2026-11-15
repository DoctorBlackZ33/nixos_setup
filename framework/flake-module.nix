# flake-parts module for config flakes. The consumer states where its tree is
# and who runs where; outputs, checks and operator tools follow.
{ frameworkInputs }:
{ config, lib, inputs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.framework;

  framework = import ./lib {
    inherit (frameworkInputs.nixpkgs) lib;
    inputs = frameworkInputs;
  };

  fleet = import ./lib/fleet.nix {
    inherit (frameworkInputs.nixpkgs) lib;
    inherit framework;
    inherit (cfg) root deployments secrets moduleArgs overlays nixpkgsConfig;
    inputs = frameworkInputs;
  };

  # Keep this out of the systems definition: its default comes from the fleet.
  missingSystems = lib.subtractLists config.systems fleet.systems;

  packagesOf = input: system: frameworkInputs.${input}.packages.${system} or { };
in
{
  options.framework = {
    root = mkOption {
      type = types.path;
      description = "Directory containing `hosts/` and `users/`.";
    };

    overlays = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      example = lib.literalExpression "[ (final: prev: { unstable = import inputs.nixpkgs-unstable { inherit (prev) system; }; }) ]";
      description = ''
        nixpkgs overlays for every host and user. They apply identically to
        NixOS systems, system-manager systems and standalone users.
      '';
    };

    nixpkgsConfig = mkOption {
      type = types.attrsOf types.raw;
      default = { };
      example = { allowUnfree = true; };
      description = "nixpkgs `config`, applied on the same three paths as `overlays`.";
    };

    deployments = mkOption {
      inherit ((import ./lib/inventory.nix { inherit lib; })) type;
      default = { };
      description = "The inventory: which users run on which host.";
    };

    moduleArgs = mkOption {
      type = types.attrsOf types.raw;
      default = { };
      example = lib.literalExpression "{ flakeInputs = inputs; }";
      description = ''
        Extra arguments for hostConf, userConf and every other module, for
        example this flake's own inputs under a name of your choice. Names the
        framework provides itself (`inputs`, `pkgs`, `facts`, `framework`,
        `secretsDirectory`, `osConfig`) are rejected.
      '';
    };

    frameworkChecks = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Also run the framework's own checks (unit checks and the synthetic
        fleet) against the inputs this flake pins, as
        `checks.<system>."framework-*"`.
      '';
    };

    secrets = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          directory = mkOption {
            type = types.path;
            description = "Directory holding `<name>.age` and `rekeyed/<deployment>/`.";
          };
          masterIdentities = mkOption {
            type = types.listOf types.raw;
            default = [ ];
            description = "Identity stubs of the master keys (for example a YubiKey).";
          };
          extraEncryptionPubkeys = mkOption {
            type = types.listOf types.raw;
            default = [ ];
            description = "Backup recipients (for example a 1Password SSH public key).";
          };
        };
      });
      default = null;
      description = ''
        Enables the agenix secrets provider on every NixOS host. Leave null
        until a master identity exists: agenix-rekey refuses to evaluate
        without one.
      '';
    };
  };

  config = {
    systems = lib.mkDefault fleet.systems;

    flake = if cfg.deployments == { } then
      throw "framework.deployments is empty. Add at least one host to deployments.nix (for example: { desktop.users = [ \"alice\" ]; })."
    else if missingSystems != [ ] then
      throw "systems must include every deployment platform (missing: ${lib.concatStringsSep ", " missingSystems})."
    else
      {
        inherit (fleet) nixosConfigurations systemConfigs hjemConfigurations;
      }
      # Read by the agenix CLI below (`rekey`, `edit`, `generate`). The output
      # set is freeform, where `mkIf false` would leave an attribute that
      # throws when `nix flake check` touches it.
      // lib.optionalAttrs (cfg.secrets != null) {
        agenix-rekey = frameworkInputs.agenix-rekey.configure {
          userFlake = inputs.self;
          inherit (fleet) nixosConfigurations;
          collectHomeManagerConfigurations = false;
        };
      };

    perSystem = { system, pkgs, ... }: {
      checks =
        fleet.checksFor system
        // lib.optionalAttrs cfg.frameworkChecks (lib.mapAttrs'
          (name: lib.nameValuePair "framework-${name}")
          (import ./checks {
            inherit pkgs system;
            inputs = frameworkInputs;
          }));

      # Operator tools at the revisions this flake locks:
      #   nix run .#hjem -- standalone switch --flake . --flake-attr 'hjemConfigurations."<user>@<name>"'
      #   nix run .#system-manager -- switch --flake .#<name> --sudo
      #   nix run .#agenix -- rekey -a
      #   nix run .#sync-framework-lock        (after `nix flake update`)
      packages =
        lib.optionalAttrs (packagesOf "hjem" system ? hjem) { inherit (packagesOf "hjem" system) hjem; }
        // lib.optionalAttrs (packagesOf "system-manager" system ? default) {
          system-manager = (packagesOf "system-manager" system).default;
        }
        // lib.optionalAttrs (cfg.secrets != null && packagesOf "agenix-rekey" system ? default) {
          agenix = (packagesOf "agenix-rekey" system).default;
        }
        // {
          sync-framework-lock = pkgs.writeShellApplication {
            name = "sync-framework-lock";
            runtimeInputs = [ pkgs.jq pkgs.git ];
            text = builtins.readFile ./sync-framework-lock.sh;
          };
        };

      formatter = pkgs.alejandra;
    };
  };
}
