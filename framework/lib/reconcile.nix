{ lib }:
let
  contract = import ./contract.nix { inherit lib; };

  missingFact = value: value == null || (lib.isList value && value == [ ]);

  factValue = facts: path: lib.attrByPath (lib.splitString "." path) null facts;

  capabilityReport = { kind, requires, provides }:
    let
      names = lib.attrNames requires;
      entries = map
        (name: {
          inherit name;
          required = requires.${name}.required or true;
          supplied = builtins.hasAttr name provides && provides.${name};
        })
        names;
    in
    {
      errors = map
        (entry: "requires ${kind} '${entry.name}' but the host does not provide it")
        (builtins.filter (entry: entry.required && !entry.supplied) entries);
      warnings = map
        (entry: "optional ${kind} '${entry.name}' is not provided by the host")
        (builtins.filter (entry: !entry.required && !entry.supplied) entries);
    };

  portalReport = { requires, provides }:
    map
      (portal: "requires portal '${portal}' but the host does not provide it")
      (builtins.filter (portal: !(builtins.elem portal provides.portals)) requires.portals);

  udevReport = { requires, provides }:
    let
      provided = map toString provides.udev.rules;
      required = map toString requires.udev.rules;
    in
    map
      (rule: "requires udev rule '${rule}' but the host does not provide it")
      (builtins.filter (rule: !(builtins.elem rule provided)) required);

  factReport = { requires, facts }:
    let
      entries = lib.mapAttrsToList
        (path: requirement: {
          inherit path;
          required = requirement.required or true;
          value = factValue facts path;
        })
        requires.facts;
      absent = builtins.filter (entry: missingFact entry.value) entries;
    in
    {
      errors = map (entry: "requires fact '${entry.path}' but the host does not report it") (builtins.filter (entry: entry.required) absent);
      warnings = map (entry: "optional fact '${entry.path}' is not reported by the host") (builtins.filter (entry: !entry.required) absent);
    };
in
rec {
  inherit factValue;

  reconcile = { requires, provides, facts }:
    let
      requires' = contract.normaliseRequires requires;
      provides' = lib.recursiveUpdate contract.emptyProvides provides;
      pam = capabilityReport { kind = "PAM service"; requires = requires'.pam; provides = provides'.pam; };
      services = capabilityReport { kind = "service"; requires = requires'.services; provides = provides'.services; };
      setuid = capabilityReport { kind = "setuid wrapper"; requires = requires'.setuid; provides = provides'.setuid; };
      secrets = capabilityReport { kind = "secret"; requires = requires'.secrets; provides = provides'.secrets; };
      portals = portalReport { requires = requires'; provides = provides'; };
      udev = udevReport { requires = requires'; provides = provides'; };
      factChecks = factReport { requires = requires'; inherit facts; };
    in
    {
      errors = lib.concatLists [
        pam.errors
        services.errors
        setuid.errors
        secrets.errors
        portals
        udev
        factChecks.errors
      ];
      warnings = lib.concatLists [
        pam.warnings
        services.warnings
        setuid.warnings
        secrets.warnings
        factChecks.warnings
      ];
    };
}
