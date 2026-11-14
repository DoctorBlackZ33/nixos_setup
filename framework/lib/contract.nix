{ lib }:
let
  inherit (lib) mkOption types;

  capabilityType = types.submodule {
    options = {
      required = mkOption {
        type = types.bool;
        default = true;
        description = "Whether a missing capability is an error (true) or a warning (false).";
      };
    };
  };

  secretType = types.submodule {
    options = {
      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "Mode the decrypted runtime path must have. Never the secret value.";
      };
      required = mkOption {
        type = types.bool;
        default = true;
        description = "Whether a missing secret is an error (true) or a warning (false).";
      };
    };
  };

  factRequirementType = types.submodule {
    options = {
      required = mkOption {
        type = types.bool;
        default = true;
        description = "Whether a missing fact is an error (true) or a warning (false).";
      };
    };
  };

  requiresType = types.submodule {
    options = {
      pam = mkOption {
        type = types.attrsOf capabilityType;
        default = { };
        description = "PAM services the configuration needs, for example `pam.hyprlock = { };`.";
      };
      portals = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "XDG desktop portal implementations the configuration needs, by short name.";
      };
      services = mkOption {
        type = types.attrsOf capabilityType;
        default = { };
        description = "System services the configuration needs, for example `services.pipewire = { };`.";
      };
      udev.rules = mkOption {
        type = types.listOf (types.either types.str types.package);
        default = [ ];
        description = "udev rules the configuration needs.";
      };
      setuid = mkOption {
        type = types.attrsOf capabilityType;
        default = { };
        description = "Setuid wrappers the configuration needs.";
      };
      secrets = mkOption {
        type = types.attrsOf secretType;
        default = { };
        description = "Secrets the configuration needs by name; only paths are handed to modules.";
      };
      facts = mkOption {
        type = types.attrsOf factRequirementType;
        default = { };
        description = "Host facts the configuration needs, addressed by attribute path.";
      };
    };
  };

  providesType = types.submodule {
    options = {
      pam = mkOption {
        type = types.attrsOf types.bool;
        default = { };
        description = "PAM services this host supplies.";
      };
      portals = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Portal implementations this host supplies.";
      };
      services = mkOption {
        type = types.attrsOf types.bool;
        default = { };
        description = "System services this host supplies.";
      };
      udev.rules = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "udev rules this host supplies.";
      };
      setuid = mkOption {
        type = types.attrsOf types.bool;
        default = { };
        description = "Setuid wrappers this host supplies.";
      };
      secrets = mkOption {
        type = types.attrsOf types.bool;
        default = { };
        description = "Secrets this host supplies.";
      };
    };
  };

  factsType = types.submodule {
    options = {
      hostName = mkOption {
        type = types.str;
        description = "Host name of this machine.";
      };
      platform = mkOption {
        type = types.str;
        default = "x86_64-linux";
        description = "Nix system string.";
      };
      location = mkOption {
        type = types.str;
        default = "unknown";
        description = "Physical or logical location.";
      };
      managed = mkOption {
        type = types.enum [ "nixos" "system-manager" "manual" ];
        default = "nixos";
        description = "Which system adapter owns this host.";
      };
      gpu = mkOption {
        type = types.submodule {
          options = {
            vendor = mkOption {
              type = types.enum [ "amd" "intel" "nvidia" "virtual" "unknown" ];
              default = "unknown";
            };
            vulkan = mkOption {
              type = types.bool;
              default = false;
            };
          };
        };
        default = { };
        description = "GPU facts.";
      };
      displays = mkOption {
        type = types.listOf (types.submodule {
          options = {
            width = mkOption { type = types.int; };
            height = mkOption { type = types.int; };
            refresh = mkOption {
              type = types.int;
              default = 60;
            };
          };
        });
        default = [ ];
        description = "Attached displays with their native mode.";
      };
      extra = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Additional hand-written facts outside the typed schema.";
      };
    };
  };

  emptyRequires = {
    pam = { };
    portals = [ ];
    services = { };
    udev.rules = [ ];
    setuid = { };
    secrets = { };
    facts = { };
  };

  emptyProvides = {
    pam = { };
    portals = [ ];
    services = { };
    udev.rules = [ ];
    setuid = { };
    secrets = { };
  };

  unionList = a: b: lib.unique (a ++ b);

  normaliseRequires = requires: lib.recursiveUpdate emptyRequires requires;

  mergeRequires = a: b:
    let
      left = normaliseRequires a;
      right = normaliseRequires b;
    in
    {
      pam = left.pam // right.pam;
      portals = unionList left.portals right.portals;
      services = left.services // right.services;
      udev.rules = unionList left.udev.rules right.udev.rules;
      setuid = left.setuid // right.setuid;
      secrets = left.secrets // right.secrets;
      facts = left.facts // right.facts;
    };
in
{
  inherit requiresType providesType factsType emptyRequires emptyProvides normaliseRequires mergeRequires;
}
