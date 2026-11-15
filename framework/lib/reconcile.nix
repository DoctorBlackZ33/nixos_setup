# Pure contract logic. `requests` maps a source label ("user black",
# "system") to a typed `requires` value, so every message can say who asked.
{ lib, capabilities }:
let
  inherit (capabilities) kinds;

  # A fact is missing when it is unknown or says "no".
  missingFact = value:
    value == null || value == false || value == [ ] || value == "" || value == { };

  # name -> [ { source; request; } ] for one kind across all sources.
  collect = kindName: requests:
    lib.zipAttrs (lib.mapAttrsToList
      (source: requires:
        lib.mapAttrs (_: request: { inherit source request; }) requires.${kindName})
      requests);

  # One requester needing it makes it required; parameters come from the
  # first requester and disagreement is reported as a conflict.
  mergeEntries = parameters: entries:
    {
      required = lib.any (entry: entry.request.required) entries;
      sources = map (entry: entry.source) entries;
    }
    // lib.mapAttrs (parameter: _: (builtins.head entries).request.${parameter}) parameters;

  conflictsOf = kind: name: entries:
    lib.concatLists (lib.mapAttrsToList
      (parameter: _:
        let
          values = lib.unique (map (entry: entry.request.${parameter}) entries);
        in
        lib.optional (builtins.length values > 1) {
          required = true;
          sources = map (entry: entry.source) entries;
          message =
            "${kind.label} '${name}' is requested with conflicting ${parameter}: "
            + lib.concatMapStringsSep ", "
              (entry: "${toString entry.request.${parameter}} by ${entry.source}")
              entries;
        })
      kind.parameters);

  merge = requests:
    lib.mapAttrs
      (kindName: kind: lib.mapAttrs (_: mergeEntries kind.parameters) (collect kindName requests))
      kinds
    // {
      facts = lib.mapAttrs (_: mergeEntries { }) (collect "facts" requests);
    };

  requesters = want: lib.concatStringsSep ", " want.sources;

  verdict = findings: {
    errors = map (finding: finding.message) (lib.filter (finding: finding.required) findings);
    warnings = map (finding: finding.message) (lib.filter (finding: !finding.required) findings);
  };
in
{
  # kind -> name -> { required; sources; <parameters>; } plus `facts`.
  inherit merge;

  # -> { errors; warnings; forSources }. `forSources [ "user alice" ]` is the
  # same verdict restricted to what those requesters are involved in.
  reconcile = { host, requests, provides, facts }:
    let
      wanted = merge requests;

      missingCapabilities = lib.concatLists (lib.mapAttrsToList
        (kindName: kind:
          lib.mapAttrsToList
            (name: want: {
              inherit (want) required sources;
              message = "${kind.label} '${name}' is requested by ${requesters want} but host '${host}' does not provide it";
            })
            (lib.filterAttrs (name: _: !(provides.${kindName}.${name} or false)) wanted.${kindName}))
        kinds);

      missingFacts = lib.mapAttrsToList
        (path: want: {
          inherit (want) required sources;
          message = "fact '${path}' is requested by ${requesters want} but host '${host}' does not report it";
        })
        (lib.filterAttrs
          (path: _: missingFact (lib.attrByPath (lib.splitString "." path) null facts))
          wanted.facts);

      conflicts = lib.concatLists (lib.mapAttrsToList
        (kindName: kind:
          lib.concatLists (lib.mapAttrsToList (conflictsOf kind) (collect kindName requests)))
        kinds);

      findings = missingCapabilities ++ missingFacts ++ conflicts;
    in
    verdict findings // {
      forSources = sources:
        verdict (lib.filter (finding: lib.any (source: lib.elem source finding.sources) sources) findings);
    };

  # One multi-line message per host for assertions and throws.
  report = host: errors:
    lib.concatStringsSep "\n" (
      [ "contract violations on host '${host}':" ]
      ++ map (error: "  - ${error}") errors
    );
}
