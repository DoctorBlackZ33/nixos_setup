# Contract wiring shared by the system adapters (NixOS and system-manager).
# Modules write `contract.requires` and `contract.provides`; this file merges
# the requests, reconciles, and turns the result into assertions and warnings.
{ config, lib, framework, ... }:
let
  inherit (lib) mkOption types;
  inherit (framework) contract reconcile;
  cfg = config.contract;

  external = lib.mapAttrs' (user: lib.nameValuePair "user ${user}") cfg.userRequests;

  # Users evaluated outside this system get their verdict in their own
  # configuration, so one of them cannot keep the system, or the others, from
  # building. Everyone evaluated here is judged here.
  result = (reconcile.reconcile {
    host = cfg.facts.name;
    inherit (cfg) requests provides facts;
  }).forSources (lib.subtractLists (lib.attrNames external) (lib.attrNames cfg.requests));
in
{
  options.contract = {
    facts = mkOption {
      type = contract.factsType;
      readOnly = true;
      description = ''
        Fixed host facts, set once by the fleet builder from
        hosts/<host>/facts.nix and the hardware report. They flow host -> user
        (R2) and are never derived from the user layer.
      '';
    };

    requires = mkOption {
      type = contract.requiresType;
      description = "Capabilities the system layer itself needs, for example audio on a workstation.";
    };

    userRequests = mkOption {
      type = types.attrsOf contract.requiresType;
      default = { };
      description = ''
        Requirements of users whose configuration is evaluated outside this
        system (standalone delivery), keyed by user name. Providers react to
        them; their verdict is delivered in the users' own configurations.
      '';
    };

    provides = mkOption {
      type = contract.providesType;
      description = ''
        Capabilities this host supplies. Provider modules define entries from
        their own config; nothing else writes here.
      '';
    };

    secretsDirectory = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Where the secrets provider places decrypted secrets; null without one.";
    };

    requests = mkOption {
      type = types.attrsOf contract.requiresType;
      description = "Every requirement by source label. Adapters add the users they evaluate.";
    };

    wanted = mkOption {
      type = types.raw;
      readOnly = true;
      description = ''
        Merged view of `requests` for provider modules:
        `wanted.<kind>.<name> = { required; sources; }`.
      '';
    };
  };

  config = {
    contract.requests = { system = cfg.requires; } // external;

    contract.wanted = reconcile.merge cfg.requests;

    # Behind mkIf: reconcile reads the user layer, which must not be forced
    # while the module system is still collecting definitions.
    assertions = lib.mkIf (result.errors != [ ]) [
      {
        assertion = false;
        message = reconcile.report cfg.facts.name result.errors;
      }
    ];

    warnings = result.warnings;
  };
}
