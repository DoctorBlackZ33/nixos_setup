# Option types for requires / provides / facts, derived from the capability
# table. Plain data (fixtures, hand-written host files) goes through `eval*`
# so that defaults apply and typos fail in every adapter the same way.
{ lib, capabilities, typed }:
let
  inherit (lib) mkOption types;
  inherit (capabilities) kinds;

  requiredOption = mkOption {
    type = types.bool;
    default = true;
    description = "Whether a miss fails evaluation (true) or only warns (false).";
  };

  requestType = parameters: types.submodule {
    options = { required = requiredOption; } // parameters;
  };

  requiresType = types.submodule {
    options =
      lib.mapAttrs
        (_: kind: mkOption {
          type = types.attrsOf (requestType kind.parameters);
          default = { };
          inherit (kind) description;
        })
        kinds
      // {
        facts = mkOption {
          type = types.attrsOf (requestType { });
          default = { };
          description = ''
            Host facts that must be known and truthy, addressed by dotted path,
            for example `facts."gpu.vendor" = { };`.
          '';
        };
      };
  };

  providesType = types.submodule {
    options = lib.mapAttrs
      (_: kind: mkOption {
        type = types.attrsOf types.bool;
        default = { };
        description = "Which ${kind.label}s this host supplies.";
      })
      kinds;
  };

  # `null` means unknown. A requirement on an unknown fact fails, so facts
  # carry no invented defaults.
  factsType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Inventory key of this host (set by the deployment builder).";
      };
      hostName = mkOption {
        type = types.str;
        description = "Network host name.";
      };
      platform = mkOption {
        type = types.str;
        example = "x86_64-linux";
        description = "Nix system the host runs.";
      };
      managed = mkOption {
        type = types.enum [ "nixos" "system-manager" "manual" ];
        description = ''
          Who owns the system layer: a NixOS configuration, a system-manager
          configuration, or nobody (only the user layer is deployed).
        '';
      };
      kind = mkOption {
        type = types.enum [ "workstation" "server" ];
        description = "The one high-level machine type. Framework modules gate on it.";
      };
      tags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Free-form groupings for user and host configuration. The framework does not interpret them.";
      };
      location = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      virtualisation = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "kvm";
        description = "Hypervisor the host runs under, or null on bare metal / unknown.";
      };
      gpu = {
        vendor = mkOption {
          type = types.nullOr (types.enum [ "amd" "intel" "nvidia" "virtual" ]);
          default = null;
        };
        vulkan = mkOption {
          type = types.nullOr types.bool;
          default = null;
        };
      };
      displays = mkOption {
        type = types.listOf (types.submodule {
          options = {
            width = mkOption { type = types.ints.positive; };
            height = mkOption { type = types.ints.positive; };
            refresh = mkOption {
              type = types.nullOr types.ints.positive;
              default = null;
            };
          };
        });
        default = [ ];
      };
      hostKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "ssh-ed25519 AAAA...";
        description = "SSH host public key. Secrets for this host are encrypted to it.";
      };
      extra = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Hand-written facts outside the typed schema.";
      };
    };
  };
in
{
  inherit requiresType providesType factsType;

  evalRequires = requires: typed.eval requiresType [ requires ];
  evalProvides = provides: typed.eval providesType [ provides ];

  # Later definitions win over earlier ones only through priorities, so
  # callers pass detected values wrapped in `lib.mkDefault`.
  evalFacts = definitions: typed.eval factsType definitions;
}
